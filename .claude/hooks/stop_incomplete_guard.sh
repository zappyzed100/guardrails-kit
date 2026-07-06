#!/usr/bin/env bash
# stop_incomplete_guard.sh — ターン終了ゲート: 未完了（未コミット作業/構造検査が赤）の終了を exit 2 で差し戻す（正本: GUARDRAILS.md §2b）
#
# Stop フックの仕様: 応答終了時に発火し、exit 2 で終了を差し戻せる（stderr が Claude に渡る）。
# 入力 JSON: session_id / transcript_path / stop_hook_active。stop_hook_active=true は
# 「既に差し戻しで継続中」を意味する（無限ループ防止に必読 — §2b）。
#
# 差し戻し条件（いずれかの理由が成立 ∧ 免除なし の時のみ exit 2）:
#   条件A（v2.4）: `git status --porcelain` が非空（未コミットの作業がある）
#   条件B（v2.9・決定点②の強化案を確定）: ツリーはクリーンだが `dev.py check` が
#     exit 1 かつ出力に `HARD:`（ゲートを通らない状態で終わろうとしている）。
#     条件Bはクリーンな時だけ走る（ダーティなら条件Aが先に成立——毎ターンのコストは
#     §7.7 の 2 秒予算＋uv 起動数十ms。ハングは本体側フックタイムアウトが殺す＝
#     kill は exit 2 以外 → 差し戻されない側に倒れる）。
#     fail-open の枝: uv 不在・scripts/dev.py 不在（表示1行で素通し）・exit 2（内部
#     エラー）・`HARD:` 行の無い非0——いずれも差し戻さない。
#   免除: transcript 終端 N 行に `"BLOCKED:`（値の先頭が BLOCKED: で始まる報告）がある
#       ※ 素の `BLOCKED:` を探すと、本フック自身の差し戻し文面（`BLOCKED:` の指示）が
#         transcript に載った時点で恒久すり抜けになる。先頭一致の近似は仕様（§7.4 の流儀）。
#       免除・ループ保護・fail-open は条件A/Bで共有。
#
# ループ保護（二重 — §2b）:
#   ① .claude/session/<session_id>.stopcount のカウンタで差し戻しは最大 3 回。
#     stop_hook_active=false（新しい停止連鎖）でカウンタは 0 から数え直す。
#   ② Claude Code 本体側の連続ブロック上限（v2.1.143+・CLAUDE_CODE_STOP_HOOK_BLOCK_CAP）。
#
# 【契約——§2 と逆向き】本フックの想定外エラーは exit 0（fail-open・差し戻さない）。
# PreToolUse（§2）は fail-closed が正だが、Stop で fail-closed にすると壊れたフックが
# セッションを終了不能にする。非対称の正本は §2b。

MAX_REDIRECTS=3
TAIL_LINES=50

# ---- fail-open の骨格: どの前提が欠けても「差し戻さない」側に倒す ----
input=$(cat 2>/dev/null) || exit 0
[ -n "$input" ] || exit 0
command -v git >/dev/null 2>&1 || exit 0

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$root" ] && [ -d "$root" ] || exit 0
cd "$root" 2>/dev/null || exit 0

porcelain=$(git status --porcelain 2>/dev/null) || exit 0

# ---- 入力 JSON の読み取り（jq があれば精密・無ければ保守的 — post_edit_format.sh と同型）----
if command -v jq >/dev/null 2>&1; then
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || session_id=""
  transcript_path=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null) || transcript_path=""
  active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null) || active="false"
else
  session_id=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  transcript_path=$(printf '%s' "$input" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  if printf '%s' "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
    active="true"
  else
    active="false"
  fi
fi
session_id=$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9._-')  # ファイル名安全化（§7.2 の流儀）
[ -n "$session_id" ] || session_id="unknown"
counter_dir="$root/.claude/session"
counter_file="$counter_dir/$session_id.stopcount"

# ---- 差し戻し理由の確定（出口1を含む）----
# クリーン ∧ 構造検査が緑 ＝ DoD を満たしてコミット済みの正規終了（出口1）。
# クリーンでも check が赤なら条件B（v2.9）——「クリーンにさえすれば赤い検査を残して
# 終われる」隙間を塞ぐ。
reason=""
check_head=""
if [ -n "$porcelain" ]; then
  reason="dirty"
else
  if command -v uv >/dev/null 2>&1 && [ -f "$root/scripts/dev.py" ]; then
    check_out=$(uv run scripts/dev.py check 2>&1)
    check_rc=$?
    if [ "$check_rc" -eq 1 ] && printf '%s\n' "$check_out" | grep -q 'HARD:'; then
      reason="check"
      check_head=$(printf '%s\n' "$check_out" | grep 'HARD:' | head -n 5)
    fi
    # exit 0=緑 / exit 2=内部エラー / HARD 無しの非0 → いずれも差し戻さない（fail-open）
  else
    echo "[stop-gate] 条件B スキップ（uv または scripts/dev.py が無い）——静かな不発の禁止は本表示で満たす（GUARDRAILS.md §2b）" >&2
  fi
  if [ -z "$reason" ]; then
    rm -f "$counter_file" 2>/dev/null
    exit 0
  fi
fi

# ---- 出口2: 明示ブロッカー報告（応答の先頭が BLOCKED: で始まる）----
# transcript が読めない時は判定不能 → fail-open（差し戻すと出口2が構造的に消える）。
transcript_path="${transcript_path/#\~/$HOME}"
[ -n "$transcript_path" ] && [ -r "$transcript_path" ] || exit 0
if tail -n "$TAIL_LINES" "$transcript_path" 2>/dev/null | grep -F -q -- '"BLOCKED:'; then
  rm -f "$counter_file" 2>/dev/null
  exit 0
fi

# ---- 差し戻し（ループ保護①のカウンタ内でのみ）----
count=0
if [ "$active" = "true" ]; then
  count=$(cat "$counter_file" 2>/dev/null | tr -cd '0-9')
  [ -n "$count" ] || count=0
  if [ "$count" -ge "$MAX_REDIRECTS" ]; then
    echo "[stop-gate] 差し戻し上限（${MAX_REDIRECTS}回）到達のため終了を許可（GUARDRAILS.md §2b）" >&2
    exit 0
  fi
fi
mkdir -p "$counter_dir" 2>/dev/null || exit 0
echo $((count + 1)) > "$counter_file" 2>/dev/null || exit 0  # 記録できないなら差し戻さない（fail-open）

if [ "$reason" = "check" ]; then
  echo "作業ツリーはクリーンだが、構造検査（dev.py check）が赤のままターンを終えようとしている（§2b 条件B — v2.9）。終えてよい出口は2つだけ: (a) 規則IDで GUARDRAILS.md §3.3 を引いて違反を解消し、規約どおりコミットする。 (b) 物理的に解消不能なら、応答の先頭を \`BLOCKED:\` で始めて具体的に報告する。検出された違反（先頭5行）:
${check_head}" >&2
else
  changed=$(printf '%s\n' "$porcelain" | grep -c .)
  echo "未コミットの作業ツリー（変更 ${changed} 件）のままターンを終えようとしている。終えてよい出口は2つだけ: (a) DoD を満たし規約どおりコミットして作業ツリーをクリーンにする（§3・§10 実行規律7）。 (b) 本当に手が止まる物理的ブロッカーなら、応答の先頭を \`BLOCKED:\` で始めて具体的に報告する。「続けますか?」で止まるのはサボりの一形態（GUARDRAILS.md §2b）。" >&2
fi
exit 2

#!/usr/bin/env bash
# session_baseline.sh — セッション開始時点の未コミット変更（人間のWIP）のパス集合を保存する（正本: GUARDRAILS.md §2c）
#
# SessionStart フック。`git status --porcelain` のパスを
# `.claude/session/<session_id>.baseline`（1行1パス・リポジトリ相対）へ書く。
# guard_human_wip.sh（PreToolUse）がこの baseline を読み、「セッション開始時から
# 人間の手で dirty だったファイル」への AI の Edit/Write をブロックする（§2c）。
#
# 契約（§2c — fail-open 側）: SessionStart は exit 2 でもセッションを止めない仕様のため、
# 本フックの失敗は stderr 1行の表示＋exit 0（表示で「静かな不発」を防ぎ、進行は止めない。
# baseline が書けなかった場合、guard_human_wip.sh 側も「baseline 不在＝警告1行で通す」）。
#
# 近似（§7.4 の流儀）: porcelain v1 のリネーム行 `XY old -> new` は両側のパスを保存する。
# core.quotePath による引用表記（非ASCIIパス等）は近似の範囲外——実測されたら
# guard_human_wip.sh と同一コミットで直す。

warn_and_pass() {
  echo "[session-baseline] $1（所有権ガード §2c は baseline 不在の警告付き素通しで縮退する）" >&2
  exit 0
}

input=$(cat 2>/dev/null) || warn_and_pass "stdin を読めない"
command -v git >/dev/null 2>&1 || warn_and_pass "git が見つからない"

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$root" ] && [ -d "$root" ] || warn_and_pass "リポジトリルートを解決できない"

# ---- session_id の抽出（jq があれば精密・無ければ保守的 — stop_incomplete_guard.sh と同型）----
if command -v jq >/dev/null 2>&1; then
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || session_id=""
else
  session_id=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
fi
session_id=$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9._-')  # ファイル名安全化（§7.2 の流儀）
[ -n "$session_id" ] || session_id="unknown"

porcelain=$(git -C "$root" status --porcelain 2>/dev/null) || warn_and_pass "git status が失敗"

baseline_dir="$root/.claude/session"
baseline_file="$baseline_dir/$session_id.baseline"
mkdir -p "$baseline_dir" 2>/dev/null || warn_and_pass "session ディレクトリを作れない"

# 1行1パスに整形（`XY path`→path。リネーム `XY old -> new` は両側を1行ずつ）。
# ツリーがクリーンでも**空の baseline を必ず書く**——「不在（不明）」と
# 「開始時クリーン（保護対象なし）」を guard 側が区別できるようにする。
{
  printf '%s\n' "$porcelain" | while IFS= read -r line; do
    [ -n "$line" ] || continue
    path=${line:3}
    case "$path" in
      *" -> "*)
        printf '%s\n' "${path% -> *}"
        printf '%s\n' "${path#* -> }"
        ;;
      *)
        printf '%s\n' "$path"
        ;;
    esac
  done
} > "$baseline_file" 2>/dev/null || warn_and_pass "baseline を書けない"

count=$(grep -c . "$baseline_file" 2>/dev/null | tr -cd '0-9')
[ -n "$count" ] || count=0
if [ "$count" -gt 0 ]; then
  echo "[session-baseline] セッション開始時点の未コミット変更 ${count} 件を記録した。これらのファイルへの Edit/Write は、人間が commit / stash するまでブロックされる（GUARDRAILS.md §2c）" >&2
fi
exit 0

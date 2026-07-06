#!/usr/bin/env bash
# guard_human_wip.sh — 人間の未コミット変更（セッション開始時点で dirty だったファイル）への AI の Edit/Write を exit 2 でブロックする（正本: GUARDRAILS.md §2c）
#
# PreToolUse(Edit|Write|MultiEdit)。ブロック条件は**両方**が成立する時のみ:
#   (A) 対象 file_path が session_baseline.sh の保存した baseline に含まれる
#       （＝セッション開始時点で既に未コミット変更があった＝人間のWIP）
#   (B) そのファイルが**現在も**未コミット（`git status --porcelain -- <path>` が非空）
# 人間が commit / stash すれば (B) が外れて自動解除——解除用の特別経路を作らない（§2c）。
#
# 【契約——§2 と逆向き・§2b の仲間】baseline 不在・git 不在などの想定外は
# **警告1行＋exit 0（fail-open）**。書き込み保護は利便とのトレードであり、壊れた
# フックが全編集を止めてはならない（迂回防止 §2 の fail-closed とは非対称——正本は §2c）。
#
# 既知の限界（§2c に明記）: baseline はセッション**開始時点**のスナップショット。
# 同一セッション内で人間が並行して編集を始めたファイルは守れない。
# パスの正規化（絶対→リポジトリ相対・区切り差）は git 自身に任せる——
# `git status --porcelain -- <絶対パス>` の出力がリポジトリ相対で返ることを利用する。

warn_and_pass() {
  echo "[human-wip-guard] $1（判定不能のため素通し——所有権ガード §2c は fail-open 側）" >&2
  exit 0
}

input=$(cat 2>/dev/null) || exit 0
[ -n "$input" ] || exit 0
command -v git >/dev/null 2>&1 || warn_and_pass "git が見つからない"

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$root" ] && [ -d "$root" ] || warn_and_pass "リポジトリルートを解決できない"

# ---- 入力 JSON の読み取り（jq があれば精密・無ければ保守的 — post_edit_format.sh と同型）----
if command -v jq >/dev/null 2>&1; then
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || file_path=""
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || session_id=""
else
  file_path=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
  session_id=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
fi
[ -n "${file_path:-}" ] || exit 0
session_id=$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9._-')
[ -n "$session_id" ] || session_id="unknown"

baseline_file="$root/.claude/session/$session_id.baseline"
[ -r "$baseline_file" ] || warn_and_pass "baseline が無い（SessionStart フック未発火か保存失敗: $session_id.baseline）"

# ---- 条件(B): 現在も未コミットか。git がパス正規化ごと判定する（リポジトリ外・クリーンなら空）----
status_line=$(git -C "$root" status --porcelain -- "$file_path" 2>/dev/null | head -n 1) || exit 0
[ -n "$status_line" ] || exit 0   # いまクリーン（or 未作成）＝人間のWIPは残っていない

rel=${status_line:3}
case "$rel" in
  *" -> "*) rel="${rel#* -> }" ;;   # リネーム行は現行側のパス（近似 — §7.4 の流儀）
esac
[ -n "$rel" ] || exit 0

# ---- 条件(A): セッション開始時点でも dirty だったか ----
if grep -Fxq -- "$rel" "$baseline_file" 2>/dev/null; then
  echo "ブロック: このファイルにはセッション開始時点から人間の未コミット変更がある: $rel（GUARDRAILS.md §2c 所有権ガード）。人間と AI の変更が混ざった diff は原因追跡不能の温床。人間が commit / stash すれば自動的に解除される——AI 側から退避コマンドで消すのは §2 作業消失ガードが別途ブロックする。" >&2
  exit 2
fi
exit 0

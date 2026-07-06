#!/usr/bin/env bash
# post_edit_format.sh — Edit/Write/MultiEdit 直後に編集ファイルへ整形を当てる（正本: GUARDRAILS.md §1）
#
# 狙い: フォーマット崩れの検出地点を「コミット時」から「編集した瞬間」へ前倒しする。
# PostToolUse の仕様: 編集自体は取り消せない。exit 2 のとき stderr が Claude に渡り
# 自己修正の材料になる（整形が失敗する = 構文エラーの可能性が高いので exit 2 を使う）。
# フォーマッタ未導入・対象外拡張子は exit 0（この層は利便であってゲートではない。
# ゲートは §3〜§5 が担う）。どの整形も冪等。
#
# BINDING-SOURCE: <列ID@版をここに>   ← Step 0 で刻印（§12.7）
#
# ===== BINDING: 対象拡張子 × 整形コマンド（bindings/catalog.md の採用列から充填）=====
# v2キットは言語なしで出荷される（下の case は既定分岐のみ）。Step 0 で採用列の
# paste-block を case へ挿入する。冪等な整形コマンドのみ許可（表A「整形」）。

set -uo pipefail

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
else
  file_path=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
fi

[ -n "${file_path:-}" ] || exit 0
[ -f "$file_path" ] || exit 0

case "$file_path" in
  # ---- ここに採用列の case 分岐を貼る（bindings/catalog.md）----
  *)
    : # 未配線の拡張子は素通し（この層はゲートではない — §1）
    ;;
esac

exit 0

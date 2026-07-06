#!/usr/bin/env bash
# post_edit_lint.sh — Edit/Write/MultiEdit 直後の編集ファイルへ単一ファイル lint を当てる第2段（正本: GUARDRAILS.md §1）
#
# 整形（post_edit_format.sh・自動修正系）と責務を分けた**判定系**の第2段（v2.5・Phase 12）。
# lint の初出地点が push 段（§4）から編集直後へ2段前倒しになり、「push で落ちて再試行」の
# ループ1周が消える。違反は exit 2 —— stderr が Claude に渡り、コンテキストを保持した
# まま即修正ループに入れる。
#
# 実行順の保証: Claude Code の公式仕様では同一 matcher の複数フックは**並列・順序不定**。
# そのため本フックは settings.json 側で post_edit_format.sh と**1コマンドの直列**として
# 配線される（整形→lint の順を実行環境の仕様に依存させない —— §1）。
#
# 性能予算（§7.7・v2.5 新設）: 整形と合わせて**編集1回あたり3秒以内**。全体 typecheck・
# 全体テストはここに入れない（push 段 §4 に残す。予算に収まる単一ファイル lint のみ）。
# ツール不在: 「lint 未導入」を stderr 1行で表示して素通し（exit 0 —— 表示で静かな不発を
# 防ぎ、編集フローは止めない。表示＋素通しの型は §2b/§2c 系の fail-open 側の整理）。
# --fix 系（自動修正）はここに置かない —— それは整形フック（第1段）の責務。
#
# BINDING-SOURCE: <列ID@版をここに>   ← Step 0 で刻印（§12.7）
#
# ===== BINDING: 対象拡張子 × lint コマンド（bindings/catalog.md 表A「編集直後 lint」）=====
# v2キットは言語なしで出荷される（下の case は既定分岐のみ）。Step 0 で採用列の
# paste-block を case へ挿入する。単一ファイル・3秒予算に収まる判定系コマンドのみ。
# 予算に収まらない言語は「該当なし（push 段で回収）」——カタログにその判断を記録する。

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
  # ---- ここに採用列の case 分岐を貼る（bindings/catalog.md 表A「編集直後 lint」）----
  *)
    : # 未配線の拡張子は素通し（この層はゲートではない — §1。門は §3〜§5 が担う）
    ;;
esac

exit 0

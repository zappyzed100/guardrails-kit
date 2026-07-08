#!/usr/bin/env bash
# guard_git_bypass.sh — git の --no-verify/-n・SKIP=・--force/-f push・core.hooksPath 迂回、および非可逆な作業消失（rm -rf .git／dirty での reset --hard 等）を exit 2 でブロック（正本: GUARDRAILS.md §2）
#
# PreToolUse(Bash) の仕様: ブロックできるのは exit 2 **だけ**（exit 1 含む他の非0は素通し）。
# したがって本フック内の想定外エラーもすべて exit 2 に倒す（fail-closed）——これが契約。
# 引用符の中身（コミットメッセージ等）は判定前に取り除くため、メッセージ文面に
# --no-verify という文字列が入っていても誤検知しない（jq がある場合の精密経路）。
# jq が無い場合は生JSONに対する保守的マッチに切り替える（過剰ブロック側に倒す）。
#
# 作業消失ガード（v2.5・Phase 14）は同一フック内の節として実装する（プロセス数を
# 増やさない — G11）。対象は**非可逆な作業消失だけ**——汎用の危険コマンド一覧
# （誤検知の密集地帯）は採らない。ローカルDBの破壊は `reset` 1発で戻る設計（§12.2）
# なので対象外。dirty 条件付き規則の回帰再生はコーパスの前提列（tests/guard_corpus.tsv）。

set -Eeuo pipefail
trap 'echo "guard_git_bypass: フック内部エラーのため fail-closed でブロック（GUARDRAILS.md §2）" >&2; exit 2' ERR

input=$(cat)
[ -n "$input" ] || exit 0

block() {
  echo "ブロック: $1 によるフック迂回は禁止（GUARDRAILS.md §2）。フックが落ちるなら迂回せず違反そのものを直すこと。2回連続で同じフックが落ちるなら原因調査に切り替える（ルート AGENTS.md §10-4）。" >&2
  exit 2
}

block_loss() {
  echo "ブロック: $1（GUARDRAILS.md §2 作業消失ガード）。消してよい変更なら先に commit / stash で退避するのが正規経路。人間の指示によるものなら、その旨を人間に確認してから人間側の端末で実行する。" >&2
  exit 2
}

word_present() {
  # \b相当（単語境界）の移植版。bash組み込みの [[ =~ ]] は MSYS2/Windows で \b が
  # 拡張として効かない（GNU grepだけの拡張——実測で判明。v2.22）ため、POSIX標準クラス
  # だけで「単語の前後が英数字/アンダースコア以外（または文字列端）」を組み立てる。
  [[ $1 =~ (^|[^[:alnum:]_])($2)([^[:alnum:]_]|$) ]]
}

worktree_dirty_or_unknown() {
  # 未コミットの作業があるか。判定不能（git 不在・リポジトリ外）はブロック側に倒す
  # （fail-closed — §2）。クリーンなら 1 を返し、dirty 条件付き規則は素通しになる。
  local out
  out=$(git -C "${CLAUDE_PROJECT_DIR:-.}" status --porcelain 2>/dev/null) || return 0
  [ -n "$out" ]
}

if command -v jq >/dev/null 2>&1; then
  # --- 精密経路: コマンド文字列を抽出し、引用符の中身を除去してから判定 ---
  # v2.22（G11・性能是正）: 判定は bash 組み込みの [[ =~ ]]／パターン展開へ置き換え、
  # grep/tr の子プロセス生成を無くした（jq・sed の2個だけ残す——量が多いのはブール判定側で、
  # そちらは組み込みで完全代替できる。sed の可変長「引用符の中身を全部消す」は組み込み
  # パターン展開だけでは安全に再現しづらく、jq 同様そのまま残置）。実測: Windows 32コア機で
  # 1回の呼び出しが約1000ms→約80msへ短縮（tests/guard_corpus.tsv 全74行で before/after
  # 完全一致を確認 — GUARDRAILS.md §7.7）。
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
  [ -n "$cmd" ] || exit 0
  no_newlines=${cmd//$'\n'/ }
  stripped=$(printf '%s' "$no_newlines" | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g')

  # 全フック迂回: core.hooksPath の付け替え（`git config core.hooksPath …`・`git -c core.hooksPath=…`）。
  # フック本体ごと差し替えれば --no-verify 検査は無意味になるため、git を含むコマンドでの
  # 言及自体をブロックする（キー名は git 仕様どおり大文字小文字非区別で判定・過剰ブロック側に倒す）。
  if word_present "$stripped" git; then
    shopt -s nocasematch
    hookspath_hit=0
    [[ $stripped =~ hookspath ]] && hookspath_hit=1
    shopt -u nocasematch
    [[ $hookspath_hit -eq 1 ]] && block 'core.hooksPath の変更（フック本体の付け替え）'
  fi

  # 全フック迂回: pre-commit uninstall（シムの取り外し）。settings.json の deny は前方一致のみで
  # `cd x && pre-commit uninstall`・`uvx pre-commit uninstall`・`uv tool uninstall pre-commit` を
  # 通してしまう——引数順・経由の迂回を塞ぐのは主防壁の責務（--force と同じ二重構造）。
  if word_present "$stripped" pre-commit && word_present "$stripped" uninstall; then
    block 'pre-commit uninstall（フックシムの取り外し）'
  fi

  if word_present "$stripped" git && word_present "$stripped" 'commit|push'; then
    [[ $stripped == *--no-verify* ]] && block '--no-verify'
    [[ $stripped =~ (^|[\;\&\|[:space:]])SKIP= ]] && block 'SKIP='
    # git commit の -n / 結合短フラグ内の n も --no-verify の別名
    if word_present "$stripped" commit \
       && [[ $stripped =~ (^|[[:space:]])-[a-mo-zA-Z]*n[a-zA-Z]*([[:space:]]|$) ]]; then
      block '-n (--no-verify の別名)'
    fi
    # force push（--force / --force-with-lease / -f / 結合短フラグ内の f）。
    # settings.json の deny は前方一致のみで、引数順を変えた `git push origin -f` を
    # 通してしまう——引数順の迂回を塞ぐのは主防壁であるこのフックの責務（README の二重構造）。
    if word_present "$stripped" push; then
      [[ $stripped == *--force* ]] && block '--force push（--force-with-lease 含む。履歴を書き換えない）'
      if [[ $stripped =~ (^|[[:space:]])-[a-eg-zA-Z]*f[a-zA-Z]*([[:space:]]|$) ]]; then
        block '-f (--force の別名)'
      fi
    fi
  fi

  # --- 作業消失ガード（§2・Phase 14 — v2.5）: 非可逆な作業消失だけを塞ぐ ---
  # ① `.git` を含む rm -rf は**常時**ブロック（履歴＝全作業の非可逆な破壊。履歴ごと
  #    消えたら guard もコーパスも無力）。フラグ検出は結合形（-rf/-fr/-Rf/-rvf 等）の
  #    近似——分離形 `rm -r -f` は §7.4「近似は仕様」の範囲外（実測されたらコーパスと
  #    同一コミットで還元する）。引用符で包んだ `.git` は stripped から消えるため、
  #    生コマンド側の引用付きトークンも併せて見る（過剰ブロック側に倒す — §2）。
  if [[ $stripped =~ (^|[\;\&\|[:space:]])rm[[:space:]]([^\;\&\|]*[[:space:]])?-[a-zA-Z]*([rR][a-zA-Z]*f|f[a-zA-Z]*[rR]) ]]; then
    if [[ $stripped =~ (^|[[:space:]=/])\.git(/|[[:space:]]|$) ]] \
       || [[ $cmd =~ [\"\'].git(/|[\"\']) ]]; then
      block_loss '.git を含む rm -rf（リポジトリ履歴の非可逆な破壊）は常時ブロック'
    fi
  fi
  # ② dirty 条件付き: 未コミットの作業がある時だけ、それを消すコマンドをブロックする。
  #    クリーンなら同じコマンドは無害なので素通し（dirty 条件が誤検知をほぼ消す）。
  #    広域判定の `.` は checkout/restore の**後**の単独トークンのみ（`git add .` 等の
  #    複合コマンドで誤検知しない）。`git restore --staged .` はインデックス操作のみで
  #    作業ツリーは無傷のため対象外（--worktree / -W を伴えば対象）。
  if word_present "$stripped" git; then
    wipe=''
    if word_present "$stripped" reset && [[ $stripped == *--hard* ]]; then
      wipe='git reset --hard'
    elif word_present "$stripped" clean \
         && { [[ $stripped == *--force* ]] \
              || [[ $stripped =~ (^|[[:space:]])-[a-eg-zA-Z]*f[a-zA-Z]*([[:space:]]|$) ]]; }; then
      wipe='git clean -f'
    elif word_present "$stripped" checkout \
         && [[ $stripped =~ checkout[^\;\&\|]*[[:space:]]\.([[:space:]]|$) ]]; then
      wipe='広域の git checkout -- .'
    elif word_present "$stripped" restore \
         && [[ $stripped =~ restore[^\;\&\|]*[[:space:]]\.([[:space:]]|$) ]]; then
      if [[ $stripped =~ --staged|(^|[[:space:]])-[a-zA-Z]*S ]] \
         && [[ ! $stripped =~ --worktree|(^|[[:space:]])-[a-zA-Z]*W ]]; then
        wipe=''  # --staged のみ＝インデックス操作。作業ツリーの消失ではない
      else
        wipe='広域の git restore .'
      fi
    fi
    if [ -n "$wipe" ] && worktree_dirty_or_unknown; then
      block_loss "未コミット作業がある状態での ${wipe}（非可逆な作業消失。クリーンなツリーなら素通しになる）"
    fi
  fi
else
  # --- 保守的経路（jq 不在）: 生JSONに対するマッチ。誤検知は過剰ブロック側に倒す（fail-closed） ---
  if printf '%s' "$input" | grep -Eq '\bgit\b' && printf '%s' "$input" | grep -iq 'hookspath'; then
    block 'core.hooksPath（保守的判定: jq 導入で精密化できる）'
  fi
  if printf '%s' "$input" | grep -Eq '\bpre-commit\b' && printf '%s' "$input" | grep -Eq '\buninstall\b'; then
    block 'pre-commit uninstall（保守的判定: jq 導入で精密化できる）'
  fi
  if printf '%s' "$input" | grep -Eq 'git[^"]*\b(commit|push)\b|"(commit|push)\b' ; then
    printf '%s' "$input" | grep -q -- '--no-verify' && block '--no-verify（保守的判定: jq 導入で精密化できる）'
    printf '%s' "$input" | grep -Eq '(^|[;&|[:space:] "])SKIP=' && block 'SKIP=（保守的判定: jq 導入で精密化できる）'
    if printf '%s' "$input" | grep -Eq 'git[^"]*\bcommit\b|"commit\b' \
       && printf '%s' "$input" | grep -Eq '(^|[[:space:]"])-[a-mo-zA-Z]*n[a-zA-Z]*([[:space:]\\"]|$)'; then
      block '-n（保守的判定: jq 導入で精密化できる）'
    fi
    if printf '%s' "$input" | grep -Eq 'git[^"]*\bpush\b|"push\b'; then
      printf '%s' "$input" | grep -q -- '--force' && block '--force push（保守的判定: jq 導入で精密化できる）'
      if printf '%s' "$input" | grep -Eq '(^|[[:space:]"])-[a-eg-zA-Z]*f[a-zA-Z]*([[:space:]\\"]|$)'; then
        block '-f（保守的判定: jq 導入で精密化できる）'
      fi
    fi
  fi

  # --- 作業消失ガード（保守的経路 — Phase 14。生JSONへのマッチ・過剰ブロック側）---
  if printf '%s' "$input" | grep -Eq '(^|[[:space:]"])rm[[:space:]]' \
     && printf '%s' "$input" | grep -Eq -- '-[a-zA-Z]*([rR][a-zA-Z]*f|f[a-zA-Z]*[rR])' \
     && printf '%s' "$input" | grep -Eq '\.git(/|[[:space:]\\"]|$)'; then
    block_loss '.git を含む rm -rf（保守的判定: jq 導入で精密化できる）'
  fi
  if printf '%s' "$input" | grep -Eq 'git[^"]*\b(reset|clean|checkout|restore)\b|"(reset|clean|checkout|restore)\b'; then
    wipe=''
    if printf '%s' "$input" | grep -Eq '\breset\b' && printf '%s' "$input" | grep -q -- '--hard'; then
      wipe='git reset --hard'
    elif printf '%s' "$input" | grep -Eq '\bclean\b' \
         && { printf '%s' "$input" | grep -q -- '--force' \
              || printf '%s' "$input" | grep -Eq '(^|[[:space:]"])-[a-eg-zA-Z]*f[a-zA-Z]*([[:space:]\\"]|$)'; }; then
      wipe='git clean -f'
    elif printf '%s' "$input" | grep -Eq '\b(checkout|restore)\b[^;&|"]*[[:space:]]\.([[:space:]\\"]|$)'; then
      wipe='広域の git checkout / restore（. 指定）'
    fi
    if [ -n "$wipe" ] && worktree_dirty_or_unknown; then
      block_loss "未コミット作業がある状態での ${wipe}（保守的判定: jq 導入で精密化できる）"
    fi
  fi
fi

exit 0

# PROMPT_claude_code_update.md — 導入済みリポジトリをキットの新版へ更新する時に Claude Code へ貼るプロンプト

使い方: **既にこのキットを導入済み（ブートストラップ完了/進行中）のリポジトリ**を新しい版の
キットへ更新する場合に使う（初回導入は `PROMPT_claude_code.md` / `PROMPT_claude_code_existing.md`）。
新版の zip をリポジトリルートに置き、下の「入力」の ★ を埋め、罫線から下の全文を
リポジトリルートで起動した Claude Code の**最初のメッセージ**として貼り付ける。

---

## 入力（ユーザー記入欄）

- 特記事項: ★（既存維持したいファイル・触ってほしくない箇所など。無ければ「なし」）

## 任務

このリポジトリに導入済みのガードレール・キットを、ルートに置かれた新版 zip の内容へ更新する。
契約の正本は更新**後**の `.guardrails/GUARDRAILS.md`。以下の Step U0〜U6 を順に実行し、
途中でターンを終えない。物理的ブロッカーは応答の先頭を `BLOCKED:` で始めて報告する。

## 前提（この更新方式が成立する理由）

- インストーラの `UPGRADED` 判定は「キット系統＋git 追跡済み＋クリーン」のファイルを
  新版で上書きする——**旧内容は git 履歴が安全網**。消えた採用先ローカル部は履歴から
  機械的に復元できる。
- `.pre-commit-config.yaml` / `.claude/settings.json` / `.codex/hooks.json` はトークン
  検証つきの KEPT/CONFLICT——新版でフックが増えていれば CONFLICT に落ち、ヒントに
  統合先が書いてある（黙って届かない、は起きない — `installer-token-drift` が原本側で保証）。
- 更新差分の機械入力は **GUARDRAILS §10 の Phase 見出し**（追記専用の連番）——
  版ファイルは存在しない（正本は git タグ — G5）。

## 手順

- **Step U0（前提確認。コミットしない）**:
  ① git リポジトリであること・**作業ツリーがクリーン**であることを確認する
  （dirty なら停止してユーザーに退避を依頼——UPGRADED は クリーンが条件）。
  ② 更新前の基準線を採取: `uv run scripts/dev.py check` の全出力・
  現在の `.guardrails/GUARDRAILS.md` §10 の **Phase 最大番号**・
  `scripts/repo_scan.py` の `BINDING-SOURCE` 刻印（列ID@版）。
  ③ 一時停止中の規則（清掃 Phase 登録済みの BINDING 空リスト等）の一覧を控える——
  **更新はこれらを勝手に再有効化しない**。
- **Step U1（機械配置）**: `python3 -m zipfile -e guardrails-kit-*.zip .guardrails-kit-src` →
  `python3 -c "import glob,subprocess,sys; hits=glob.glob('.guardrails-kit-src/**/scripts/install_kit.py',recursive=True); sys.exit('scripts/install_kit.py が見つからない' if not hits else subprocess.run([sys.executable,hits[0]]).returncode)"`
  （`python3` が無ければ `py -3` / `uv run --no-project`）。レポート全行を保存する。
  `CONFLICT` は各行のヒントに従い**既存側へ統合**（既存エントリ・採用列の追記を消さない）
  して再実行（冪等）。**exit 0 になるまで Step U2 へ進まない**。
- **Step U2（消えた充填の復元）**: `git diff` で UPGRADED による消失分を確認し、
  旧版の内容（`git show HEAD:<path>`）から**採用先ローカル部だけ**を新版ファイルへ
  再適用する。対象の典型: `scripts/repo_scan.py` の BINDING 充填と `BINDING-SOURCE` 刻印・
  `scripts/dev.py` の COMMANDS・`guardrails-ci.yml` の列ジョブ・
  `.guardrails/GUARDRAILS.md` §10 の**自リポジトリの状態記録**（清掃 Phase・保留・✅）。
  **復元の向きを間違えないこと**: 新版ファイルを土台に旧充填を移植する。旧ファイルの
  区画を丸ごと戻すのは禁止——新版で増えたスロット（BINDING の新変数等）が消えると
  検査器ごと落ちる。復元後、post_edit/lint フックの指摘はその場で解消する。
- **Step U3（更新差分の把握。読み取りのみ）**: 旧 GUARDRAILS
  （`git show HEAD:.guardrails/GUARDRAILS.md`）と新 GUARDRAILS の diff から
  ① §10 の**増えた Phase**（U0 で控えた最大番号より後）を列挙し、
  ② §3.3 の規則一覧・§11 Step の変更点を対応づける。
  `bindings/catalog.md` の採用列の**版が上がっていれば**、paste-block の差分も列挙する。
- **Step U4（新しい門の実体化）**: U3 で列挙した増分ごとに実施する:
  列充填が要るもの → カタログ新版の paste-block 差分を BINDING へ適用（刻印の版も更新——
  §12.7）。設定が要るもの → 新 Step の記述どおり（例: required checks・フック種の追加）。
  **各門に違反注入 DoD**（わざと違反して落ちる→解消して通る、を実測）。
  一時停止中の規則（U0 ③）はそのまま維持し、新版がその規則自体を変えていれば
  清掃 Phase の記述だけ現行化する。
- **Step U5（検証）**: ① `pre-commit install` を再実行（フック種が増え得る——忘れると
  静かに無効 §0。`hook-type-missing` が検出はする） ② `uv run scripts/dev.py check` を
  実行し **U0 の基準線と比較**する——増えた指摘は「新しい門の正しい検出」か「復元漏れ」かを
  1件ずつ判定し、復元漏れは直す ③ guard コーパス再生・（新版に在れば）
  `check_bootstrap.py --verify-scenarios` ④ 既存テスト一式。
- **Step U6（コミット）**: 原則1コミット（大きければ「機械配置＋復元」と「新しい門の
  DoD」の2つまで）。件名: `chore: ガードレールキット更新（Phase <旧最大>→<新最大>）`。
  本文: 効くG（例: G13）・UPGRADED/CONFLICT 解消の要約・復元した充填の一覧・
  新しい門ごとの DoD 結果1行。**push はユーザーに確認してから**。

## 絶対規則

1. 履歴を書き換えない・force push しない（`--no-verify` 等はフックが技術的にもブロックする）。
2. 充填値を黙って変えない——値を変えたくなったら `bindings/catalog.md` の列の版上げが
   正規経路（§12.7。更新のついでの黙修正は binding-drift の人間版）。
3. 一時停止中の規則（清掃 Phase）を更新のついでに再有効化しない——それは清掃 Phase の
   仕事（着手可否はユーザー判断）。
4. アプリの挙動を変える変更を混ぜない。
5. 解消できない CONFLICT・判断の要る差分（例: 大きく書き換えた GUARDRAILS の統合）は、
   推測で潰さずレポートに載せてユーザーへ確認する。

## 報告形式

Step U6 完了時に更新レポートを提示する: ① 版の移動（Phase <旧>→<新>・BINDING-SOURCE
刻印の版） ② インストーラ判定の内訳（UPGRADED/KEPT/CONFLICT→解消） ③ 復元した
充填の一覧 ④ 新しい門と各 DoD 結果 ⑤ `check` の基準線差分（増減した指摘と判定）
⑥ 残課題（ユーザー判断待ちの項目）。

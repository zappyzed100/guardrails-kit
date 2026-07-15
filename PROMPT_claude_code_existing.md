# PROMPT_claude_code_existing.md — 既存リポジトリへ導入する時に Claude Code へ貼るプロンプト

使い方: **既にコードがあるリポジトリ**にキットを導入する場合はこちらを使う（まっさらな
新規リポジトリなら `PROMPT_claude_code.md`）。下の「入力」の ★ を埋め、罫線から下の全文を
リポジトリルートで起動した Claude Code の**最初のメッセージ**として貼り付ける。

---

## 入力（ユーザー記入欄）

- 言語・レイヤー構成: ★（分かる範囲で。「コードから読み取って Step -1b で提案せよ」でも可）
- 確率的コンポーネント: ★ 有 / 無 / 不明（有なら: コンポーネント名・本体の呼び出し関数名）
- 触ってはいけない領域: ★（凍結中のディレクトリ・自動生成物・他チーム管轄など。無ければ「なし」）
- 既存テストの状態: ★ 緑 / 一部赤 / 不明（赤がある場合の扱いは Step 0 で必ず確認される）
- 採用するバインディング列: ★（`bindings/catalog.md` の列ID@版。「コードから判断して Step -1b で提案せよ」でも可）
- ランタイム到達経路（操作レール）: ★（分かる範囲で。Step -1b の棚卸しで補完される — §12.4）
- 中核不変条件: ★（壊れたら致命の性質。分かる範囲で — §12.6）
- 外部I/O一覧: ★（分かる範囲で。Step -1b の棚卸しで補完される — §9.5）
- GitHub リモート URL: ★（Step 9 の CI 実測に必要）
- workflow信頼境界の人間CODEOWNER: ★（一人開発なら本人。PR作者は別のmachine user/GitHub App）
- 特記事項: ★（無ければ「なし」）

## 任務

この**既存リポジトリ**に「LLM の作業出戻りを防ぐガードレール」を敷設する。手順・契約・
完了条件の正本は `.guardrails/GUARDRAILS.md`。まず全文を読み、**§11 の Step 0→10 を、
本プロンプトの「既存リポジトリ向けの読み替え」を適用した上で**、§10 冒頭の実行規律
（順序固定・1 Step = 1 ブランチ = 1 PR・違反注入必須・虚偽✅禁止・途中でターンを終えない）
に従って完遂すること。

## 新規リポジトリとの前提の違い（この3つが全読み替えの理由）

1. **既存コードには違反が眠っている**。全 hard 規則を即時有効化すると、その瞬間から
   全コミットが止まり、清掃作業自体ができなくなる。→ 対策は「猶予の可視化」:
   違反が残る規則は BINDING で一時停止し、**必ず .guardrails/GUARDRAILS.md §10 に清掃 Phase として
   登録**する（見えない緩和・黙った無効化は禁止）。
2. **既存ファイルと衝突し得る**。CLAUDE.md・CI ワークフロー・analysis_options.yaml・
   .gitignore・.gitattributes・.claude/settings.json などが既にあれば**マージであって
   上書きではない**。衝突の検出・停止は Step -1a のインストーラが機械的に行い（黙った
   上書きは構造的に起きない）、統合の実施は各 Step が担う。
3. **既存の挙動・履歴・公開ブランチを守る**。機構導入と挙動変更を同一コミットに混ぜない。
   force push・履歴書き換えはしない（秘密が履歴に見つかっても報告のみ——対処はユーザー判断）。

## 配置済みファイル（新規用と同じ。ゼロから書き直さない）

v2キットは言語なしで出荷され、言語固有値は `bindings/catalog.md` の検証済み列に集約
（採用列の paste-block を**管理区画 `>>> GUARDRAILS BINDING >>>` の内側**へ充填し
`BINDING-SOURCE` を刻印——§12.7。区画内の充填はキット更新時に自動継承される — Phase 44）:
`scripts/repo_scan.py`（末尾の管理区画＝充填先）、`scripts/dev.py`
（動詞ルーター。管理区画内で `COMMANDS.update({...})`——全置換は既定配線を消すため禁止 §12.1）、`.guardrails/GOALS.md`・`bindings/catalog.md`（正本）、
`scripts/generate_structure.py` / `check_structure.py` / `check_commit_msg.py`（BINDING 参照のみ）、
`.pre-commit-config.yaml`（BINDING マーカー以下の pre-push フック群）、
`.claude/hooks/post_edit_format.py`・`post_edit_lint.py`（DISPATCH 辞書——整形とlintの直列2段 §1）、
`.claude/hooks/guard_git_bypass.py`（迂回＋作業消失ガード）・
`.claude/hooks/stop_incomplete_guard.py`（§2b）・`.claude/settings.json`（言語非依存）、
`tests/guard_corpus.tsv`＋`scripts/check_guard_corpus.py`（§2 の門番回帰テスト・言語非依存）、
`.github/workflows/guardrails-ci.yml`（BINDING マーカー以下）、
`.python-version`・`.gitattributes`・`CLAUDE.md.template`・`scripts/install_kit.py`
（配置・マージ・後片付け専用——Step -1a。再実行は冪等）。

既存の `.claude/settings.json` がある場合、インストーラは衝突を報告して止まる（黙って
上書きしない）。マージ時は `hooks` の **PostToolUse / PreToolUse（Bash と
Edit|Write|MultiEdit の2 matcher）/ Stop / SessionStart の4キー**と `permissions.deny` を
欠かさず取り込むこと（Stop / SessionStart キーの取りこぼしは §2b / §2c が静かに不在に
なる——`check` の `missing-required` がフック実体の消失は検出するが、settings 側の
配線はインストーラの検証が正本）。

**check_structure の全 hard 規則は BINDING のパターンリストで個別に停止できる**
（空リスト＝不発。例: `LAYER_FORBIDDEN_IMPORTS = []` でレイヤー検査停止）。既存リポジトリ
導入ではこれを「猶予」の実装手段として使う。停止する場合は必ずコメントで
`（Phase N で再有効化 — §10）` と清掃 Phase 番号を明記する。

## 既存リポジトリ向けの読み替え（Step -1a/-1b を追加し、Step 0〜10 を修正）

- **Step -1a（配置。コミットしない）**: キットが zip / 展開フォルダのままなら、
  **手でコピーせず**配置する（配置済みならスキップ）:
  `python3 -m zipfile -e guardrails-kit-*.zip .guardrails-kit-src` →
  `scripts/install_kit.py` を探す（GitHub の Download ZIP / Release zip は
  `<repo>-<ブランチ/タグ>/` で1階層ネストされるため固定パスで決め打ちしない——
  `python3 -c "import glob,sys; hits=glob.glob('.guardrails-kit-src/**/scripts/install_kit.py',recursive=True); print(hits[0] if hits else sys.exit('scripts/install_kit.py が見つからない'))"`。
  `python3` が無ければ `py -3` / `uv run --no-project`）。実行は3段（v2.42 の CLI — §11 前段）:
  ① **`<installer> --detect`** — 採用列の候補と「機械で導出できない残りの質問」を採取
  （Step -1b ①と Step 0 の入力になる。手でコードを読む前に機械に読ませる）
  ② **`<installer> --diff`** — 書き込みなしで全判定＋差分行数をプレビューし、CONFLICT に
  なるファイルと原因を**統合作業の前に**全部把握する（1件ずつ踏んで戻るループを消す）
  ③ 本実行 — 既存リポジトリでは `CONFLICT` が出るのが普通。各行のヒントに従い
  **既存側へキット要件を統合**（既存エントリは消さない）して再実行し（冪等）、意図して
  既存を維持する場合のみ `--skip <パス>` で明示する。**exit 0 になるまで Step -1b へ
  進まない**。exit 0 で zip・展開元は自動削除される。
  `.claude/settings.json` を今回配置・統合した直後は、ユーザーに「`/hooks` で
  PreToolUse: Bash・Edit|Write|MultiEdit / PostToolUse / Stop / SessionStart の4種
  5エントリの有効化を確認し、承認したら『続行』と返信してください」とだけ依頼して待つ
  （fail-open 防止 — §2・§2c。質問集約の例外）。『続行』を受けたら
  **`uv run scripts/dev.py probe --live`** の2段階（sentinel 発行→セッション内で実行→
  再実行で PASS 判定——§12.1・Phase 44）で、フックが**実経路で**発火していることを
  機械確認する。PASS しない場合は、`.claude/settings.json` を**このセッション中に
  新規作成/統合**したことで、プロセスが起動時にしかフック設定を読み込んでおらず未反映と
  いう既知の症状の可能性がある（特に VSCode 拡張のパネル経由）。その場合はユーザーに
  「このセッションを終了し、VSCode なら拡張のウィンドウをリロード（または別のターミナルで
  `claude` を同じディレクトリで直接起動）してから新しいセッションで続きを」と依頼して
  終了する。なお配置したキットファイル群は未コミットのまま Step 0 の最初のコミットに含める。
- **Step -1b（棚卸し・読み取り専用・コミットしない）**: 何も書き換えずに現状を測る。
  ① 言語・レイヤー・テスト配置・生成物・エントリポイントを確定する——出発点は
    Step -1a ①の `--detect` 出力（列候補＋根拠）。機械が出せない部分（レイヤー・
    エントリポイント）だけコードから読み取る
  ② 既存の CI / git フック / lint 設定 / CLAUDE.md 系文書の有無を列挙する——環境側は
    `uv run scripts/dev.py doctor` の事実表示（ツール・シム・hooksPath・フック配線）を
    そのまま使う。門の初期状態は `uv run scripts/dev.py gates` を採取（何が常時有効で
    何が列充填待ちかの一覧——棚卸しレポートの骨格になる）
  ③ `scripts/repo_scan.py` の BINDING を現実のパスに合わせて**作業コピー上で**仮調整し、
    `uv run scripts/check_structure.py` を実行して**規則IDごとの違反件数**を採取する
  ④ 既存テストを1回実行し赤/緑を採取する
  ⑤ `uvx gitleaks detect`（git 履歴込み）を1回実行し、現ツリー/履歴それぞれの検出を分けて記録する
  ⑥ ランタイムの棚卸し: ローカル起動・リセット・E2E の手段、時刻/乱数の注入シームの有無、
    外部I/O依存を列挙する（§12・Step 0 のD表の充填元）
  ⑦ 以上を「棚卸しレポート」として提示する。**ここでユーザーに確認するのは次の3点のみ**:
    赤テストの扱い（直す/該当ゲートを Phase 送りにする）・大規模是正が必要な規則
    （目安: 違反50件超 or 挙動変更を伴う）の扱い・履歴内の秘密の扱い。
- **Step 0（入力確定）**: 棚卸し結果＋上の「入力」から表A/B/Cの全セルを埋める。
  **充填と刻印は手で貼らず `uv run scripts/fill_bindings.py <列ID@版>`**（Phase 47——
  YAML 系と、一時停止のための空リスト化だけが手作業）。充填後
  `uv run scripts/dev.py dod` で列コーパスの規則DoDを機械再生する。加えて
  **「規則ID × 違反件数 × 方針（即時有効 / Phase 送り）」の判定表**を作り、.guardrails/GUARDRAILS.md に
  記録して最初のコミットにする。方針の既定則: 違反0件の規則→即時有効。機械的に直せる違反
  （役割ヘッダー欠落、少数の print 直呼び等）→該当 Step の中で清掃して有効化。構造是正を
  要する違反（layer-violation 多数、巨大ファイル分割等）→ BINDING で一時停止し §10 に
  清掃 Phase 登録。**契約（§1〜§9）自体は緩めない——緩めるのは「いつから効くか」だけ**。
- **台帳の運用（全 Step 共通 — .guardrails/GUARDRAILS.md §3.5）**: 進捗の正本は `.guardrails/BOOTSTRAP.md`
  （install_kit が配置）。Step 0 で固有名詞リストCを台帳へ記入し、各 Step の完了時に
  該当行を ✅ にして**その Step の実装と同一コミット**に含める（1コミット1Step・番号順——
  `check-bootstrap` が再実行検証。既存リポジトリで本当に対象外の Step は — ＋備考の理由）。
- **Step 1（文書と正規化。骨格は作らない）**: 既存構造を尊重し、ディレクトリを動かさない。
  既存の `CLAUDE.md` / `AGENTS.md` があれば、その記述を**消さずに** `AGENTS.md` の
  章構成（§0〜§13 相当）へ移設・追記で整え、`CLAUDE.md` は `CLAUDE.md.template` どおり
  冒頭 `@AGENTS.md`＋Claude Code 固有節の薄い層に**同一コミット**で置き換える（§6。
  どちらも無ければ両テンプレから完成させる）。`.gitattributes` の導入は
  **改行正規化の巨大 diff を生むため単独コミット**にする:
  `git add --renormalize .` → `chore: 改行をLFへ正規化（機構導入の前提）`。
  ここに機能変更を1行も混ぜない。
- **Step 2（スクリプト調整と初回生成）**: BINDING を Step 0 の判定表どおりに確定
  （現実のパス・即時有効の規則・一時停止の規則＋Phase 番号コメント）。STRUCTURE.md を
  初回生成。DoD は新規用と同じ（決定性2回一致・--check の exit 0/1・内部エラー exit 2・
  **有効化した全規則**への違反注入——コーパス対象は `uv run scripts/dev.py dod` の一括
  再生が実績・手動は対象外5分類の分のみ（Phase 47。dod で済む注入を手でやり直さない
  ——実行規律6）・2秒以内）＋「一時停止した規則が §10 に全件 Phase 登録
  されている」こと。
- **Step 3（pre-commit 導入）**: 導入前にまず `uvx pre-commit run --all-files` 相当で
  衛生フックを全ファイルに1回当て、その差分だけを `chore: 衛生チェック一括適用` として
  単独コミットする（導入直後に無関係な差分でフックが落ち続けるのを防ぐ）。その後
  `uv tool install pre-commit==4.6.0` → `pre-commit install` → 違反注入3種の実測（新規用と同じ）。
  gitleaks が**現ツリー**で検出したものはこの Step で除去する。**履歴のみ**の検出は
  対処しない（Step -1b で報告済み——鍵ローテーション/履歴書き換えはユーザーの判断）。
- **Step 4（迂回防止）**: `.claude/settings.json` が既にある場合は permissions.deny と
  hooks を**マージ**する（既存エントリを消さない）。DoD は新規用と同じ実測3点。
- **Step 5（commit-msg）**: 新規用と同じ。規約は**このコミット以降**に適用される
  （既存履歴の書き換えはしない）。
- **Step 6（push 段と lint 昇格）**: 既存テストが緑であることが前提（赤は Step 0 の決定に
  従う——直してから、または該当テストコマンドのゲートを Phase 送りにして §10 登録）。
  lint 昇格（avoid_print 等の error 化）は既存違反を一斉に赤にするため、
  **print 清掃 Phase（Step 7）と同一 PR** で入れる判断も可——その場合も §10 に明記する。
- **Step 7（ログ単一出口）＝清掃 Phase の代表例**: ①単一出口を実装 ②**既存の print 系
  直呼びを全て移行** ③ BINDING の一時停止を解除して `log-direct-call` を有効化
  ④違反注入で落ちるのを実測（`log-direct-call` はコーパス対象——`dev.py dod` でよい）
  ——を**1つの PR** で行う（検査だけ足して移行しないのは禁止。
  違反ゼロ＋規則有効で初めて完了）。他の一時停止規則も同じ型で: 清掃→再有効化→違反注入。
- **Step 8（テスト決定性）**: 新規用と同じ。既存テストに非決定パターンがあれば、
  ここで修正してから規則を有効化する（修正が大きければ Step 0 の判定表どおり Phase 分割）。
- **Step 9（CI）**: 既存ワークフローがあれば checks ジョブ等を**既存へ統合**し、重複実行を
  作らない。無ければ `guardrails-ci.yml` をそのまま使う。DoD は新規用と同じ
  （正常 PR 緑＋ Web エディタからの違反 PR が赤＋検証ブランチ削除）。PR必須・bypassなし、
  4コアjob（`checks` / `red-first` / `commit-msg-history` / `workflow-integrity`）と採用した
  全言語別jobのrequired登録、CODEOWNERS placeholder置換、workflow群・integrity検査器・
  CODEOWNERS自身へのcode owner review必須化まで実測する。required checkの期待送信元は
  全てGitHub Actions Appに固定し、`any source`にしない。
  `dismiss stale reviews` または `require last push approval` も有効にする。
- **Step 10（総合監査）**: 新規用の監査に加えて、①一時停止中の規則が「BINDING のコメント
  ⇔ §10 の Phase」で1対1に対応している（片方だけの幽霊猶予が無い）②清掃済み Phase の規則が
  実際に有効で違反注入で落ちる ③棚卸しレポートの違反件数と現在値の差分（何件解消し、
  何件が Phase 待ちか）を最終報告に含める。監査コマンドは
  `uv run scripts/dev.py selftest`（門コーパス3種一括）→ `doctor`（環境＋check）→
  `gates`（全門の最終状態——Step -1b の初期採取との差分が「この導入で有効化された門の
  一覧」としてそのまま最終報告になる）。

## 絶対規則（既存リポジトリ特有）

1. main へ直接 push しない・force push しない・履歴を書き換えない。
2. 機構導入コミットに、アプリの挙動を変える変更を混ぜない（清掃は refactor:/chore: として
   分離し、挙動が変わらないことをテストで担保する）。
3. 「触ってはいけない領域」（入力欄）には検査で違反が出ても手を入れない——BINDING の
   除外（GENERATED_PATTERNS 等）に登録し、§10 に理由つきで記録する。
4. 規則の一時停止は必ず「BINDING のコメント + §10 の Phase 登録」のセット。どちらか片方
   だけの停止は虚偽 ✅ と同種の違反として扱う。
5. 大規模是正（違反50件超・アーキテクチャ変更を伴うもの）は勝手に着手せず、規模見積りを
   §10 の Phase として登録して報告する（着手可否はユーザー判断）。

## 報告形式

Step -1b 完了時に棚卸しレポート（言語/構成、規則IDごとの違反件数、テスト赤緑、秘密検出、
既存設定との衝突一覧、Phase 送り提案）を提示し、3点の確認だけ受けてから Step 0 へ進む。
以降は各 Step 完了時に「実行コマンド / 違反注入の失敗出力（抜粋）/ 解消後の成功出力（抜粋）/
コミットハッシュ」を短く報告して止まらず進み、Step 10 で最終監査結果
（チェックリスト全✅＋違反件数の増減表＋残 Phase 一覧）を報告し、**`.guardrails/CUSTOMIZE.md` の
存在と読みどころを1行で案内**して終了する。

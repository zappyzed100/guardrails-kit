# README_SETUP.md — ガードレール・キットの配置と使い方（旧 README_配置手順.md）

## このキットの目的

**LLM エージェント（Claude Code / Codex / Cline 等）によるアプリ開発を、善意や心得ではなく機械的な仕組みで——
出戻りなく・バグ少なく・速く——回せる状態にする**こと。あらゆる言語・あらゆるアプリで
使い回せることが前提。判定基準は3レンズ:

1. **LLMにとって取り扱いやすい**（決定性・一発到達・文脈最小・機械可読な即時フィードバック・単一の正）
2. **バグが減る**（変更面の最小化・不変条件の機械強制・非決定の検疫・沈黙の禁止・回帰の複利）
3. **開発時間が短縮できる**（ループ秒速・質問の前払い・移植の定数時間）
4. **意図の保存**（意図の複利——新しい構造には設計根拠が同コミットで残る。v2.8 新設の第4レンズ）

この3＋1レンズを判定可能な14条に固定したのが **`.guardrails/GOALS.md`（目標の正本）**、それを実現する
機構の契約が **`.guardrails/GUARDRAILS.md`（契約の正本）**、言語固有の具象値が
**`bindings/catalog.md`（バインディングの正本）**——という三層構成。迷ったらこの順で読む。

## このキットの中身

このキット（v2）は .guardrails/GUARDRAILS.md の各機構（§1〜§9・§12）の**言語なし実装**です。
言語固有値は `bindings/catalog.md` の検証済み列（TS/React・Python・Dart/Flutter・Rust）
に集約してあり、Claude Code が .guardrails/GUARDRAILS.md §11 の手順で採用列を充填します。ユーザーがやることは
**「1. 配置 → 2. 前提ツール → 3. プロンプト貼り付け」の3つ**です。

プロンプトは対象リポジトリの状態で使い分けます:

| 対象 | 使うプロンプト | 違い |
|---|---|---|
| まっさらな新規リポジトリ | `PROMPT_claude_code.md` | 骨格を作り、ゲートを先に立て、違反ゼロから始める |
| 既にコードがあるリポジトリ | `PROMPT_claude_code_existing.md` | 棚卸し（Step -1）→ 違反が残る規則は BINDING で一時停止し §10 に清掃 Phase 登録 → 規則ごとに「清掃＋再有効化＋違反注入」を1PRずつ |

## v2.25 での変更点（非決定性テストの免除機構。根拠は `.guardrails/GOALS.md` のG）

`test-sleep`/`test-nondeterminism`/`test-network` に免除経路を追加した回（正本:
.guardrails/GUARDRAILS.md §9.5・§10 Phase 35）。実タイミング競合の再現テストのように、非決定性の
再現そのものがテストの本質という正当なケースがあり、`NO-LOG:`（§8.4）・
`RED-FIRST-EXEMPT:`（§5）と同型の「存在検査のみ・理由必須」境界を持つ
`NONDETERMINISM-EXEMPT: 理由` コメントで免除できるようにした。

- 免除は該当行の前後3行以内（`NONDETERMINISM_EXEMPT_WINDOW`・列上書き可）——3規則が
  同一テストで同時に発火しうるため、単一のコメントでまとめて免除できる設計。
- `test-calls-solver-direct` は対象外（既に別の免除経路を持つ）。
- 詳細: `.guardrails/CUSTOMIZE.md` §5「個別の逃げ道」に追記。

## v2.24 での変更点（v2.23 からの完遂＋是正。根拠は `.guardrails/GOALS.md` のG）

v2.23で見送った残り4フックの言語統一を完遂した回（正本: .guardrails/GUARDRAILS.md §10 Phase 34）。
あわせて、フック本体をPython化しても呼び出すツールが遅ければ効果が薄いという観点から、
post-editフックが呼ぶ外部ツールの呼び方も見直した。

- **`stop_incomplete_guard.py`・`session_baseline.py`・`post_edit_format.py`・
  `post_edit_lint.py`**: 全てPython化。実測は698ms→157ms（3.5倍）・356ms→171ms
  （2.1倍）等。`session_baseline.py`は移植直後にCRLF/LF不一致（Windowsでの
  `write_text`既定動作）を検出・修正——bash版とのバイト完全一致を確認。
- **post_edit フックが呼ぶツールの直接呼び出し化**（`bindings/catalog.md`「post_edit
  フックの速度3原則」）: `npx prettier`（実測約900ms/回・ローカルinstall済みでも）を
  `node_modules/.bin/prettier`直接呼び出し（約240ms/回）へ、`uvx ruff`（約218ms/回）を
  `uv tool install ruff`後の直接呼び出し（約156ms/回）へ変更。**この差はフック本体の
  言語移行そのものより実利用への影響が大きい**——ホットパスの支配コストは「ガードの
  コード」ではなく「ガードが待つツール」だった。
- **Biomeを ts-react-web 列の代替として調査・記録**（採用はせず）: 公開ベンチマークで
  ESLint比10〜35倍・Prettier比35倍という報告を確認し出典つきで記録。単一バイナリで
  lint+format+import整理を1execに収められる点も記録したが、既定（prettier+eslint）は
  維持——乗り換えは各プロジェクトの判断（列の版上げで記録する設計は変えない）。
- **rust列の整形を`cargo fmt`（クレート単位・cwd切替要）から`rustfmt {file}`
  （単一ファイル直接）へ変更**: DISPATCH辞書が素のargv実行のみを想定するための対応
  だが、post-editの「1ファイル・数秒予算」という契約そのものにも単一ファイル直接
  呼び出しの方が合っている。
- 全6フックがPython化で統一——`.claude/hooks/`配下にbash実装は0本になった。

## v2.23 での変更点（v2.22 からの言語移行。根拠は `.guardrails/GOALS.md` のG）

「他にも同種の遅い実装は無いか」「そもそもbash採用に根拠はあるか」という観点から
全フックを棚卸しし、`guard_git_bypass.sh`（v2.22是正後も jq・sed の2プロセスが
残存）と `guard_human_wip.sh` を Python へ完全移行した回（正本: .guardrails/GUARDRAILS.md §10 Phase 33）。

- **Go/Rustも候補に入れてセットアップ時に最速を実測選択する案は不採用**: 実装が
  言語の数だけ増えG5「単一の正」に反する・Step 0にコンパイル/ベンチマーク工程が
  増えG13「移植の定数時間」に反する・Go/Rustのツールチェーンがキット自体の新規
  必須依存になり重複排除ゲート違反（キットの必須言語ツールは `uv` のみ）。
- **`guard_git_bypass.py`**: jq/sed/grep/tr の子プロセスが標準ライブラリで完結し
  git status 呼び出し以外はゼロに。実測 約243ms/回→約150ms/回。コーパス全74行を
  10回連続PASS。書き換え中にPython版own のバグ2件を発見・修正（stdinのUTF-8未設定・
  検証ハーネスの相対パス問題）——コーパスと手動比較それぞれが実際に機能した実例。
- **`guard_human_wip.py`**: 専用コーパスが無いため6ケースの手動比較で新旧完全一致を
  確認。実測 約593ms/回→約230ms/回（2.6倍）。.guardrails/GUARDRAILS.md §2の保留トリガー
  （このフックの改修発生）が本コミットで発火したことを明記——恒久コーパス化
  （`check_guard_corpus.py --hook` 拡張）は次回以降の宿題として残す。
- **未着手のまま残したもの**: `stop_incomplete_guard.sh`・`session_baseline.sh`・
  `post_edit_format.sh`・`post_edit_lint.sh`（優先度が低いと判断——理由は
  .guardrails/GUARDRAILS.md §10 Phase 33参照）。

## v2.22 での変更点（v2.21 からの是正。根拠は `.guardrails/GOALS.md` のG）

導入先プロジェクト（Windows・32論理コア機）で `guard-corpus` フックが pre-commit
チェーンの中で断続的にタイムアウトする事例が発生し、原因を実測で特定・是正した回
（正本: .guardrails/GUARDRAILS.md §7.7・§10 Phase 32）。

- **`check_guard_corpus.py` の並列度上限を32→12へ是正**（G11）: 「物理コア数より
  多めが有利」という旧前提を、32コア機での実測（1〜48並列を計測）で反証した——
  8並列で頭打ち、旧上限32は8並列と同等かそれ以下。
- **`guard_git_bypass.sh` 本体を bash 組み込み構文へ書き換え**（G7）: 1回の呼び出しで
  `grep`/`sed`/`tr`/`jq` が10〜18回起動していたのが根本原因（約1073ms/回）。bash 組み込みの
  `[[ =~ ]]`／パターン展開へ置き換え、jq・sed の2個だけ残置——約243ms/回（4.4倍）に短縮。
  `\b`（単語境界）が MSYS2/Windows の bash 正規表現エンジンで非対応と判明したため、
  POSIX標準クラスのみの自前実装（`word_present()`）に置き換えた。
- **書き換え直後、コーパス（`tests/guard_corpus.tsv`）が実際に36/74行の回帰を検出**——
  `\b`非対応によりDENYがALLOWへ後退する規模の回帰で、コーパス自身が門番の改修における
  安全網として機能した実例（G10）。全74行PASSを5回連続確認してから確定。
- **性能予算（§7.7）を実測に合わせて是正**: 「全行2秒以内」は複数コアでも達成不能な
  数字だったと判明——「全行10秒以内（目標5秒）」へ変更。実測は5〜8秒。

## v2.21 での変更点（v2.20 からの整備。根拠は `.guardrails/GOALS.md` のG）

セッション内の対話——「導入後にカスタムできる項目（数値調整・サンプル差し替え・
トリガー待ち機能・規則の一時停止・逃げ道・MCP追加・規約文書の編集）はユーザーに
通知されるのか」という問いから出発。答えは「されない」だった——機構は揃っているが、
存在を知らせる導線が無いという穴（G9）。

- **新規 `.guardrails/CUSTOMIZE.md`**（root）: 導入後にカスタムできる7項目の**索引**。中身を
  複製せず、.guardrails/GUARDRAILS.md の該当節へのポインタに徹する（複製は正本の分裂——Serena の
  `.serena/memories` 不採用と同じ理由でG5違反）。
- **導線を3箇所に追加**: `install_kit.py` の完了メッセージ／`.guardrails/BOOTSTRAP.md` の完了注記／
  両PROMPTファイルのStep 10報告フォーマット——ブートストラップが完了する瞬間に必ず
  1回は目に入るようにした。
- ファイル名はASCII（`.guardrails/CUSTOMIZE.md`）——日本語ファイル名はzip展開時の文字化けで
  メタ除外をすり抜ける事故が過去に実測されている（`README_SETUP.md` 改名の理由と同じ
  — G1）。

## v2.20 での変更点（v2.19 からの増築。根拠は `.guardrails/GOALS.md` のG）

セッション内の設計対話から出発した回（正本: .guardrails/GUARDRAILS.md §8.4・§10 Phase 31）。
「全関数にログを強制すべきか」という問いを、**重要度判定は機械化できない**という結論まで
詰め、代わりに「客観的に検出できる境界（I/O・外部呼び出し・エラーハンドラ）＋見えない
サボりを見える形に変える」という設計へ着地させた。

- **soft 検査 `missing-log-coverage`**（G9/G7/G4）: 境界の前後5行以内に `logOp` 呼び出しか
  `NO-LOG: 理由` コメントのどちらかを要求する。理由の妥当性は検証しない——存在検査のみ。
- 外部調査（2026-07-08）で裏付け: ESLint `eslint-comments/require-description`・Rust
  clippy `allow_attributes_without_reason`・SonarQube S108/S2486・Honeycomb の
  DBマイグレーションlinterが同型の「存在検査＋可視化」を採用済みと確認——独自発明ではない。
- 不採用の記録: 全関数一律強制（ノイズ・空呼びで骨抜き）／テスト実行時の出力量に応じて
  ログのON/OFFやソース上の位置を自動変更する案（出力量と重要度は無相関・G1決定性と衝突・
  レビューを経ない自己治癒ランタイム型の変更経路——詳細は §8.4）。
- **ログ単一出口の参考実装を python-uv 列に追加**（`bindings/catalog.md`@6）:
  「形式は決まっているというが、実際どんな形式かは規定しないのか」という問いに対する
  回答として、OpenTelemetry Logs Data Model の命名・12-factor app（ログはイベント
  ストリーム）・構造化ログの実務コンセンサスに揃えた1行1JSONの `log_op` を実装。実行して
  出力を確認し、`LOG_BOUNDARY_PATTERNS`/`LOG_CALL_PATTERN` も4ケースの違反注入DoDを通した。
  独自スキーマの発明ではなく、既存標準への収斂であることを明記。サンプルは貼り替え自由な
  出発点であり、キットの検査はその中身までは見ない（§8.2）。
- **是正: GitHub の Download ZIP / Release zip 配置手順が壊れていた**（G9）: `guardrails-kit-master.zip`
  のように GitHub のzipは中身が `<repo>-<ref>/` で1階層ネストされるため、
  `PROMPT_claude_code.md`・`PROMPT_claude_code_existing.md`・`README.md` が示す
  「`python3 .guardrails-kit-src/scripts/install_kit.py` を直接叩く」手順が
  `No such file or directory` で失敗することを実際に再現して確認した。加えて
  `install_kit.py` 自身の後片付けロジックも `kit_root.parent == target` の一致判定に
  依存しており、ネスト配置では該当せず `.guardrails-kit-src/` が無言で残る（G9違反）ことも
  発見。①3ファイルの手順を `glob` による探索へ変更 ②`install_kit.py` の後片付けを
  「target 直下の最初の階層コンポーネント」で判定する方式に変更——の2点を修正し、
  ネスト配置・フラット配置・想定外の名前の3ケースをそれぞれ実行して確認した
  （ネスト→完全に片付く／フラット→従来どおり片付く／想定外の名前→`NOTE:source-kept`
  で明示的に残る、の3通りとも実測どおり）。

## v2.19 での変更点（v2.18 からの整備。文書のみ・根拠は `.guardrails/GOALS.md` のG）

**2026-07-07 調査⑤（実企業の門運用——Rust bors / Uber SubmitQueue / Shopify Shipit /
GitLab・GitHub の標準機能化）**の回（正本: `surveys/SURVEY_COMPANY_GATES.md`。調査④と
重複する Meta / StrongDM は再判定しない）。**機構の追加はゼロ**——それが正直な結論。

- 新規発見は1系統のみ: **合流の門（マージキュー）が守るマージスキュー**（個別に緑の
  PR 同士の意味的衝突）は、**キットのローカル門と PR 単位 CI では原理的に守れない層**。
  これを設計上の見落としでなく「層の違い」として §10 保留に登録（トリガー = 並行 PR の
  常態化 or 合流起因の main 赤の実測。発火時は GitHub Merge Queue の設定のみ——Step 9 の
  required checks がそのまま前提になる）。既設の `push: main` 再実行が「即検知・非予防」の
  部分防御であることも明文化。
- 裏書き: Uber の「最悪日 revert 10%・緑率52%」は事後修正文化の実測コストとして記録。

## v2.18 での変更点（v2.17 からの増築。根拠は `.guardrails/GOALS.md` のG）

**2026-07-07 調査④（門主導アーキテクチャ群——Meta RADAR / StrongDM Dark Factory /
VibeReady / AST ゲート / サンドボックス）**の回（正本: `surveys/SURVEY_GATE_ARCHITECTURES.md`）。
大半は現行機構の外部裏書き（機械の門>人間レビューの実測データ等）で、本物の空白2つを採用:

- **hard 検査 `env-file-tracked`**（G7/G9）: 実値の入り得る `.env` 系の追跡を拒否
  （雛形3種は除外・列 += 可）。gitleaks は内容パターン検査＝低エントロピー実値の素通り
  経路を存在検査で塞ぐ。
- **soft 検査 `test-shrink`（§3.4 検査8）**（G10/G4）: fix/feat でテストファイル純減を警告。
  **既存テストの弱体化＝門を欺く最短路**は red-first の守備範囲外だった。警告の常態化は
  新保留「Clean Room 隔離テスト」のトリガー実測。
- **複雑度ゲートは対応表として正本化**（catalog 注記——自作 AST 検査は不採用・linter が
  上位互換）。**保留1件追加**: Clean Room 隔離テスト（permissions.deny + CI 専用実行の
  設計スケッチつき）。不採用/裏書き7群の記録は調査④参照（リスクスコア ML・独立モデル
  判定＝非決定な検証は門になれない・サンドボックス＝実行環境層 等）。

## v2.17 での変更点（v2.16 からの増築。根拠は `.guardrails/GOALS.md` のG）

**2026-07-07 調査③（ゼロレビュー・自律運用系）**の回。ユーザー提供の外部リサーチ
（自己治癒ランタイム・Dark Factory・Telos 注釈・OpenClaw ワークスペース・Vibe Testing・
Governed AI 等）を採用ゲートで判定した（正本: `surveys/SURVEY_ZERO_REVIEW.md`。
入力コードの欠陥・出典の質も記録）。キットの立場を1行で固定——**ゼロレビューが買える
のは「機械検査可能な違反ゼロ」まで**。

- **soft 検査 `context-doc-too-large`**（G3）: 常時読込の規約文書の行数警告（CLAUDE.md
  系200行・AGENTS.md 500行、列上書き可）。「注意力の希釈」対策の機械化で、**Skills 化
  保留のトリガーのセンサー**を兼ねる。
- **心得2行**（テンプレ §8）: テストの重心は統合水準へ（モック写しの単体は実装の複製）・
  LLM 生成テストは境界値と異常系を明示して発注（Testing Trophy——機械化不能な残余）。
- **保留1件**: 依存・脆弱性監査 CI ジョブ（本番・顧客データ段階で発火。アドバイザリ DB
  更新が G1 決定性と衝突する緊張を先に記録——非ブロッキング開始→昇格判定）。
- **不採用7群**（詳細と理由は調査③）: 自己治癒ランタイム／Dark Factory 自動マージ／
  Telos 関数注釈／SOUL・MEMORY・HEARTBEAT／Vibe Testing／トークンバジェット等
  （中核思想の裏書きとして記録）／SPEC.md・worktree（調査②再確認）。

## v2.16 での変更点（v2.15 からの整備。文書のみ・根拠は `.guardrails/GOALS.md` のG）

公開（public）に切り替える回。機構の変更なし。

- **README.md をポートフォリオ両用に再構成**（G2）: 想定読者を冒頭で明示
  （①出戻りに焼かれた実務者=道具として ②設計判断を読む技術者=判断ノートとして）。
  「30秒で分かる設計判断の例」（red-first 証明・虚偽✅監査）と「読みどころの地図」
  （surveys / Phase 節 / 是正の記録）を新設し、3分で判断の質に到達できる導線にした。
  正直な注意書き（効果未実測——キット自身の認識論をまだ満たしていない旨）は維持。
- **判断の記録**: LICENSE は置かない（ユーザー判断——閲覧中心の公開。再利用許諾が
  必要になった時点で改めて判定する）。版表記は固定文字列をやめ git タグを正本とした
  （v2.15 の README が v2.14 と表記したままだった不整合の再発防止）。

## v2.15 での変更点（v2.14 からの整備。文書のみ・根拠は `.guardrails/GOALS.md` のG）

GitHub（private）での配布へ移行する回。機構の変更なし。

- **`README.md` 新設**（G2——初見の読者が「これが何で・どう使い始めるか」に一発到達）:
  リポジトリの玄関。防壁の層の一覧・正直な注意書き（速くならない/効果未実測/機械検査
  可能なものだけ/Claude Code 固有3層の境界）・最短の導入経路・読む順番・リポジトリ運用。
  install_kit ではメタ扱い（README* プレフィックス）＝移植先には配置されない。
- **導入手順の記述を §1 に統一（是正）**（G9）: README.md 初稿の「直下に展開」を
  「**zip を置くだけ→インストーラが fail-closed の衝突判定で配置**」へ書き直した——
  既存プロジェクトでは直下展開が先住ファイル（.gitignore / CI / pre-commit 設定等）を
  無断上書きするため。あわせて本書 §1 の「インストール後の姿」ツリーから、移植先に
  配置されない README.md / surveys/ の2行を除去（v2.14〜15 で誤って追加していた——
  ツリーの前提は移植先の姿）。
- **リポジトリ運用の判断を記録**（G5）: 配布は「版 = git タグ」＋ Release 添付とし、
  **zip はリポジトリにコミットしない**（木と zip の二重正本はドリフトの温床——
  binding-drift の配布版）。キット自身のリポジトリでは Actions を無効化する
  （出荷状態は自己検査が意図的に5件赤 — §3.3——移植先で緑になる設計のため）。

## v2.14 での変更点（v2.13 からの整備。根拠は `.guardrails/GOALS.md` のG）

機構の追加なし——**調査文書の同梱**と、v2.8〜v2.13 で積んだ全機構の**横断整合性監査**の回。

- **調査文書の同梱**（G5——判断の出典をキットと一緒に運ぶ）: `surveys/` を新設し、
  調査①（`SURVEY_MCP_ECOSYSTEM.md`——2026-07-07 MCP・エコシステム）と
  調査②（`SURVEY_FAMOUS_KITS.md`——同日 著名キット）を同梱。install_kit では
  **メタ扱い＝移植先には配置しない**（README / PROMPT と同じ分類——判断の出典であって
  移植先の規約ではない）。
- **整合性監査（機械監査スクリプトで横断検査→所見8件を全て修正）**（G4/G5）:
  ① スクリプトが出す規則IDの全数照合——`commit-msg-format`・`fix-without-test` の
  IDが GUARDRAILS §3.4 に未記載だった（v2.1 以来の欠落）→ 検査1・2の見出しに明記
  ② **検査番号の連番化**——v2.13 が検査6を欠番にして 7・8 を振っていた →
  `feat-without-test`=**検査6**・`commit-too-large`=**検査7** へ改番（コード・文書・
  調査②とも同期） ③ §3.3 の scripts 本数 8本→**9本**（v2.12 の check_bootstrap 追加の
  反映漏れ） ④ missing-required の列挙に台帳 .guardrails/BOOTSTRAP.md を明記 ⑤ §11 Step 2 見出しの
  旧「スクリプト4本」（v2 は全スクリプト同梱済み）を是正 ⑥ PROMPT の列ID例示 @4→@6・
  ファイル表に .guardrails/BOOTSTRAP.md 行を追加 ⑦ 不採用記録の「正本は2文書」を v2.10 以降の構成
  （AGENTS.md / CLAUDE.md）へ ⑧ 歴史記録（各版の変更点セクション内の旧列ID等）は
  **意図的に残置**——書かれた時点の事実の記録であるため。
  監査で**問題なし**を機械確認した項目: 全 HARD/SOFT 規則IDの文書照合・REQUIRED_PATHS の
  実在・PRECOMMIT_REQUIRED↔設定・台帳↔監査器の Step 一致・GOAL_CITATION の G1〜G14 境界・
  状態表 Phase 19〜26 の完全性・README 版順・テンプレ構造（章見出し14本・import）・
  出荷状態の自己検査5件・監査器の沈黙。

## v2.13 での変更点（v2.12 からの増築。根拠は `.guardrails/GOALS.md` のG）

**2026-07-07 調査②（著名な同種キット）**の回。Superpowers（obra）・GitHub Spec Kit・
Kiro（AWS）・BMAD-METHOD・OpenSpec・GSD・Ralph Loop・Beads 等を調査した
（成果物: `surveys/SURVEY_FAMOUS_KITS.md`——v2.14 でキットに同梱）。最大の発見は**本キットの路線の
外部裏書き**——著名キットはほぼ全てプロンプト層の規律であり、Fowler の実測は
「チェックリストは AI が解釈するため保証が無い」、EPAM の事例は「明文の constitution
規則ですら破られる」ことを示した。機械化できる知見は2つだけ採用:

- **検査6 `feat-without-test`（soft）**（G10/G4）: feat: がコードに触れるのにテスト変更が
  無ければ警告（Superpowers の TDD 鉄則の門化。fix 側=検査2 hard の feat 版）。
  soft で観測から始め、昇格トリガーを Phase 25 に登録（v2.6 検査5と同じ導入経路）。
- **検査7 `commit-too-large`（soft）**（G11/G4）: 純変更 400 行超（生成物・lockfile 除外・
  列上書き可）で警告（Superpowers「2〜5分粒度」等の収斂の門化——実行規律2の一般開発版）。
- 心得側3行を AGENTS.md テンプレへ（plan の粒度・feat のテスト同梱・小さなコミット）。

### v2.13 で検討し**不採用/対象外**にしたもの（調査②の判定——再提案ループ防止）

| 候補（出典） | 判定と一行理由 |
|---|---|
| 役割エージェント群（BMAD の 12+ ペルソナ） | 不採用再確認——§5-5 前例（正本の分裂・可動部増）。ハンドオフのファイル受け渡しが崩れる実測報告も調査②に |
| プロセスファイル一式（Spec Kit の specify/plan/tasks・Kiro の requirements/design/tasks） | 不採用——チェックリストは AI 解釈で保証なし（Fowler）。本キットは同じ目的を門で達成済み（plan は検査5、DoD は BOOTSTRAP 監査、constitution は .guardrails/GOALS.md＋検査3） |
| constitution 概念そのもの | 採用済みと判定——.guardrails/GOALS.md（G引用の機械検査つき）が同等以上。名称だけの輸入はしない |
| GSD・Ralph Loop（メタプロンプト/ループ実行） | 対象外——実行時のオーケストレーションはキットの層（リポジトリ内の門）の外。プロンプト集の常駐は v2.11 と同根で不採用 |
| Beads・Memory Bank 系の台帳/メモリ | 不採用再確認——§13 中央メモ禁止。タスク台帳の正当な形は plan.md と .guardrails/BOOTSTRAP.md（検証可能な範囲のみ） |
| git worktree 並列実行（Spec Kitty / Conductor 等） | 対象外——個人のワークフロー層。キットの門はブランチ構成に依存しない |
| Kiro の EARS 記法強制 | 不採用——受け入れ条件の形式強制は偽陽性>価値（§7.4 の範囲外）。「テスト可能な形で書く」は §8 の心得で足りる |
| Superpowers の skills 層への追随 | 保留済み（v2.11 の Skills 化トリガーに包含——常駐問題の実測＋相互運用標準の成熟待ち） |

## v2.12 での変更点（v2.11 からの増築。根拠は `.guardrails/GOALS.md` のG）

「LLM がプロンプト1つでキットを展開できるか」という懸念への回答の回。
プロンプト分割は不採用（心得の再配置——検証力を足さずに人間の介入だけ増える。正しい
分割単位は既に 1 Step = 1 コミットで存在する）とし、**✅ の自己申告を門で検証する機構**
＝実行規律1〜4（順序・1Step=1コミット・完了=実行結果・虚偽✅禁止）の機械化を実装した。

- **ブートストラップ監査 `check-bootstrap`（hard・§3.5 新設）**（G7/G4/G2）: 進捗の正本を
  **`.guardrails/BOOTSTRAP.md`（台帳）** に一本化し（状態 🚧/✅/—＋固有名詞リストC）、
  pre-commit フックが**台帳に触れたコミット＝✅ 化の瞬間**に発火して4種を機械検査する
  （CI の --all-files では常時再監査——guard-corpus と同じ二重の網）:
  `bootstrap-order`（✅ は番号順のみ）・`bootstrap-multi-flip`（✅ 化は1コミット1Step）・
  **`bootstrap-false-done`（✅ の Step ごとに検証可能なアサーションをその場で再実行**——
  例: Step 1 = 章見出し14本＋★/TODO/固有名詞Cの残置 grep、Step 2 = 索引 `--check` 再実行、
  Step 4 = guard コーパス全再生、Step 5 = 形式違反メッセージの注入やり直し、
  Step 10 = コード全ファイルの TODO grep**）**・`bootstrap-demote`（✅→— 禁止。
  ✅→🚧 の差し戻しが正規経路）。**嘘の ✅ と空実装は物理的にコミットできなくなり、
  人間は台帳を見るだけで進捗を監査できる**。出荷状態（全 🚧）では沈黙——進捗を強要する
  門ではなく、「進んだという主張」だけを検証する。
- 付随（G5）: §11 のチェックリストから状態列を廃し .guardrails/BOOTSTRAP.md へ移行（進捗正本の
  一本化）、実行規律1〜4に機械化注記、台帳と監査器を missing-required へ、
  install_kit の必須フック検証に check-bootstrap を追加、PROMPT 2本に台帳運用を追記。

## v2.11 での変更点（v2.10 からの増築。根拠は `.guardrails/GOALS.md` のG）

**2026-07-07 に実施した MCP・エコシステム・Plugin 連携調査**（LLM = Claude Code 前提）の
判定をキットへ固定した回。調査の結論は「即時採用すべき新規はゼロ——現構成
（Playwright MCP 1本＋CLI 群＋薄い常駐）が推奨形に既に一致」であり、成果物は機構の追加
ではなく**判定の門化と記録**（改善の必要がない部分は改善しない）。

- **MCP 採用許可リスト `mcp-not-allowed`（hard）**（G3/G5/G7）: プロジェクト正本
  （追跡された `.mcp.json`）に置ける MCP を `repo_scan.py` の `MCP_ALLOWED_SERVERS`
  （中立既定値 **playwright のみ**＝2026-07-07 調査の判定）の許可リスト制にする。
  「便利そうだから」の MCP 常駐（ツール定義がコンテキストを食う——実測例: GitHub MCP
  フルで 42〜55k トークン）を、判定の記録なしには増やせなくした。解釈不能な JSON は
  `SOFT:mcp-unparseable` で素通し・タスク単位のローカル追加（`claude mcp add`）は
  対象外＝門は「常駐の既成事実化」だけを塞ぐ。
- **採用規律の正本化**（G5）: 採用ゲート3条（①重複排除——CLI・ネイティブ・既存機構が
  優先、逆転は実測のみ ②常駐予算——スポット用途はタスク単位 add/remove へ格下げ
  ③契約整合——書込ツール・メモリ生成・注入面）を catalog の
  「**MCP・エコシステム採用規律（2026-07-07 調査）**」注記に登録。deprecated-api の
  出典規律と同格の、許可リストを増やす時の判定手順の正本。
- **保留4件の登録**（§10 保留節・トリガー付き）: Chrome DevTools MCP（性能調査時のみ・
  タスク単位で常駐させない）／Context7（deprecated-api で同一ライブラリの再発を実測した
  時）／Serena（大規模**既存**リポジトリで参照追跡が溢れる実測が出た時のみ・memories
  無効化＋read-only 条件付き）／Skills 化（AGENTS.md 常駐の問題化＋相互運用標準の成熟）。

### v2.11 で検討し**不採用**にしたもの（2026-07-07 調査の判定表——再提案ループ防止の転記先）

| 候補 | 不採用の一行理由 |
|---|---|
| Serena MCP（新規リポジトリの常駐） | `.serena/memories/` が §13「中央メモ禁止」と正面衝突（Memory Bank 不採用と同根）。索引=STRUCTURE.md＋500行/7ファイル上限で役割充足。トークン削減効果はタスクレベルで逆転する実測もあり「明らかに性能が大きい」に該当せず。大規模既存限定の再評価は保留（§10） |
| GitHub MCP | `gh` CLI が完全代替（実測 約35倍のトークン差・定義常駐 42〜55k）。外部内容読込経由の注入実証（toxic agent flow 2025-05）もある領域 |
| Supabase / Postgres 系 MCP | 観察レールは `dev.py db`（読み取り専用・ローカル限定）と CLI で充足。書込可能ツールは §2/§3 の門の外の変更経路（G7） |
| filesystem / git / fetch 等の基本系 MCP | Claude Code ネイティブツールと完全重複——定義分だけ損 |
| sequential-thinking MCP | 拡張思考（ネイティブ）と重複 |
| memory / knowledge-graph 系 MCP | §13 中央メモ禁止・Memory Bank 不採用（v2.4）と同根。auto memory も既存 |
| プロンプト集型フレームワーク（SuperClaude 等） | 大量の「心得」の常駐はキットの「機械化できる部分はすべて門」と正反対で、常駐トークンも大 |
| Plugins / マーケットプレイスによるキット配布 | プラグインはユーザー環境層＝規約が統治するコードと同じコミットに固定されない（G5/G1——Agent Rules MCP 不採用と同根）。配布の正本は install_kit.py のまま |
| SaaS 系 MCP（Sentry・CircleCI 等）・個人ツール（ccusage・mgrep 等） | 対象外——製品都合・個人利用自由（Repomix 前例）。入れるならタスク単位で・キット正本に入れない |

## v2.10 での変更点（v2.9 からの増築。根拠は `.guardrails/GOALS.md` のG）

保留項目「AGENTS.md 可搬列」のトリガー（他エージェント併用の発生）がユーザー宣言で成立し、
登録済みの設計スケッチどおり発動した回（Phase 22）。

- **規約の正本を全エージェント共通の `AGENTS.md` へ二分**（G13/G5/G7）: 旧ルート
  CLAUDE.md の全章（§0〜§13）を **`AGENTS.md.template` へ移設**（章番号不変）。
  Codex / Cline / Cursor / Windsurf はルート AGENTS.md をネイティブに直読みし、
  Claude Code は薄くなった `CLAUDE.md` 冒頭の **`@AGENTS.md` インポート**（公式
  ドキュメント記載の到達経路）で同じ本文を読む。**同期スクリプトは作らない**——
  同一内容の正本を2つ置いて一致を追いかける構図は G5 違反（binding-drift の規約版）。
  分割なら同期対象が存在せず、ドリフトは構造的に発生しない。インポート行の存在は
  新設の hard 検査 **`agents-import-missing`**（`REQUIRED_CONTENT_RULES` の既定1件目）が
  機械強制し、`AGENTS.md` 自体も `missing-required` の対象に追加。
  CLAUDE.md 側に残るのは Claude Code 固有のフック層（§1/§2/§2b/§2c）の説明のみで、
  §3〜§5 の門（pre-commit / commit-msg / pre-push / CI）は git フックと CI なので
  **元より全エージェント共通**——可搬性の空白はフック層だけ、を §6 に明文化。
  symlink 方式は Windows でプレーンテキスト化する既知の罠があり不採用（§7.2 の前提）。
  フォルダ別 CLAUDE.md は据え置き（探索仕様がツール間で割れる領域——運用は
  AGENTS.md §12 手順3「触るフォルダの CLAUDE.md を読む」が全エージェントに効く）。
- 文書の更新（G5/G13）: §6 を二分構成に再構成、§3.3 に `agents-import-missing`＋
  出荷状態の想定出力を5件へ、§11 Step 1 を2テンプレ同時完成へ、§0 一次対応表に
  他エージェント行、Phase 22 を新設（実装時の事実確認と同期スクリプト不採用の判断を
  記録）。本書・.guardrails/GOALS.md・catalog・スクリプトの章参照を `AGENTS.md §N` へ機械改名
  （移植元原本への言及と変更点の歴史記録は除外）。catalog は ts-react-web@6（注釈の
  改名のみ）。v2.7 で漏れていた §3.3 のスクリプト本数（7本→8本）も是正。

## v2.9 での変更点（v2.8 からの増築。根拠は `.guardrails/GOALS.md` のG）

更新計画の残り2つの決定点をユーザー判断で確定し、両方とも**強い側**へ倒した回。

- **Stop ゲート条件B＝決定点②の強化案を確定**（G7/G4/G2）: ターン終了ゲート（§2b）の
  差し戻し条件に「ツリーはクリーンだが `dev.py check` が赤」を追加。これまでは
  「クリーンにさえすれば赤い検査を残して終われる」隙間があった（条件A=未コミット作業
  のみ）。誤差し戻しは3つの絞りで抑える: `HARD:` を含む exit 1 だけが差し戻す
  （check の内部エラー exit 2・素の非0は素通し）／uv・dev.py 不在は**表示1行で
  条件Aのみへ縮退**（fail-open の向きは従来どおり）／差し戻し上限3回のカウンタは
  条件A/Bで共有。差し戻し文面には違反の先頭5行（規則ID入り）を同梱——そのまま
  §3.3 へ直行できる。条件Bはクリーン時のみ走るため毎ターンの追加コストは2秒予算内。
- **red-first の required 化＋`RED-FIRST-EXEMPT` 乱用監視＝決定点③を確定**（G10/G7）:
  CI の red-first ジョブから `--soft` を外した——違反（親コミットでも緑の fix）は
  **exit 1 でジョブが赤**。計画の運用条件「最初から required にするなら EXEMPT の
  乱用監視をレビュー規約に足すこと」を二層で実装した: **機械部分**＝理由の無い
  `RED-FIRST-EXEMPT` は免除不成立（1行表示して通常判定を続行）、**人間部分**＝
  レビュー規約をルート CLAUDE.md テンプレ §8 に追加（理由の具体性・CI 上の
  再現不能性・頻度を点検）。required の完成はブランチ保護の required checks への
  登録まで（リポジトリ設定——§11 Step 9 ④）。表示のみへ戻すロールバックは CI の
  呼び出しに `--soft` を足すだけ。
- 文書の更新（G5/G13）: §0 全体像・一次対応表（Stop 行を新設・red-first 行を更新）、
  §2b を条件A/B/免除の3部構成に改稿（決定点②の確定を記録）、§5 の導入強度を
  required へ、§10 状態表に Phase 20・21・Phase 18 節に確定の追記・保留（変異テスト）
  のトリガー文言更新、§11 Step 4 ⑥／Step 9 ④ に条件B・required の注入を追加。
  カタログ・.guardrails/GOALS.md の変更なし（両機構とも既存Gの強化——列値も判定列も不変）。

## v2.8 での変更点（v2.7 からの増築。根拠は `.guardrails/GOALS.md` のG）

- **第4レンズ「意図の保存」＝G14「意図の複利」の新設と `feat-without-plan` の hard 昇格**
  （G14/G7/G5）: v2.6 から soft（表示のみ）で運用してきた検査5を **exit 1 の hard** へ
  昇格し、根拠を .guardrails/GOALS.md の**レンズ4**として憲法化した——**決定点①を案Aで確定**
  （ユーザー判断・§10 Phase 19）。レイヤー直下（列充填の `PLAN_LAYER_ROOTS`——空なら
  不発は据え置き）に新規ディレクトリを作る `feat:` は、設計根拠（`plan.md` /
  `docs/plans/`——1行でよい）の差分を同コミットに含めない限り落ちる。
  **逃げ道の意味論は fix⇔テスト（検査2）と同一**: 根拠を書けない構造変更は feat を
  名乗らない（refactor / chore）。fix⇔テスト（G10＝回帰の複利）と feat⇔plan
  （G14＝意図の複利）が対として完成し、「何を直したか」と「なぜ作ったか」の両方が
  git 履歴に機械強制で残る。
- **同時改修の3点セット**（旧計画が「§1-7 で実測済みの罠」と警告していた漏れ——同一の
  変更で実施）: ① `check_commit_msg.py` の `GOAL_CITATION` 正規表現を
  `G(1[0-4]|[1-9])` へ（G14 引用が検査3で偽陽性にならない） ② .guardrails/GOALS.md ヘッダ
  「G1〜G13」「13条」→「G1〜G14」「14条」＋レンズ4新設・G5 行の分担整理（同梱強制は
  G14 へ移管、G5 は「正本が単一」に純化） ③ README・.guardrails/GUARDRAILS.md（§0 一次対応表・
  §3.4 検査5・§6 表・§10 状態表 Phase 17/19・§11 Step 0 表A/Step 5 ⑥）・catalog 注記・
  CLAUDE.md テンプレ §4 の soft 表記を hard へ。
- 移植先への影響: 既存リポジトリでは、これまで警告止まりだった構造追加コミットが
  落ちるようになる。対応は「1行の根拠を書く」か「feat を名乗らない」の二択のみ
  （§0 一次対応表）。列未充填（`PLAN_LAYER_ROOTS` 空）の場合は従来どおり不発。

## v2.7 での変更点（v2.6 からの増築。根拠は `.guardrails/GOALS.md` のG）

- **red-first 証明 CI（`red-first` ジョブ・PR のみ）**（G10/G7）: 検査2（fix⇔テスト対）は
  「テスト同梱」までしか強制していなかった——そのテストが**バグを再現していた**こと
  （＝親コミットで赤だった）を `scripts/check_red_first.py` が機械証明する。PR 範囲の
  `fix:` コミット毎に、そのコミットで**追加**されたテストファイルを親コミットの一時
  worktree（リポジトリ直下 `.red-first-*/`——node/npx の上方解決で主チェックアウトの
  `node_modules` が見える）へコピーし、採用列の「単一テストファイル実行」で1ファイル
  ずつ実行——**少なくとも1つが赤**なら証明成立、全部緑なら `red-first-green` を
  1コミット1行で報告する。「直した証明」が自己申告から実行結果に変わる（G10 の完成形）。
  CI 上で赤にできない修正は本文の `RED-FIRST-EXEMPT: 理由` 行で免除（免除・対象外は
  すべて1行で見える——静かなスキップの禁止）。「非0=赤」は近似であり仕様（§7.4——親で
  実行エラーになるテストも「親が fix を欠く」の現れとして寛大側に倒す）。
  **出荷状態は表示のみ**（CI が `--soft` で呼ぶ——違反は SOFT: 列挙・exit 0。ただし内部
  エラー exit 2 は素通しにしない）。**決定点③**: 数値が安定したら CI の呼び出しから
  `--soft` を外して required 化（カバレッジの「表示のみ→ラチェット」前例）。
  BINDING は `repo_scan.py` の `SINGLE_TEST_COMMAND` / `SINGLE_TEST_CWD`（未充填なら
  不発1行＝言語なし出荷と両立）。多層構成（例: `app/` 直下で実行する Flutter）は cwd
  スロットで吸収し、単独実行が構造的に不能な rust は「該当なし＋代替」を判断ごと記録。
- 文書の更新（G5/G13）: §0 全体像・一次対応表に1行、§3.4 検査2・§9.3 に相互参照、
  **§5 に red-first ジョブの契約**、§10 Phase 18 を ✅ 化（実装時確定3点——worktree の
  位置・cwd スロット・`--soft` フラグ——を記録）、§11 Step 0 表A に1行・Step 9 完了条件に
  ④。catalog は表Aに1行＋4列とも版上げ（ts-react-web@5・python-uv@5・dart-flutter@4・
  rust@4。rust は「該当なし＋代替」・dart は cwd スロット、の判断ごと記録）。
  .guardrails/GOALS.md G10 行に判定・機構を追記（✅→✅/（列））。`.gitignore` キット区画に
  `.red-first-*/` を追加（worktree 残骸で porcelain が汚れない——§2b の session/ と同じ理由）。

## v2.6 での変更点（v2.5 からの増築。根拠は `.guardrails/GOALS.md` のG）

- **世代交代 API 検査 `deprecated-api`**（G4/G13/G7）: LLM が訓練カットオフの都合で
  書きがちな旧作法（例: python の `datetime.utcnow(`）を、プロンプト規則（心得）でなく
  `repo_scan.py` の列パターン `DEPRECATED_PATTERNS`（門）として封鎖する hard 検査。
  **テスト内限定でなく全コード走査**。列値の出典規律（①ベンダー公式 AI プロンプト
  ②公式非推奨告知のみ初期値・近似不能な構文世代は載せない）をカタログに明文化。
  違反注入の実測で**自己偽陽性**（paste-block のラベルが自分のパターンに一致）を発見し、
  パターン定義の正本 `scripts/repo_scan.py` 自身のみ除外に確定（定義は引用であって使用
  ではない——`LOG_EXIT_PREFIXES` と同じ境界。.guardrails/GUARDRAILS.md §3.3）。
- **所有権ガード（§2c 新設）**（G7/G6/G9）: セッション開始時点で既に未コミット変更が
  あったファイル（＝**人間の WIP**）への AI の Edit/Write を exit 2 でブロックする。
  SessionStart フック `session_baseline.sh` が開始時点の dirty パス集合を保存し、
  PreToolUse(Edit|Write|MultiEdit) フック `guard_human_wip.sh` が「baseline に含まれ、
  かつ**現在も**未コミット」の両立時だけ止める——人間が commit / stash すれば**自動解除**
  （特別な解除経路は無い）。v2.5 の作業消失ガード（WIP を消せない）と対になり、
  「未コミット作業の保全」が消失・混入の両面から完成。契約は §2b の仲間の
  **fail-open**（baseline 不在・git 不在は警告1行で素通し——壊れたフックが全編集を
  止めない。§2 の fail-closed と逆向き）。既知の限界: 同一セッション内の人間との
  並行編集は守れない（baseline は開始時点のスナップショット）。
- **feat⇔plan 対 `feat-without-plan`（soft・表示のみ）**（G5）: レイヤー直下
  （列充填の `PLAN_LAYER_ROOTS`——空なら不発）に HEAD に無い新規ディレクトリを作る
  `feat:` に、設計根拠文書（`plan.md` / `docs/plans/`）の差分が無ければ警告1行。
  **コミットは通る**。fix⇔テスト（G10＝回帰の複利）と対をなす「意図の複利」の入口。
  **決定点①は未決**——hard 昇格（G14「意図の保存」新設）は soft 運用でノイズ率を
  実測してからのユーザー判断（機械の実績が先、憲法改正は後——.guardrails/GUARDRAILS.md §10）。
- **コーパス再生の並列度をコア数から自動導出**（G11）: `check_guard_corpus.py` の
  固定値 `max_workers=16` を `os.cpu_count()` 由来（下限8・目安2×コア・上限32）に変更。
  標準ライブラリで Windows 含め動くため、**ユーザー入力も調査スクリプトも不要**
  （8コア機では従来と同じ16——挙動の実質変更なし・多コア機で速くなる）。
- 文書の更新（G5/G13）: §0 全体像・一次対応表に3機構の行、**§2c 新設**、§3.3 に
  `deprecated-api`、§3.4 に検査5、§10 の Phase 15〜17 を ✅ 化（実装時確定3点を記録）・
  保留に「所有権ガードのコーパス再生」をトリガー付きで登録、§11 Step 0 表A に2行・
  Step 4/5 の DoD 追記。catalog は表Aに2行＋出典規律の注記＋4列とも版上げ
  （ts-react-web@4・python-uv@4・dart-flutter@3・rust@3。ts 列の `getSession(` は
  「ブラウザ SPA では対象外」の判断ごと記録・dart/rust は「該当なし」の判断ごと記録）。
  .guardrails/GOALS.md の G5/G7 行に新機構を追記。

## v2.5 での変更点（v2.4 からの増築。根拠は `.guardrails/GOALS.md` のG）

- **編集直後リント（PostToolUse 第2段）**（G4/G11）: 整形（第1段・自動修正系）の直後に
  編集された1ファイルへ判定系 lint を当てる `.claude/hooks/post_edit_lint.sh` を同梱。
  違反は exit 2 で stderr が Claude に渡り**その場で修正**——lint の初出が push 段から
  編集直後へ2段前倒しになり「push で落ちて再試行」の1周が消える。公式仕様では同一
  matcher の複数フックは並列・順序不定のため、`settings.json` は整形→lint の**直列
  1コマンド**として配線済み（順序が実行環境の仕様に依存しない — .guardrails/GUARDRAILS.md §1）。
  性能予算「編集1回あたり合計3秒以内」を §7.7 に新設（実測: ruff 単一ファイル約60ms）。
  ツール未導入は1行表示して素通し（静かな不発を防ぎ、フローは止めない）。
- **依存追加の明示化 `undeclared-dependency`（commit-msg 検査4）**（G7/G6/G9）:
  依存マニフェスト（package.json / pyproject.toml / Cargo.toml / pubspec.yaml——
  basename 一致でモノレポのネストも対象）に **HEAD 比で追加された名前**があるのに
  本文に現れないコミットを exit 1 で止める（`依存追加: <名前> — 理由1行` を書けば通る）。
  **依存は増えてよいが、黙って増えてはならない**——fix⇔テストと同じ「意味論で塞ぐ」型。
  lockfile・版更新・削除・初回コミット・新規マニフェストは対象外（境界は §3.4 に明記）。
- **作業消失ガード**（G7/G9/G10）: 迂回防止と同じ主防壁 `guard_git_bypass.sh` 内の節として、
  **非可逆な作業消失だけ**を exit 2 で塞ぐ——① `.git` を含む `rm -rf` は常時ブロック
  ② `git reset --hard`・`git clean -f`・広域 `checkout .`/`restore .` は**未コミット変更が
  ある時だけ**ブロック（dirty 条件が誤検知をほぼ消す。クリーンなら素通し・`stash` が正規の
  退避経路）。回帰再生のためコーパスに**前提列**（`期待<TAB>dirty|clean<TAB>コマンド`）を
  新設——チェッカが一時リポジトリのフィクスチャで dirty/clean を機械再生する（§2）。
  コーパスは 40行→**74行**。
- 文書の更新（G5/G13）: §0 全体像・一次対応表に3機構の行、§1 を直列2段の契約に改稿、
  §3.4 に検査4、§7.7 に3秒/編集予算、§10 の Phase 12〜14 を ✅ 化（実装時確定2点を記録・
  Phase 14 の旧 DoD ⑤ は Phase 16 へ繰り越し）、§11 Step 0 表A に2行・Step 4/5 の DoD 追記。
  catalog は表Aに2行＋4列とも版上げ（ts-react-web@3・python-uv@3・dart-flutter@2・rust@2。
  lint 不適合言語は「該当なし（push 段で回収）」の判断ごと記録）。

### v2.5 で検討し**不採用**にしたもの

| 候補 | 不採用の一行理由 |
|---|---|
| 汎用の危険コマンド一覧（rm 全般・dd 等） | 誤検知の密集地帯。非可逆な作業消失2種に限定する方が信号が濃い（§2） |
| 依存検査での lockfile 監視 | 推移的更新まで宣言を強いると儀式化する——直接依存の名前だけが意図の単位（§3.4） |
| tomllib による TOML 解析 | Python 下限が 3.11 に上がる（§7.1 違反）。行指向の自前近似で足りる——近似は仕様（§7.4） |
| lint 第2段の2エントリ登録 | 公式仕様で並列・順序不定——整形→lint の順序が保証できないため直列1コマンドに（§1） |

## v2.4 での変更点（v2.3 からの増築。根拠は `.guardrails/GOALS.md` のG）

- **guard 迂回コーパス**（G10/G7/G11）: 主防壁 `guard_git_bypass.sh` の回帰テストを同梱。
  `tests/guard_corpus.tsv`（`期待<TAB>コマンド`、DENY 25行＋ALLOW 15行）を
  `scripts/check_guard_corpus.py` が実フックへ再生して照合する。門番を改修した時に
  過去に塞いだ迂回が静かに開き直る事故を、`HARD:guard-corpus-mismatch` の機械停止に
  変える。pre-commit では門番3点に触れたコミットだけで走り、CI では常時走る。
- **probe 動詞（事前照会）**（G4/G12/G2）: `uv run scripts/dev.py probe "<cmd>"` が
  迂回防止の判定を実行前に返す（`ALLOW` / `DENY guard: 理由`）。コーパス再生と同一経路で
  guard を呼ぶため、照会結果＝実際のブロック挙動。`dev.py` は9動詞→**10動詞**。
- **ターン終了ゲート（Stop フック）**（G7/G2）: 実行規律7「途中でターンを終えない」を
  機械化。未コミットの作業があり、かつ `BLOCKED:` 報告も無いターン終了を exit 2 で
  差し戻す（`.claude/hooks/stop_incomplete_guard.sh`）。無限ループはセッション毎
  カウンタ（最大3回）と Claude Code 本体の上限で二重に保護。**§2 の fail-closed とは
  逆に、このフックの内部エラーは fail-open（素通し）**——壊れた門がセッションを
  終了不能にしないため。契約は .guardrails/GUARDRAILS.md **§2b（新設）**。
- **走査の頑健化（DoD 違反注入で発見した実バグの修正）**（G7/G11）: 追跡済みだが
  ディスクに無いファイル（削除コミットの直前＝pre-commit が走る状態）があると
  `check` が `FileNotFoundError` の内部エラー exit 2 で落ち、本来の
  `HARD:missing-required` 報告が出なかった。`repo_scan.list_tracked_files` が
  ディスク実在でフィルタするよう修正——防壁消失は規則ID付きの1行で止まる（Fail Loudly）。
- 文書の追記（G5/G13）: §0 全体像表に「ターン終了」行と Fail Loudly の対応注記、
  §10 状態表に Phase 9〜18（v2.4 の3機構 ✅＋v2.5〜v2.7 の予定 🚧）と保留3件
  （トリガー付き）を登録。`permissions.deny` の不動作が外部で報告されている件と
  「CLAUDE.md は影響であって強制ではない」件を §2 に注記（フック側に門を置く本キット
  構造の外部裏書き）。

### v2.4 で検討し**不採用**にしたもの（再提案ループ防止の記録。詳細理由の正本は本節）

| 候補 | 不採用の一行理由 |
|---|---|
| Memory Bank（複数 md の記憶術） | 手書き文書群は腐る（G9）。本キットは生成物＋門で同じ役割を既に果たす |
| Repomix 成果物の同梱 | `STRUCTURE.md`（生成・鮮度検査つき）と重複。腐る成果物を増やさない（G9/G3） |
| 反迎合プロンプト規則の追加 | 心得は門にならない（G7）。迎合の実害は §3.4/§10 実行規律が既に機械側で塞ぐ |
| 計画実行モード規約（Plan Mode 常用の明文化） | ツール固有 UI への依存（G13）。規律7＋§2b で挙動側を固定した |
| 特化型エージェント表（reviewer/architect 等） | 役割分担は門を増やさない。検査は既に非対話の機械（G7） |
| クラウド API 併用（実 LLM でのコーパス評価） | 決定性が壊れる（G1）。コーパスは実フック再生で足りる |
| Before/After スナップショット認知ログ | 書く量が増えるだけで判定機構が無い（G11）。git 履歴＋STRUCTURE で代替済み |
| Agent Rules MCP（規則配信サーバ） | 規則の正本が外部化しドリフトする（G5/G13）。正本はリポジトリ内の規約文書（v2.10 以降は AGENTS.md / CLAUDE.md — §6） |
| Repomix MCP（都度パック生成） | ランタイム依存を増やす（G11）。観察レール §12.3 と重複 |

## v2.3 での変更点（v2.2 からの増築。根拠は `.guardrails/GOALS.md` のG）

- **配置の機械化 `scripts/install_kit.py`**（G2/G9/G7）: 「ルートへ手でコピー」は既存
  ファイルとの衝突＝上書き事故の温床だった。zip / 展開フォルダをルートに置けば、配置・
  既存との衝突判定（決して黙って上書きしない）・`.gitignore` のマーカー区画追記・
  キット系統ファイルの安全な版上げ（git 履歴を安全網に `UPGRADED`）・検証・**zip の
  自動後片付け**までを1コマンドで行う。判定は決定的・出力は1行1ファイル・再実行は冪等。
- **CI ワークフローを `guardrails-ci.yml` へ改名**（G13）: 既存リポジトリで最も衝突しやすい
  `ci.yml` を、キット名前空間にして衝突そのものを消した（GitHub Actions は複数ワークフローの
  共存が正規の形）。旧 `ci.yml` の痕跡はインストーラが `NOTE:legacy` で知らせる。
- **本書を `README_SETUP.md` へ改名**（G1）: 日本語ファイル名は zip 展開系（Windows の
  標準展開・一部 unzip）のエンコーディング差で名前が化け、v2.3 のメタ除外を
  すり抜けてリポジトリへ混入する事故を実測した。ASCII 名で構造的に回避し、
  インストーラ側も README*/PROMPT_* のプレフィックス除外で二重化した。
- **メタ3ファイルをリポジトリに入れない**（G3）: 本書と PROMPT 2本は「インストールの説明書」
  であり、配置後のリポジトリには残らない（`.guardrails/GUARDRAILS.md` §11 が手順の正本として残る）。

## v2.2 での変更点（v2.1 からの増築。根拠は `.guardrails/GOALS.md` のG）

- **コミット毎の全検査二重実行を解消**（G11）: pre-commit は stages 未指定のフックを
  「インストール済みの全フック種」で走らせる仕様のため、衛生〜構造検査がコミット毎に
  2回＋push でさらに1回走っていた。`default_stages: [pre-commit]` で半減（実測: 2回→1回）。
- **「install 忘れ＝静かに無効」を心得から機械検査へ**（G7/G9）: `HARD:hook-type-missing`
  （フック種追加後の `pre-commit install` 忘れ）・`HARD:hooks-path-overridden`
  （core.hooksPath 設定済み＝シム無効の静的検出）・`SOFT:hooks-not-installed`
  （出荷直後の正常状態。Step 3 で解消）。CI ではスキップ。
- **防壁ファイル自体を `missing-required` の対象に**（G7/G9）: `.pre-commit-config.yaml`・
  フック2本・`settings.json`・`guardrails-ci.yml`・`scripts/` 5本等——防壁が消えるのは fail-open の最悪形。
- **列充填の取りこぼし検出 `HARD:binding-dead-pattern`**（G9/G4）: パターン辞書の拡張子が
  `CODE_EXTS` に無く検査が永久に不発、という静かな不発を hard で検出。
- **GOALS 運用ルールの機械化 `HARD:governance-without-goal`**（G5/G7）: 正本3文書
  （GOALS/GUARDRAILS/catalog）を変更するコミットはメッセージにG引用が必須（commit-msg 検査3）。
- **主防壁に `pre-commit uninstall` 検出を追加**（G7/G9）: deny は前方一致のみで
  `uvx pre-commit uninstall` 等が素通りだった——force push と同じ二重構造に。
- **カタログの paste-block を加算形に統一**（G13/G5）: ts-react-web@2 / python-uv@2。
  代入形は「複数列の併用」で後貼りが先の列を静かに消していた。
- **`scripts/` をログ出口検査から既定除外**（G13/G9・`LOG_EXIT_PREFIXES`）: python 系の列を
  採用した瞬間、キット自身の scripts 5本（§7・§12.1 の契約で stdout/stderr 直書きが正）が
  `log-direct-call` 24件で落ちる実測バグを修正。
- **CI にハング保険 `timeout-minutes`**（G11）: §9.1「無限に待つCI＝最悪の出戻り」のCI自身への適用。

## v2 での変更点（v1 からの増築。根拠は `.guardrails/GOALS.md` のG）

- **契約とバインディングの完全分離**（G5/G13）: 言語固有値は `bindings/catalog.md` の
  検証済み列へ退去。出荷状態は言語なし——`check` を走らせると `SOFT:binding-unstamped`（Step 0 の刻印
  `BINDING-SOURCE: 列ID@版` で解消）・`HARD:missing-required CLAUDE.md`（雛形が
  `CLAUDE.md.template` のため——Step 1 で解消）・`SOFT:hooks-not-installed`（Step 3 の
  `pre-commit install` で解消——v2.2）の3件が出て exit 1 になるのが**正常**。
  刻印の値不一致・一部ファイルのみの刻印は `HARD:binding-drift`。
- **ランタイム契約 §12**（G1/G2/G4）: 共通動詞 `scripts/dev.py`
  （up/reset/seed/time/test/e2e/fmt/check/db）・操作レール（Web列は Playwright MCP を
  `.mcp.json` で配線。`settings.json` は自動有効化済み）・観察レール・時刻注入・
  外部I/O検疫（hard `test-network`）・UIテストID強制（hard `ui-missing-testid`）。
- **目標の正本 `.guardrails/GOALS.md`**（G1〜G14）: キット・規約への変更はGの引用が必須。
- **新Step**: Step 0 にD表（ランタイム）、Step 8b（ランタイムレール敷設）。

## 1. 配置 — zip をルートに置くだけ（手動コピーはしない）

**ダウンロードした `guardrails-kit-*.zip` を対象リポジトリのルートにそのまま置く。**
展開もコピーも不要——実際の配置は Claude Code が同梱の `scripts/install_kit.py` で
機械的に行い、成功したら zip を自動で片付ける。既に自分で展開してある場合は、その
フォルダごとルートに置けば同じように動く（zip 推奨の理由: 1ファイル＝部分コピー事故が
起きない・後片付けの対象が明確・再配布が容易）。

手で1ファイルずつコピーしない理由は既存ファイルとの衝突で、`.gitignore`・
`.claude/settings.json`・`.pre-commit-config.yaml`・CI などは既存リポジトリに高確率で
先住している。インストーラの規則は fail-closed（G9）:

| 状況 | 動作 |
|---|---|
| 対象に無い / バイト同一 | `INSTALLED` / `OK`（冪等——何度でも再実行できる） |
| `.gitignore` が既存 | キット区画（`>>> guardrails-kit >>>`）を末尾へ**追記** `MERGED` |
| `.gitattributes`・`.pre-commit-config.yaml`・`settings.json` が既存 | 検証条項を満たせば `KEPT`（既存維持）、満たさなければ**上書きせず** `CONFLICT`＋解消ヒント |
| キット系統ファイルの旧版（コミット済み・クリーン） | `UPGRADED`（旧内容は git 履歴が安全網。未コミット変更があれば `CONFLICT` で停止） |
| キット系統でない同名ファイル | `CONFLICT:foreign`（内容確認・手動統合を促す） |

CONFLICT が1件でもあれば exit 1 で止まり、**何も削除しない**。0件になった実行の最後に
zip・展開元フォルダを自動削除する（残したい場合は `--keep-source`）。

インストール後の姿（メタ——本書・`README.md`・PROMPT 2本・`surveys/`——は移植先へは入らない）:

```
リポジトリルート/
├── .guardrails/GUARDRAILS.md                     … 契約の正本（言語なし）
├── .guardrails/GOALS.md                          … 目標の正本（G1〜G14。変更はGを引用）
├── bindings/
│   └── catalog.md                    … 検証済みバインディング列（言語固有値の正本）
├── .guardrails/BOOTSTRAP.md                      … ブートストラップ進捗台帳（✅ は監査器が再実行検証 — v2.12）
├── AGENTS.md.template                … Step 1 で AGENTS.md に完成（全エージェント共通規約の正本 — v2.10）
├── CLAUDE.md.template                … Step 1 で CLAUDE.md に完成（冒頭 @AGENTS.md＋Claude Code 固有の薄い層）
├── .python-version                   … §7.1: uv が従う Python 版の正本
├── .gitignore                        … キット区画（既存があれば区画を追記）
├── .gitattributes                    … 改行 LF 固定（鮮度チェックの CRLF 偽陽性防止）
├── .pre-commit-config.yaml           … §3・§4 の正本
├── .claude/
│   ├── settings.json                 … §2: フック配線 + permissions.deny（第二防壁）
│   └── hooks/
│       ├── guard_git_bypass.py       … §2: 迂回（--no-verify / SKIP= 等）と非可逆な作業消失を exit 2 でブロック（v2.23でPython化）
│       ├── guard_human_wip.py        … §2c: 人間の未コミット変更への Edit/Write をブロック（v2.6・fail-open。v2.23でPython化）
│       ├── session_baseline.py       … §2c: セッション開始時点の dirty パス集合を保存（v2.6・v2.24でPython化）
│       ├── post_edit_format.py       … §1: 編集直後の整形（第1段・自動修正系。v2.24でPython化）
│       ├── post_edit_lint.py         … §1: 編集直後の lint（第2段・判定系——v2.5・v2.24でPython化）
│       └── stop_incomplete_guard.py  … §2b: 未完了のターン終了を差し戻す（条件A=未コミット・条件B=check赤 v2.9。fail-open・v2.24でPython化）
├── .github/
│   └── workflows/
│       └── guardrails-ci.yml         … §5: 最終防衛線（キット名前空間——既存 CI と衝突しない）
├── tests/
│   └── guard_corpus.tsv              … §2: 迂回コーパス（期待<TAB>[前提<TAB>]コマンド、DENY/ALLOW・dirty/clean）
└── scripts/
    ├── install_kit.py                … 本節の配置・マージ・後片付け（再実行は冪等）
    ├── repo_scan.py                  … §7.3: 共通走査（BINDING = 言語バインディング置き場）
    ├── generate_structure.py         … §7.4: STRUCTURE.md を書いてよい唯一の主体
    ├── check_structure.py            … §7.5: 構造検査（hard/soft）
    ├── check_guard_corpus.py         … §2: コーパス再生＋probe 実体（jq 必須）
    ├── check_red_first.py            … §5: red-first 証明（fix テストが親で赤だった機械証明——CI の red-first ジョブが呼ぶ・v2.7）
    ├── check_bootstrap.py            … §3.5: ブートストラップ監査（台帳の ✅ を再実行検証——虚偽✅の門・v2.12）
    ├── dev.py                        … §12.1: ランタイム共通動詞（up/reset/…/probe/db）
    └── check_commit_msg.py           … §3.4: メッセージ検査
```

- 手動で配置する場合（非推奨）のみ `chmod +x .claude/hooks/*.sh` が必要
  （インストーラは自動で付与する。なお6本のフックはいずれも `bash <path>` 起動のため必須ではない）。
- **移植元プロジェクトのルート `CLAUDE.md`（または `AGENTS.md`）原本を持っている場合は、
  `CLAUDE.md.original` 等の名前で一緒に置く**と Step 1 の精度が上がる（原本の章は
  v2.10 以降 `AGENTS.md` 側へ移設して完成させる——テンプレートは .guardrails/GUARDRAILS.md §6 の
  章マップからの再構成なので、原本にしか無い章 §6/§9/§11 は ★ のまま）。

## 2. 前提ツール（ユーザーのマシンに1回）

| ツール | 用途 | 備考 |
|---|---|---|
| git + GitHub リモート | Step 9 の CI 実測に必須 | リモート未作成なら Claude Code に `gh` で作らせてもよい |
| uv | §7.1: Python 系の唯一の実行経路 | 無ければ Claude Code に公式インストーラで導入させてよい |
| jq | フックの精密判定（推奨） | 無くても動く（保守的判定に自動で切り替わる） |
| 対象言語のツールチェーン | 整形・テスト・解析 | 採用列の「前提ツール」欄（例: ts-react-web 列なら Node.js。Playwright MCP も npx 経由） |

pre-commit 本体は Claude Code が Step 3 で `uv tool install pre-commit` として導入する。

## 3. Claude Code の起動と指示

1. zip の中の対象プロンプト（新規: `PROMPT_claude_code.md` / 既存:
   `PROMPT_claude_code_existing.md`）を開き、「入力」の ★ を埋めて全文をコピーしておく
   （**先にコピーする**——インストール成功時に zip は自動削除されるため）。
2. リポジトリルートで `claude` を起動し、コピーしたプロンプトを最初のメッセージとして
   貼り付ける。Claude Code が `install_kit.py` で配置（衝突があれば解消）まで行う。
3. `.claude/settings.json` の配置直後、Claude Code から「/hooks で確認して『続行』と
   返信を」と依頼される → `/hooks` で PreToolUse: Bash・Edit|Write|MultiEdit /
   PostToolUse: Edit|Write|MultiEdit / Stop / SessionStart の4種5エントリが有効かを
   確認し、信頼確認が出たら内容を見て承認して「続行」と返信する。
   **ここが無効のままだと §1・§2・§2b・§2c の防壁が「静かに」存在しないことになる**（fail-open）。
   承認後、`git commit --no-verify` を1回試してみて**実際にブロックされるか**を確認する
   （`/hooks` の表示が有効でも、`.claude/settings.json` を**このセッション中に新規作成**
   した場合、プロセスが起動時にしかフック設定を読み込んでおらず反映されていない症状が
   起こりうる——特に VSCode 拡張のパネル経由。ブロックされないなら、このセッションを
   終了し、VSCode なら拡張のウィンドウをリロード（または別のターミナルで `claude` を
   同じディレクトリで直接起動）してから新しいセッションで確認し直す）。

既存リポジトリへ導入する場合の追加注意:
- 必ず**ブランチ上で**導入させる（main 直 push・force push・履歴書き換えは既存用プロンプトが禁止済み）。
- `.gitattributes` 導入時の改行正規化は巨大 diff を生むため、単独コミットになる（正常）。
- 導入直後に全 hard 規則が効くとは限らない——既存違反が残る規則は .guardrails/GUARDRAILS.md §10 に
  「清掃 Phase」として登録され、清掃と同一 PR で有効化される（見えない緩和ではなく、
  見える猶予として管理される）。棚卸しレポートで件数と計画を確認できる。

あとは Claude Code が .guardrails/GUARDRAILS.md §11 の Step 0→10（骨格作成 → スクリプト調整 →
pre-commit 導入 → 迂回防止 → commit-msg → push 段 → ログ出口 → テスト決定性 → CI →
総合監査）を、各 Step で違反注入テストをしながら進める。

## 4. 完了の確認（ユーザー側の抜き取り検査）

- .guardrails/GUARDRAILS.md 内の Step チェックリストが全行 ✅ で、各 ✅ が実装と同一コミットに入っている。
- ルートに `guardrails-kit*.zip`・展開フォルダが残っていない（インストーラの後片付け済み）。
- `.github/workflows/guardrails-ci.yml` が存在し、既存の自前 CI と重複ジョブになっていない。
- わざと `print(...)` を1行足してコミット → `HARD:log-direct-call` で落ちる。
- `git commit --no-verify` と打ってみる → ブロックされる。
- `git push origin main --force` のように**引数順を変えた force push** を打ってみる → ブロックされる。
- `uvx pre-commit uninstall` と打ってみる → ブロックされる（経由を変えた取り外しの迂回）。
- `uv run scripts/dev.py probe "git push -f"` → `DENY guard: …` が返る（事前照会の生存確認）。
- `uv run scripts/check_guard_corpus.py` → `[guard-corpus] 全74行 PASS`。guard の規則を
  1つコメントアウトして再実行 → `HARD:guard-corpus-mismatch` で落ちる（戻して再確認）。
- ファイルを1つ書き換えた（未コミットの）状態で `git reset --hard` と打ってみる →
  ブロックされる。`git stash` で退避してから同じコマンド → 素通しする（§2 作業消失ガード）。
- ファイルを1つ**人間の手で**書き換えたまま新しいセッションを開始し、そのファイルを
  Claude に編集させてみる → ブロックされる。`git stash`（または commit）→ 通る
  （§2c 所有権ガード——自動解除の確認）。
- 採用列に「非推奨・世代交代パターン」がある場合: 対象の旧 API（例: python 列なら
  `datetime.utcnow()`）を1行足してコミット → `HARD:deprecated-api` で落ちる（§3.3）。
- レイヤー直下に新規ディレクトリを作る `feat:` を plan 差分なしでコミット →
  `HARD:feat-without-plan` で**落ちる**。`plan.md` に根拠1行を足すと通る。refactor: を
  名乗っても通る（§3.4 検査5——v2.8 で hard・G14。逃げ道の意味論の確認）。
- 依存マニフェストに適当な1行を足して `feat: x` でコミット → `HARD:undeclared-dependency`
  で落ちる。本文に `依存追加: <名前> — 理由1行` を書く → 通る（§3.4 検査4）。
- lint 違反（未使用 import 等）を含む編集をさせてみる → 直後に指摘が返り、Claude が
  その場で直す（§1 第2段。ツール未導入なら「lint 未導入」の1行表示で素通り）。
- 変更を残したままターンを終えさせようとする → 差し戻される（§2b。`BLOCKED:` 先頭の
  報告かコミット完了でのみ終了できる）。
- `.git/hooks/commit-msg` を手で削除してコミットしてみる → `HARD:hook-type-missing` で落ちる
  （install 忘れの機械検出）。`pre-commit install` で復旧して再確認。
- STRUCTURE.md を手で編集させようとする → 拒否される。
- PR を1本作る → CI の checks / テストジョブがすべて緑。
- `uv run scripts/dev.py reset` → 同一操作2回 → 状態が一致する（G1 の抜き取り）。
- `uv run scripts/dev.py verbs` → 全動詞が「配線済み」（未配線が残るなら Step 8b が未完）。

1つでも素通りしたら、その項目は 🚧 に戻して再実装させる（.guardrails/GUARDRAILS.md §10 実行規律 4 の監査ルール）。

## 5. 注意

- **STRUCTURE.md は生成物**。手で編集しない（deny 済み）。更新は
  `uv run scripts/generate_structure.py`。
- pre-commit のフック種（`default_install_hook_types`）を変えたら `pre-commit install` を
  再実行する（忘れると新フックは静かに無効 — .guardrails/GUARDRAILS.md §0）。
- `.claude/settings.json` の `permissions.deny` は**前方一致の第二防壁**。引数の順番を変えた
  迂回（例: `git commit -m "x" --no-verify`・`git push origin -f`）は主防壁の
  `guard_git_bypass.py` が引用符除去つきの全文走査で塞ぐ、という二重構造になっている。
  guard は `--no-verify`/`-n`・`SKIP=` に加え、force push（`--force`/`-f`）・
  `core.hooksPath` の付け替え・`pre-commit uninstall`（フック本体の差し替え/取り外し＝
  全フック迂回）もブロックする。v2.5 からは**非可逆な作業消失**（`.git` を含む `rm -rf`＝
  常時、`git reset --hard` 等＝未コミット変更がある時だけ）も同じ guard の節が塞ぐ——
  消してよい変更は先に `git stash` で退避すれば同じコマンドが素通しになる。
  既に迂回された**状態**（hooksPath 設定済み・シム欠落）は
  `check` の `hooks-path-overridden` / `hook-type-missing` が静的に検出する（v2.2）。
  この guard の挙動自体は `tests/guard_corpus.tsv` の再生（dirty/clean の前提列を含む）で
  回帰保護され、`dev.py probe "<cmd>"` で実行前に照会できる（v2.4 — .guardrails/GUARDRAILS.md §2）。
- **ターン終了ゲート（§2b）は fail-open**。差し戻しが3回続くと素通しになる（無限ループ
  防止の仕様）。ゲートが黙ったからといって規律7が消えたわけではない。v2.9 からは
  クリーンなツリーでも `dev.py check` が赤なら差し戻される（**条件B**——check の
  内部エラーや uv 不在は素通し＝fail-open の向きは同じ。uv 不在時は表示1行が出る）。
- **所有権ガード（§2c）も fail-open**。baseline 不在（SessionStart 未発火等）は警告1行で
  素通しになる——警告を見かけたら `/hooks` で SessionStart の有効を確認する。守れるのは
  「セッション開始時点で dirty だったファイル」だけで、セッション中の人間との並行編集は
  対象外（仕様——.guardrails/GUARDRAILS.md §2c）。
- `~/.claude/CLAUDE.md`（ユーザーグローバル）や `CLAUDE.local.md`、他エージェントの
  ツール別ルール（`.clinerules` / `.cursor/rules` 等）にキットの規則と矛盾する指示を
  書かない（G5——規約の正本はリポジトリ内の AGENTS.md（＋Claude Code 固有の CLAUDE.md）。
  層が違う指示は静かに競合し、門ではなく心得側から崩れる）。
- **`AGENTS.md`・`CLAUDE.md`・`STRUCTURE.md` を .gitignore に入れない**（判断ごと記録）:
  規約は統治するコードと**同じコミットに固定**されて初めて、CI の再現性（G1）・
  単一の正（G5）・規則変更のレビュー可能性が成立する——中央同期（Agent Rules MCP）を
  不採用にしたのと同じ理由の裏面。STRUCTURE.md は生成物だが、**追跡されていること
  自体が §3.2 の鮮度検査（コミット内容 vs 再生成の diff）の前提**であり、決定性設計
  （タイムスタンプなし・LF 固定 — §7.4）はまさに追跡可能にするための投資。ignore して
  よいのはセッション・一時状態（`.claude/session/`・`.red-first-*/`——同梱済み）だけ。
- キットの gitleaks / pre-commit-hooks の `rev` は実在する固定タグにしてある。導入時に
  Claude Code が `pre-commit autoupdate` で最新へ固定し直す（Step 3）。

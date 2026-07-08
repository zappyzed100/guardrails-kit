# PROMPT_claude_code.md — リポジトリ初期化時に Claude Code へ貼るプロンプト

使い方: 下の「入力」の ★ を埋め、罫線から下の全文をコピーして、リポジトリルートで起動した
Claude Code の**最初のメッセージ**として貼り付ける。

---

## 入力（ユーザー記入欄）

- 言語: ★（例: `TypeScript(React) + Supabase`。`bindings/catalog.md` に列がある言語なら列IDだけでも可）
- レイヤー構成と依存方向: ★（例: `app/ → engine/ の一方向。app はブリッジ経由でのみ engine を利用`）
- 確率的コンポーネント: ★ 有 / 無（有なら: コンポーネント名・本体の呼び出し関数名。例: `OR-Tools CP-SAT / solve()`）
- 必須ディレクトリ・必須ファイル: ★（例: `src/, CLAUDE.md, .guardrails/GUARDRAILS.md, .guardrails/GOALS.md`）
- 採用するバインディング列: ★（`bindings/catalog.md` の列ID@版。例: `ts-react-web@6`。新言語なら「新規に起こす」）
- ランタイム到達経路（操作レール）: ★（例: `Playwright MCP（Web）` / `CLI をそのまま実行` — §12.4）
- 中核不変条件: ★（壊れたら致命の性質と強制層。例: `打刻は append-only → DB GRANT で強制`。データを持つアプリで「なし」はまず疑う — §12.6）
- 外部I/O一覧: ★（依存する外部サービス全部とテスト用フェイクの方針。無ければ「なし」 — §9.5）
- GitHub リモート URL: ★（Step 9 の CI 実測に必要。未作成なら「gh で新規作成してよい」と書く）
- 特記事項: ★（無ければ「なし」）

## 任務

このリポジトリに「LLM の作業出戻りを防ぐガードレール」を敷設する。**手順・契約・完了条件の
正本は `.guardrails/GUARDRAILS.md`**。まず全文を読み、その **§11「新規リポジトリの
ブートストラップ」の Step 0 → 10 を、§10 冒頭の実行規律に従って完遂**すること。

実行規律の要点（詳細は .guardrails/GUARDRAILS.md §10 が正本。1つでも破れば未完了扱い）:
1. 順序固定・スキップ禁止。1 Step = 1 コミット（Step 9 以降は 1 PR）。
2. 完了 = 実行結果であり自己申告ではない。**成功系と違反注入の失敗系の両方**を実測してから ✅。
3. ✅ 化は実装と同一コミット。placeholder・TODO・空関数・「他も同様」での省略は禁止。
4. 途中でターンを終えない。「続けますか?」で止まらない。ユーザーへの質問は Step 0 の
   空欄確認のみに集約し、以降は質問しない。

## 配置（キットがまだ zip / 展開フォルダのままの場合のみ。配置済みならスキップ）

`.guardrails/GUARDRAILS.md` が無く、`guardrails-kit*.zip` か `guardrails-kit*` フォルダが
ある状態なら、**手でコピーせず**次で配置する。GitHub の「Download ZIP」や Release の
ソースzipは中身が `<repo>-<ブランチ/タグ>/`（例: `guardrails-kit-master/`）で
**1階層ネストされる**ため、`scripts/install_kit.py` を固定パスで決め打ちせず探索する:

```bash
python3 -m zipfile -e guardrails-kit-*.zip .guardrails-kit-src   # zip の場合のみ
python3 -c "
import glob, subprocess, sys
hits = glob.glob('.guardrails-kit-src/**/scripts/install_kit.py', recursive=True)
if not hits:
    sys.exit('scripts/install_kit.py が見つからない（配置を確認）')
sys.exit(subprocess.run([sys.executable, hits[0]]).returncode)
"
```

（`python3` が無ければ `py -3` / `uv run --no-project` で同じ引数のまま。手で展開済みの
フォルダをルートに置いた場合は1行目を飛ばして2行目だけ実行すればよい——`**` の探索が
ネスト有無どちらも吸収する）
新規リポジトリでは全行 `INSTALLED` になるのが正常。`CONFLICT` が出たら各行のヒントに
従って解消し**再実行**する（冪等）。exit 0 で zip・展開元は自動削除される。
`.claude/settings.json` を配置した直後は、ユーザーに
「`/hooks` で PreToolUse: Bash・Edit|Write|MultiEdit / PostToolUse / Stop / SessionStart
の4種5エントリの有効化を確認し、承認したら『続行』と返信してください」とだけ依頼して
待つ（§10 の質問集約の唯一の例外。ここが無効のままだと §1・§2・§2b・§2c の防壁が
静かに不在になる — fail-open）。『続行』を受けたら `git commit --no-verify` を1回試し、
**実際にブロックされるか**を実測で確認する。`/hooks` の表示が有効でもブロックされない
場合は、`.claude/settings.json` を**このセッション中に新規作成**したことで、プロセスが
起動時にしかフック設定を読み込んでおらず未反映という既知の症状の可能性がある（特に
VSCode 拡張のパネル経由）。その場合はユーザーに「このセッションを終了し、VSCode なら
拡張のウィンドウをリロード（または別のターミナルで `claude` を同じディレクトリで直接
起動）してから新しいセッションで続きを」と依頼して終了する。

## 配置済みファイル（重要: ゼロから書き直さない）

以下はすでに配置されている。**v2キットは言語なしで出荷**され、言語固有値は
`bindings/catalog.md` の検証済み列に集約——各ファイルの **BINDING** 領域へ採用列の
paste-block を充填し、`BINDING-SOURCE: 列ID@版` を刻印する（§12.7）:

| ファイル | 言語固有部の場所 |
|---|---|
| `scripts/repo_scan.py` | 後半の「BINDING」セクション（正規表現・パス・規則の充填先） |
| `scripts/dev.py` | 冒頭の COMMANDS（動詞→コマンドの充填先 — §12.1） |
| `bindings/catalog.md` / `.guardrails/GOALS.md` | 検証済み列の正本／変更レビュー基準（どちらも複製対象） |
| `scripts/generate_structure.py` / `check_structure.py` / `check_commit_msg.py` | なし（repo_scan.py の BINDING を参照するだけ） |
| `.pre-commit-config.yaml` | 「BINDING」マーカー以下の pre-push フック群 |
| `.claude/hooks/post_edit_format.py` | DISPATCH 辞書（拡張子×整形コマンド。直接バイナリを指す——npx/uvx 経由は避ける） |
| `.claude/hooks/post_edit_lint.py` | DISPATCH 辞書（拡張子×単一ファイル lint——表A「編集直後 lint」。予算不適合の言語は「該当なし」のまま素通し — §1） |
| `.claude/hooks/guard_git_bypass.py` / `.claude/settings.json` | 言語非依存（原則そのまま。settings の PostToolUse は整形→lint の直列1コマンド——並べ替えない） |
| `.claude/hooks/stop_incomplete_guard.py` | 言語非依存（そのまま — §2b のターン終了ゲート） |
| `tests/guard_corpus.tsv` / `scripts/check_guard_corpus.py` | 言語非依存（そのまま。guard に規則を足したら**同一コミット**でコーパスにも行を足す — §2） |
| `.github/workflows/guardrails-ci.yml` | 「BINDING」マーカー以下のテスト・解析ジョブ |
| `.python-version` / `.gitattributes` | 言語非依存（そのまま） |
| `scripts/install_kit.py` | なし（配置・マージ・後片付け専用。再実行は冪等） |
| `AGENTS.md.template` | ★ 印（Step 1 で AGENTS.md に完成させる——全エージェント共通規約の正本） |
| `CLAUDE.md.template` | ★ 印（Step 1 で CLAUDE.md に完成させる——冒頭 `@AGENTS.md`＋Claude Code 固有の薄い層。規約本文を複製しない — §6） |
| `.guardrails/BOOTSTRAP.md` | 固有名詞リストC（Step 0 で記入。進捗台帳——✅ 化の規律は §3.5） |

**移植とは、契約（.guardrails/GUARDRAILS.md §1〜§9・§12）を変えずに BINDING を充填すること。**
カタログに採用列があれば paste-block を貼って刻印するだけ。新言語は表A/B/Dを埋めて
**新しい列としてカタログへ還元**する（§12.7）。
契約側を緩める必要が出た場合のみユーザーに確認する。

## Step の読み替え（配置済みファイルがある前提での具体化）

- **Step 0**: 上の「入力」と .guardrails/GUARDRAILS.md §11 の表A/B/C/Dを突き合わせ、採用列を確定して
  対象ファイルへ `BINDING-SOURCE` を刻印し、全セルを埋めて `bindings/catalog.md`
  （新列・差分の還元先）と .guardrails/GUARDRAILS.md 末尾に記録し、Step チェックリストを 🚧 で
  複製して**最初のコミット**にする。空欄が残る場合のみ、ここでまとめてユーザーに質問する。
- **台帳の運用（全 Step 共通 — .guardrails/GUARDRAILS.md §3.5）**: 進捗の正本は `.guardrails/BOOTSTRAP.md`。
  Step 0 で固有名詞リストCを台帳へ記入し、各 Step の完了時に該当行を ✅ にして
  **その Step の実装と同一コミット**に含める（✅ 化は1コミット1Step・番号順のみ——
  `check-bootstrap` が ✅ の主張を再実行検証し、落ちたら 🚧 に戻して再実装する）。
- **Step 1**: 表Bのディレクトリ骨格を作成。`AGENTS.md.template` を `AGENTS.md` に、
  `CLAUDE.md.template` を `CLAUDE.md` に**同一コミット**で完成させる
  （★ を全置換・冒頭のテンプレコメント削除・章の削除統合禁止・規約本文は AGENTS.md 側のみ）。
  最小の README.md 作成。
  完了条件: 固有名詞リストCで `git grep` して残置 0 件・`TODO` 0 件・★ 0 件。
- **Step 2**: `scripts/repo_scan.py` の BINDING へ採用列の paste-block を充填
  （`scripts/dev.py` はこの時点では `check` 配線と `verbs` 表示の確認まで——残りは Step 8b）→ `uv run scripts/generate_structure.py` で STRUCTURE.md
  初回生成 → DoD 実測: ①2回連続実行で差分ゼロ ②`--check` の exit 0/1 と内部エラーの exit 2
  ③**この時点で有効な全 hard 規則**（layer-violation / missing-required / test-sleep /
  test-nondeterminism / log-direct-call / missing-catch-unwind / 設定していれば
  required-content・solver-direct）に**1件ずつ**違反ファイルを注入し、規則ID付きの1行で
  落ちるのを確認して除去 ④フルスキャン2秒以内。
- **Step 3**: `uv tool install pre-commit` → `pre-commit install` → 違反注入コミット
  （末尾空白 / hard 違反 / ダミー秘密文字列）が**3種それぞれの理由で**落ちるのを実測 →
  解消して同じコミットが通るのを実測。`pre-commit autoupdate` で rev を最新に固定し直す。
- **Step 4**: `.claude/` は配置済み。`chmod +x .claude/hooks/*.sh` を確認し、
  ①`git commit --no-verify` と `git push --force`（引数順を変えた形も）がブロックされる ②STRUCTURE.md への Edit が拒否される
  ③対象ファイル編集直後に整形が当たる、を実測する（①②の「わざと1回試みて拒否を見る」は
  検証であり違反ではない。拒否されたら即座にやめる）。加えて（v2.4）
  ④`uv run scripts/check_guard_corpus.py` が全行 PASS ⑤`uv run scripts/dev.py probe
  "git push -f"` が DENY を返す、も実測する（Stop ゲート §2b は通常作業の中で
  挙動が観測される——ダーティなまま終了しようとすると差し戻される）。
- **Step 5**: commit-msg 検査はスクリプト・設定とも配置済み。`pre-commit install` の再実行と
  DoD（不正プレフィックスで落ちる / テスト無し fix: で落ちテスト同梱で通る / Merge 素通し）
  の実測が本 Step の実体。
- **Step 6**: pre-push フックは配置済み。lint 昇格の設定
  （参照実装: `app/analysis_options.yaml` の avoid_print/empty_catches を error 化、
  `engine/Cargo.toml` の `[lints.clippy]` で print_stdout/print_stderr/dbg_macro を deny —
  .guardrails/GUARDRAILS.md §8.1）を作成し、warning 注入とテスト破壊で push が落ちるのを実測。
  テストが無い層には**通るテストを1本置いてでもゲートを先に立てる**。
- **Step 7**: ログ単一出口（参照実装: `app/lib/services/log.dart` の
  `logOp(String tag, String op, String detail, {Object? error, Duration? elapsed})` と
  `engine/src/logging.rs` — §8.2）を実装。`log-direct-call` 検査は有効化済みなので、
  直呼び注入で落ちるのを実測し、実ログが `[タグ] 操作名: 詳細 (+Xms)` 形式で出るのを確認。
- **Step 8**: 非決定パターン検査は有効化済み（違反注入の実測は必須）。確率的コンポーネント
  「有」の場合のみ: `xxx_for_test(input, seed, max_time)` ラッパーを実装し、
  `repo_scan.py` の `SOLVER_DIRECT_CALL_PATTERNS` / `SOLVER_TEST_WRAPPER_NAME` を設定して
  直呼び注入で落ちるのを実測。同一 seed 2回で結果一致・極端に短い timeout でもハングしない
  ことを実測。
- **Step 8b**: .guardrails/GUARDRAILS.md §11 Step 8b のとおり——D表の動詞充填・時刻注入シーム・
  操作レール（Web 列なら `.mcp.json` に Playwright MCP。`.claude/settings.json` は
  `enableAllProjectMcpServers` 済み）・`test-network` / `ui-missing-testid` の違反注入・
  E2E 1本と `reset`→2回一致の実測。
- **Step 9**: `guardrails-ci.yml` は配置済み。ツールチェーン版の固定を確定し、リモートへ push。
  正常 PR で全ジョブ緑 → **GitHub の Web エディタから**違反を1件コミットした検証ブランチの
  PR が赤になるのを実測（ローカルフックが存在しない正規経路なので §2 の迂回禁止に抵触
  しない）→ 検証ブランチ削除。
- **Step 10**: 総合セルフ監査（.guardrails/GUARDRAILS.md §11 Step 10 のとおり: チェックリスト全行の
  同一コミット✅・TODO 0件・固有名詞 0件・**全規則IDの違反注入実績**の突き合わせ・
  残項目の §10 Phase 登録）。

## 報告形式

各 Step 完了時に「実行コマンド / 違反注入の失敗出力（抜粋） / 解消後の成功出力（抜粋） /
コミットハッシュ」を短く報告して、止まらずに次の Step へ進む。全 Step 完了後、
チェックリスト全 ✅ の最終監査結果を報告し、**`.guardrails/CUSTOMIZE.md` の存在と読みどころ
（数値調整・サンプル差し替え・トリガー待ち機能・規則の一時停止・逃げ道・MCP追加・
規約文書の編集——の7項目）を1行で案内**して終了する。

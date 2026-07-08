# SURVEY_GATE_ARCHITECTURES.md — 調査④: 門主導アーキテクチャ群（2026-07-07・キット v2.17 時点）

> 位置づけ: ユーザー提供の外部リサーチ（Meta RADAR / StrongDM Dark Factory / VibeReady /
> Claude Code Hooks / AST ゲート / サンドボックス）を採用ゲート3条＋「門>心得」で判定した
> 記録。採用は v2.18 に実装済み。数値主張（RADAR の revert 1/3・PI 1/50、SecPass 10.5% 等）
> は未検証の仮アンカー扱い——ただし方向は本キットの存在理由の需要側データとして記録。

## 0. 結論サマリ
レポートの大半は**本キットの現行機構の外部裏書き**（詳細 §3）。本物の空白が2つ見つかり
採用（`env-file-tracked` hard・`test-shrink` soft）、複雑度ゲートは**列の linter 対応表**
として正本化（自作 AST 検査は不採用——linter が上位互換）、Clean Room QA は保留登録。

## 1. 採用（v2.18 実装）
| 知見 | キットでの形 |
|---|---|
| must ティア絶対足切り（VibeReady penaltyRule）の具体項目「.env の追跡」 | **hard 検査 `env-file-tracked`**: 追跡された `.env` 系ファイルを拒否（`.env.example` 等の雛形は除外）。gitleaks は内容パターン検査＝低エントロピー値の .env を素通りし得る空白を塞ぐ |
| Clean Room QA の脅威モデル「AI はテストを通すためにテスト自体を都合よく書き換える」 | **soft 検査 `test-shrink`（§3.4 検査8）**: fix/feat コミットでテストファイルが**純減**（削除行>追加行）なら警告。既存テストの弱体化＝門を欺く最短路の可視化（red-first が守るのは「新テストが親で赤」まで——既存テストの assertion 削除は未監視だった） |
| AST 複雑度ゲート（サイクロマティック複雑度・ネスト・引数・関数行数） | **catalog 注記「関数複雑度ゲートの対応表」**: 各列の linter ネイティブ規則（ruff C901/PLR091x・eslint complexity/max-depth/max-params・clippy too_many_arguments 等・dart_code_metrics）を Step 6 lint 昇格時の推奨として正本化。**自作 AST/regex 複雑度検査は不採用**——linter の AST が上位互換（重複排除ゲート）で、Lizard 追加は依存増 |

## 2. 保留（GUARDRAILS §10 へ登録）
- **Clean Room 隔離テスト**（Builder から読めない受け入れテスト・CI のみ実行）: トリガー =
  **テストの改変・弱体化による門の欺きを実際に観測した時**（センサー = `test-shrink` の
  警告常態化）。設計スケッチ: `.cleanroom/` ＋ `.claude/settings.json` の
  `permissions.deny: Read(.cleanroom/**)` ＋ CI 専用実行。コスト注記: 隠しテストは
  **人間が書く**しかなく（LLM は読めない物を保守できない）、単独開発では高価——
  発火まで実装しない。

## 3. 裏書きとして記録（機構は足さない——既存が同型/上位）
| レポートの機構 | キットの既存対応物 |
|---|---|
| RADAR「機械の門は人間レビューより安全」（revert 1/3・PI 1/50） | 存在理由の需要側データ。リスクスコア ML・自動マージは対象外（調査③の整理どおり: auto-merge は GitHub 設定の人間判断・キットは全緑を供給する側） |
| PreToolUse による破壊的コマンド遮断（rm -rf / deny JSON / exit 2） | §2 guard_git_bypass＋コーパス回帰がそのもの（キットはさらに回帰テスト付き） |
| ペナルティルール（must の F で全体 C 制限） | HARD/SOFT の**二値**が上位互換——点数化は「C でも通る」余地を作る。must 項目の実体（秘密・依存監査）は gitleaks／保留（調査③）が担当 |
| 無限ループ遮断器・ハードストップ | §2b Stop ゲートの回数上限＋「同じフックが2回連続で落ちたら原因調査」（AGENTS §10-4）が同型。スライディングウィンドウ検知は実行時層＝対象外 |
| 独立モデルによる完了判定（grading its own homework 回避） | **不採用**——LLM 判定は非決定＝門になれない（調査③ Vibe Testing と同根）。キットの他人採点は決定的検証（Stop ゲート条件B＝check の exit code） |
| Attractor の状態機械・versioned markdown 記憶（GOAL.md/decisions.md） | plan.md（G14 意図の保存）・.guardrails/BOOTSTRAP.md（監査台帳）が同型。中央メモは §13 で禁止のまま |
| サンドボックス・Capability 制約（Docker/WASM・ネットワーク隔離） | **対象外**（実行環境層）。Claude Code の permissions.deny 網は §2 で配線済み。コンテナ隔離は個人インフラ判断——導入してもキットの門は同じに効く（層が直交） |

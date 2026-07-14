# 導入計画: 外部ハーネスツールからの機能輸入（2026-07-14）

> **実施結果（同日・v2.42・Phase 44）**: A〜E 全 Phase 実施済み。調査の正本は
> `surveys/SURVEY_HARNESS_TOOLS.md`、実装記録と DoD は GUARDRAILS §10 Phase 44。
> 計画からの変更2点: ① B-2 の動詞名 `test` は §12.1 の既存 test（製品テスト）と衝突する
> ため `selftest` に変更 ② E-3（秘密マスク）の技術検証は**成立側で確定**
> （`updatedToolOutput` は公式仕様に実在——HARNESS-VERIFIED 2026-07-14）し、常駐予算を
> 理由にトリガー付き保留として登録（実現不能ではなく、今は買わない、へ判定が変わった）。

## 0. 入力と検証状態（完了=実行結果の適用）

入力はユーザー提供の外部比較調査（別セッション——oh-my-harness / nizos-probity /
agent-guard / dwarvesf-claude-guardrails / vibeguard）。**各リポジトリの機能主張は本計画
時点で一次未確認**（対話記録経由の転記）。Phase A の一次確認を通過した項目だけが
Phase B 以降の実装対象として確定する——確認で主張と実物が食い違った項目は、その場で
判定を書き換える（SURVEY_LLM_TESTGEN.md の入力品質注記と同じ型）。

## 1. 方針（3つの拘束条件）

1. **導入方法の整備は専用 Python で行う（ユーザー要件・絶対条件）**: ブートストラップと
   更新の「プロンプト＋エージェントの意味解釈」への依存を縮小し、機械で決定できる部分を
   `install_kit.py` と `dev.py` のサブコマンドへ移す。Phase B が本計画の主役。
2. **記録済み判断との整合（再提案ループ防止）**: 外部調査の最優先提案「宣言ファイル
   （guardrails.yaml）を正本にした生成・同期」は、`bindings/catalog.md` 運用ルールが
   **不採用を記録済み**（理由: 検査を持たない生成器はドリフト源／貼られた値は grep 可能な
   実物／移植の定数時間は列選択で達成済み。復活トリガー = 版上げの手作業還元がドリフト
   検査の赤で繰り返し実測された時）。トリガーは未成立——本計画では**生成を伴わない範囲**
   （検出・診断・差分表示・区画移植）だけを採り、生成正本化そのものは採らない。
   外部調査はこの記録を参照せずに提案しており、そのまま輸入すると記録済み判断の黙殺になる。
3. **保留台帳との接続**: 「管理範囲マーカー」は既存保留「BINDING 充填のマーカー包み＋
   機械移植」（v2.38 登録）の前倒し発動として実装する（重複登録しない）。前倒しの判定
   理由: ユーザー指示＋Phase B の diff/check がマーカー区画を前提にすると精度が上がる
   （区画の内外で「機械が見る/人間が守る」を分けられる）。

## 2. Phase A — 調査の正本化（surveys/SURVEY_HARNESS_TOOLS.md）

- 5リポジトリを一次確認（実リポジトリの README・実装の該当箇所）し、既存調査と同じ
  採用/保留/不採用の判定表に固定する。G引用必須。
- 確認の観点（対話記録の主張の裏取り）: ① oh-my-harness の sync --check / diff / doctor /
  test の実装実態 ② TDD ガードが「テスト実行なしのファイル編集記録」である点（red-first
  との差の確認） ③ agent-guard の PostToolUse マスクが Claude Code のフック API で
  実際に何をしているか（後述 E-3 の技術検証を兼ねる） ④ probity の requireCommand の
  セッション状態の持ち方。
- 完了条件: 判定表がコミットされ、以降の Phase の各項目が表の行を引用できる。

## 3. Phase B — 導入 CLI の整備（最優先・ユーザー絶対条件）（G12/G13/G2/G4）

### B-1. `install_kit.py` の拡張（導入・更新の機械化）

| サブコマンド | 中身 | 置き換える現行手順 |
|---|---|---|
| `--detect` | マニフェスト（package.json / pyproject.toml / Cargo.toml / pubspec.yaml）と特徴ファイル（vite.config.* 等）から**採用列の候補を判定して提示**（提案のみ・確定は人間/エージェント） | PROMPT の Step 0 前半（列の選択）。質問は機械で導出できない残り——レイヤー構造・ログ出口・確率的コンポーネント・独立オラクル・中核不変条件——だけに縮小（G12） |
| `--diff` | 適用**前**に OK/INSTALLED/UPGRADED/KEPT/CONFLICT の判定を**書き換えずに**全件表示（現行 `--dry-run` の出力を更新判断用に整形・KEPT の検証条項の充足状況も表示） | 更新プロンプト Step U1 の目視判断 |
| `--check` | 配置済みキットのドリフト検出（KIT_SIGNATURES 系統ファイルのバイト差＋検証条項）。**CI から呼べる exit 契約**（0=一致/1=ドリフト） | 現行は installer-token-drift（原本側のみ）＋導入先は無防備——「新版が出たのに導入先が旧版のまま静かに走る」の可視化 |

- 規約は現行どおり: stdlib のみ・決定的判定（G1）・1行1ファイル（G4）・fail-closed（G9）。
- DoD（違反注入）: detect=マニフェスト混在リポジトリで列候補が正しく複数出る／未知構成で
  「候補なし・Step 0 へ」と明示。diff=書き換えゼロを before/after ハッシュで確認。
  check=1ファイル改変を注入して exit 1・改変行の特定。

### B-2. `dev.py` への動詞追加（診断の1コマンド化）

| 動詞 | 中身 | 新規実装か |
|---|---|---|
| `doctor` | 環境診断の集約フロント: uv / pre-commit シム / core.hooksPath / settings.json のフック配線 / .claude/session / installer `--check` を**既存検査の呼び出しと表示に限定**して束ねる | 集約のみ（新検査は作らない——G11。実体は check_structure の hooks 系規則＋installer --check） |
| `test` | 門の違反注入コーパス一括実行: check_guard_corpus＋check_ownership_guard＋check_codex_hooks（＋bootstrap-verify-scenarios） | 集約のみ。「門のテスト」を G2 の1動詞にする |

- DoD: doctor=シム欠落・hooksPath 上書きをそれぞれ注入して1行ずつ検出。test=コーパス
  1行の期待値を反転させて mismatch を検出。

## 4. Phase C — 管理範囲マーカー（既存保留の前倒し発動）（G13/G5）

- `# >>> GUARDRAILS MANAGED <<<` 〜 `# <<< GUARDRAILS MANAGED <<<` 区画を、マージ対象
  ファイル（AGENTS.md / CLAUDE.md / .pre-commit-config.yaml / settings.json / repo_scan.py
  の BINDING）へ導入し、インストーラが UPGRADED/KEPT 判定時に**区画だけを機械移植**する
  （.gitignore のキット区画マーカーで実証済みの型を全対象へ一般化）。
- 区画外は人間/プロジェクトの領分として**無条件に保持**——「共通部分は新版から、充填部分は
  列から、固有部分は保持」の三層が機械で分離できる。
- `BINDING-SOURCE` 刻印との関係: 刻印=どの列のどの版か（宣言）、マーカー=更新時に機械が
  触ってよい範囲（境界）。役割が違うため併存。
- 保留台帳の当該項目はこの Phase の完了で解消（台帳に発動理由を記録して閉じる）。
- DoD: 旧版区画＋区画外の手書き行を持つフィクスチャへ新版を適用→区画だけ更新・手書き行
  無傷をバイト比較で確認。区画マーカー破損（片側欠落）→ CONFLICT で停止。

## 5. Phase D — 実ホスト経路の live probe（G7/G9）

- 現行の違反注入はフックを**コーパス経由（同じ stdin 形式）**で呼ぶ——フック単体の正しさは
  証明するが、「実際のセッションでハーネスがフックを発火させているか」（設定の配線・
  /hooks の信頼状態・ハーネス側仕様変更）は証明しない（§2d が可視化した空白の実測版）。
- `dev.py probe --live`: セッション内で実行する無害な sentinel 違反（例:
  `git commit --no-verify --allow-empty -m "GUARDRAILS-LIVE-PROBE"`）を案内し、
  違反ログ（§3.6）に当該 BLOCK が記録されたことを機械確認して PASS/FAIL を返す。
- ブートストラップ Step 4 / 8b の DoD に「live probe PASS（Claude Code / Codex 各経路）」
  を追加——「フックは書けたが実経路で発火していない」という静かな fail-open の検出。

## 6. Phase E — 保留登録のみ（トリガー成立まで実装しない）

| 項目 | 判定とトリガー |
|---|---|
| E-1. 宣言ファイル正本化＋プロファイル（base/ui/solver） | **不採用の維持**（拘束条件2）。プロファイル分割の実需要（UI 採用先で第2構成が要る実測）が出た時に、既存の復活トリガーと併せて再判定。生成器は検査と対でしか導入しない |
| E-2. requireCommand 型の順序ゲート（「B の前に A 実行済み」） | 保留。トリガー = 採用先で順序起因の事故（deploy 前 check 漏れ・migration 前 backup 漏れ）の実測。実装形はセッション状態（.claude/session/——Phase 16 基盤）＋PreToolUse |
| E-3. PostToolUse の秘密マスク（モデルが見る前に出力を書き換え） | **技術検証が先**（Phase A に含める）: Claude Code の PostToolUse がツール出力をモデル到達前に変換できるかは未確認——できないなら「マスク」は成立せず、現行の deny-read＋env-file-tracked＋gitleaks の強化のみが正しい形。検証結果を §2d の HARNESS-VERIFIED 形式で記録してから判定 |
| E-4. AI 判定型 TDD（probity の主要判定） | **不採用**。非決定な判定は門になれない（G1——Vibe Testing と同じ判定・SURVEY_ZERO_REVIEW.md）。決定的な red-first が既にあり、置き換える理由がない |

## 7. 実施順序と規模感

A（調査・半日）→ B-1（1日）→ B-2（半日）→ C（1日）→ D（半日）→ E（登録のみ・A と同コミット可）。
B を C より先にするのは、diff/check の出力が区画設計の入力になるため（区画なしでも
ファイル単位で動く→区画導入で行単位に精緻化、の順が手戻りなし）。

## 8. この計画が変えないもの

- 門の実体（フック・pre-commit・CI・検査器）は本計画では触らない——輸入するのは
  **導入・更新・診断の外皮**であり、検査そのものではない。
- プロンプト文書（PROMPT_*.md）は廃止しない——エージェントに残る仕事（レイヤー設計・
  中核不変条件の記入・列の新規起こし）の台本として維持し、機械化された部分の記述を
  「CLI を呼べ」に置き換える。

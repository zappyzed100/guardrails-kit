# SURVEY_HARNESS_TOOLS.md — 調査: 外部ハーネス・導入ツール系の知見（2026-07-14・キット v2.41 時点）

> 位置づけ: ユーザー提供の外部比較調査（別セッション）を入力に、**5リポジトリを本調査で
> 一次確認**（GitHub 実物＋Claude Code 公式ドキュメント——2026-07-14 WebFetch）した上で、
> キットの採用ゲート＋「門>心得」で判定した記録。実施計画の正本は
> `docs/plans/2026-07-14-harness-tools-import.md`。採用は v2.42 に実装。

## 0. 一次確認の結果（対話記録の主張との照合）

| リポジトリ | 実在 | 規模・鮮度 | 主張との差 |
|---|---|---|---|
| kyu1204/oh-my-harness | ✅ | ★13・v0.18.0（2026-06-08）・900+テスト | 主張どおり: harness.yaml 正本＋sync/diff/doctor/test・14言語検出・Claude/Codex 両対応。**TDD ガードは「テストファイルが先に編集されたか」の記録のみ**（テスト実行なし・赤の証明なし——red-first との差も主張どおり） |
| nizos/probity | ✅ | ★83・v1.10.0（2026-07-08）・32リリース | 主張どおり: TS ルール API（forbidCommandPattern / requireCommand / forbidContentPattern / enforceFilenameCasing）・3ホスト対応。**TDD 判定は AI ベース**（公式 SDK 経由）。requireCommand のセッション状態はトランスクリプト解析と推測（実装詳細は未確認のまま） |
| JeongJaeSoon/agent-guard | ✅ | ★13・v1.10.1（2026-07-13） | 主張どおり＋重要な技術確認: 秘密マスクは Claude Code の **PostToolUse `updatedToolOutput`**（ネイティブ出力書き換え）で実装、Codex はフック未実装のため `additionalContext` で代替。live probe は sentinel コマンド2種で Pre/PostToolUse の実発火を確認する必須セットアップ手順 |
| dwarvesf/claude-guardrails | ✅ | ★26・v0.3.8（2026-04-17） | 主張どおり: セキュリティ特化（機密パス deny・危険コマンド・秘密スキャン・プロンプトインジェクション防御）。開発品質の門ではない |
| vibeguard（SpecRail） | ⚠️ | — | **一次特定できず**。majiayu000/vibeguard（Claude Code/Codex の幻覚・重複防止ルール集）は実在するが、対話記録の「SpecRail＝Issue→仕様→実装の状態機械」に該当する実装は確認できなかった。スコープ外（統治層の外——調査②の判定と同じ）のため追跡しない |

**ハーネス仕様の一次確認（HARNESS-VERIFIED: code.claude.com/docs/en/hooks 2026-07-14）**:
PostToolUse の `hookSpecificOutput.updatedToolOutput` は**公式仕様に実在**し、ツール結果を
モデル到達前に置換できる（`additionalContext` も併存）。公式ドキュメント自身が
「redaction や transformation には PreToolUse（送信側）/ PostToolUse（受信側）で
インターセプトせよ」と記載。→ 計画 E-3 の技術検証は**成立側で確定**（採否は別判断——§2）。

## 1. 採用（v2.42 実装——実装の DoD は §10 Phase 44）

| 知見（出典） | キットでの形 |
|---|---|
| 適用前の差分表示・ドリフト検出・診断の CLI 化（oh-my-harness の diff / sync --check / doctor / test） | `install_kit.py --detect / --diff / --check` と `dev.py doctor / test`。**生成は伴わない**（検出・診断・表示のみ——下記不採用1との境界） |
| マニフェストからのスタック自動検出（oh-my-harness の14言語検出） | `install_kit.py --detect`: package.json / pyproject.toml / Cargo.toml / pubspec.yaml から採用列の**候補を提示**（確定は Step 0 の人間/エージェント）。Step 0 の質問は機械で導出できない残り（レイヤー・ログ出口・確率的コンポーネント・独立オラクル・中核不変条件）へ縮小（G12） |
| ユーザー編集部分を保持する管理範囲マーカー（oh-my-harness の managed sections） | 既存保留「BINDING 充填のマーカー包み＋機械移植」（v2.38）の**前倒し発動**: `# >>> GUARDRAILS BINDING >>>` 区画を充填先 Python 4ファイル（repo_scan / dev / post_edit_format / post_edit_lint）に導入し、インストーラの UPGRADED が**区画だけ既存を保持**して更新する。**YAML 系（.pre-commit-config.yaml / guardrails-ci.yml）は対象外**——ユーザー統合が kit 区画の「内側」（repos: リスト・jobs: 配下）に入る構造のため区画スプライスが安全でない（判断ごと記録。従来どおり検証条項 KEPT＋installer-token-drift） |
| 実ホスト経路の live probe（agent-guard の sentinel 検証） | `dev.py probe --live`: nonce 入り sentinel 違反（`git commit --no-verify …`）を案内し、違反ログ（§3.6）への BLOCK 記録を機械確認。フック単体試験（コーパス——同じ stdin 形式の再生）が証明しない「実セッションでハーネスが本当にフックを発火させるか」を埋める（§2d の空白の実測版） |

## 2. 保留（トリガー登録——GUARDRAILS §10）

- **PostToolUse 秘密マスク**（agent-guard 型）: 実現可能性は**確定**（上記 HARNESS-VERIFIED）。
  それでも即採用しないのは常駐予算（G11/G3——全ツール呼び出しに毎回フック1本＝§7.7 の
  予算を常時消費）と偽陽性（正当な出力の破壊）のため。トリガー = 対象リポジトリが
  **本番運用・顧客データ段階**に入った時（依存・脆弱性監査と同じ閾値）、**または**
  ツール出力経由の秘匿値がコード・transcript へ混入した実測1回。Codex 側は
  `updatedToolOutput` 相当が無い（agent-guard も additionalContext 代替）＝マスクは
  Claude Code 限定の門になることを採用時の設計制約として先に記録。
- **requireCommand 型の順序ゲート**（probity 型——「A 実行済みでなければ B 禁止」）:
  トリガー = 採用先で順序起因の事故（deploy 前 check 漏れ・migration 前 backup 漏れ）の
  実測。実装形はセッション状態（`.claude/session/`——Phase 16 基盤）＋PreToolUse。

## 3. 不採用（判断ごと記録——再提案ループ防止）

| 候補 | 不採用の理由 |
|---|---|
| **harness.yaml 型の宣言ファイル正本化＋生成・同期** | `bindings/catalog.md` 運用ルールに**記録済みの不採用判断の維持**（検査を持たない生成器はドリフト源／貼られた値は grep 可能な実物／G13 は列選択で達成済み。復活トリガー = 版上げの手作業還元がドリフト検査の赤で繰り返し実測——未成立）。外部調査はこの記録を参照せず再提案しており、そのまま輸入すると再提案ループ防止の否定になる。今回輸入したのは**生成を伴わない部分集合**（検出・差分・診断）のみ |
| **プロファイル分割（base/ui/solver の extends）** | 上と同根（生成層の導入が前提）。第2プロファイルの実需要（UI 採用先）が出た時に復活トリガーと併せて再判定 |
| **AI 判定型 TDD**（probity の主要判定） | 非決定な判定は門になれない（G1——Vibe Testing と同じ判定・SURVEY_ZERO_REVIEW.md）。決定的な red-first が既にある |
| **oh-my-harness の TDD ガード**（テストファイル先行編集の記録） | 「テストを先に**触った**」は「テストが赤だった」を含意しない——red-first の下位互換で輸入する物が無い（一次確認で実装方式を確定済み） |
| **dwarvesf/claude-guardrails の deny ルール群** | 重複排除ゲート: §2（フック＋deny の二重防壁）・gitleaks・env-file-tracked が同役を既に持つ。プロンプトインジェクション防御は §2 の外部裏書き（「deny は補助・主防壁はフック」）として記録のみ |

## 4. 裏書きとして記録（機構は足さない）

- oh-my-harness の「omh test = 疑似入力をフックへ渡して allow/block 確認」は、キットの
  guard コーパス（§2・v2.4）と**同型の独立発明**——「門は違反注入で検証する」収斂の追加裏書き。
- probity の requireCommand は「操作の順序も門にできる」ことの実証——キットでは §12.1 の
  共通動詞が同じ層（ただし現状は心得）。保留2の設計出発点。

# SURVEY_FAMOUS_KITS.md — 著名な同種キットの調査②（2026-07-07・キット v2.12 時点）

> 位置づけ: 採否判定のための調査。判定はキットの採用ゲート（v2.11 調査①の3条: 重複排除・
> 常駐予算・契約整合）＋「門>心得」で行い、採用分は v2.13 に実装済み。本書は正本にしない。

## 0. 結論サマリ
著名キットの大半は**プロンプト層（skills / slash commands / ペルソナ / チェックリスト）の
規律**であり、本キットの差別化点＝**git フック・CI 層の機械強制**はどれも持たない。
最重要の発見は外部裏書き2件: ① Martin Fowler の実測——Spec Kit のチェックリストは
「AI が解釈するため遵守の保証が無い」 ② EPAM 事例——constitution の明文規則
（「route handler に try-catch 禁止」）が無視された。**「心得はどれだけ立派でも破られる」**
は本キットの設計前提そのもの。採用は機械化可能な2知見のみ（feat のテスト同梱・
コミット規模）＝ v2.13 の検査6・8（いずれも soft 導入・昇格トリガー登録）。

## 1. 調査対象と判定表

| キット（作者/背景） | 本質 | 本キットとの対応 | 判定 |
|---|---|---|---|
| **Superpowers**（Jesse Vincent / obra。公式マーケットプレイス収載・数万star。Simon Willison が高評価） | skills 群で brainstorm→plan→worktree→**TDD 鉄則**→二段レビューを強制。「テスト前のコードは削除」 | TDD: 本キットは fix 側のみ機械化（検査2＋red-first CI）で **feat 側が空白** | **知見1採用**→検査6 `feat-without-test`（soft）。skills 層自体は v2.11 保留に包含 |
| 同上の plan 規律 | plan を「2〜5分粒度のタスク＋検証コマンド」に分割。チェックボックスがセッション復旧の状態ログ | 実行規律2は Phase 単位のみ。一般開発のコミット規模は未可視 | **知見2採用**→検査7 `commit-too-large`（soft・400行・列上書き可）＋心得3行（テンプレ §4/§8/§10） |
| **GitHub Spec Kit**（Microsoft/GitHub 公式・最大手） | constitution（不変原則）→ specify→plan→tasks のCLI＋テンプレ。チェックリスト=各段の DoD | constitution ≒ .guardrails/GOALS.md（ただし本キットは G引用を**機械検査**——検査3）。段階 DoD ≒ BOOTSTRAP 監査（本キットは**再実行検証**） | 不採用（同等機構を門で保有）。Fowler/EPAM の実測が「解釈依存の限界」を示す——**裏書きとして Phase 25 に記録** |
| **Kiro**（AWS・IDE。EARS 記法・hooks・SMT 矛盾検査） | spec→design→tasks を IDE が強制。hooks はイベント駆動エージェント | hooks ≒ 本キットの .claude/hooks（本キットはコーパス回帰つき）。EARS = 受け入れ条件の形式 | 不採用（IDE ロックイン・形式強制は偽陽性>価値 §7.4。「テスト可能な受け入れ条件」は §8 の心得で充足） |
| **BMAD-METHOD**（46k+ star） | 12+ ペルソナ（PM/Architect/QA…）のマルチエージェント。版付き成果物のハンドオフ | §5-5 で不採用済みの型。調査でも「ハンドオフのファイル受け渡しが実装で崩れる」報告 | 不採用再確認 |
| **OpenSpec** | brownfield 向け提案先行・差分マーカー・living spec | PROMPT_claude_code_existing（棚卸し→段階有効化）が同思想。spec 鮮度は本キットでは STRUCTURE.md を機械検査 | 不採用（同等保有）。「living spec の drift」問題は本キットでは生成+diff で解決済みの型 |
| **GSD**（61k+ star・メタプロンプト） / **Ralph Loop**（ghuntley） | 低セレモニーのプロンプト枠組み / ステートレス反復実行 | プロンプト集・実行時オーケストレーション | 対象外/不採用（v2.11 のプロンプト集型と同根。ループ実行はキット層の外——門はどの回し方でも効く） |
| **Beads**（issue 台帳） / Memory Bank 系 | エージェント用タスク/記憶台帳 | §13 中央メモ禁止・plan.md・.guardrails/BOOTSTRAP.md | 不採用再確認（台帳が正当なのは「機械検証できる場合」のみ＝BOOTSTRAP の設計判断を再確認） |
| worktree 並列（Spec Kitty / Conductor / Superpowers） | ブランチ隔離の自動化 | 門はブランチ構成非依存 | 対象外（個人ワークフロー層） |
| **Traycer** / Augment Intent | Plan→Execute→**Verify** 層・living spec の双方向更新 | Verify ≒ 本キットの門群 | 不採用（同等保有）。「spec への書き戻し」は今後の観察対象（採用ゲートを通せる機械形が出たら再評価） |

## 2. 本キットに無くて著名キットにあるもの（正直な差分）
- **要求の引き出し（brainstorm/specify）**: 本キットは意図の「保存」（G14）まで——「引き出し」は
  人間とプロンプトの領分と整理（機械検証不能）。
- **実装中のレビュー段**: 二段レビュー（Superpowers）はプロンプト層。本キットの対応物は
  CI＋red-first＋レビュー規約（§8）——機械化可能な形が出るまで現状維持。
- 逆に著名キット側に無いもの: フック迂回の技術ブロック＋コーパス回帰・生成索引の鮮度機械検査・
  red-first の CI 証明・虚偽✅の再実行監査・依存/規約変更の意味論ゲート。

## 3. v2.13 実装（採用2件の要約）
- 検査6 `feat-without-test`（soft・commit-msg）: feat がコードに触れるのにテスト変更なし→警告。
  昇格トリガー: 偽陽性率の観察後、逃げ道（refactor/chore or TEST-EXEMPT）とともに hard 化判定。
- 検査7 `commit-too-large`（soft）: 純変更 400 行超（生成物・lockfile 除外・`COMMIT_SIZE_SOFT_LIMIT`
  で列上書き可）→警告。hard にしない理由記録済み（初回移植・一括リネーム）。

### 主な情報源
Superpowers（github.com/obra/superpowers・builder.io・termdock 解説）／Spec Kit
（github/spec-kit・martinfowler.com の SDD 3-tools 検証・EPAM 事例 via dev.to）／
Kiro（AWS 公式・augmentcode 比較）／BMAD（公式・reenbit/dev.to 比較）／
spec-compare（cameronsjo——13ツール比較リポジトリ）

<!-- PLAN.md — guardrails-kit の全体計画・アーキテクチャ・技術選定理由の正本 -->
# PLAN.md — guardrails-kit 全体計画

## 目的

LLM エージェント（Claude Code / Codex 等）の出力が持つ不確実性を、テスト・pre-commit・CI という
確定実行されるコードで置き換えていくレール一式を提供する。言語非依存の契約
（`.guardrails/GUARDRAILS.md`）と言語固有の具象値（`bindings/catalog.md`）を分離し、
任意のリポジトリへ「置くだけ」で導入できる形で配布する。機械が判定できるのは
「機械検査可能な違反」までという境界を正直に引いた上で、その境界を1規則ずつ広げる
（README.md「何ではないか」）。

## アーキテクチャ

```text
.guardrails/GOALS.md          目標の正本（3＋1レンズ・14条）
  ↓ 判定基準
.guardrails/GUARDRAILS.md     契約の正本（§1〜§13・Phase台帳・脅威モデル §2e）
  ↓ 言語なし実装
scripts/check_*.py            各門の検査器（repo_scan.py が共通走査・YAML解析の基盤）
.claude/hooks/ .codex/hooks/  編集直後・編集/操作直前・ターン終了の即時フック
.pre-commit-config.yaml       コミット時の門（check_*.py をID配線）
.github/workflows/            push・PR時の最終防衛線
  guardrails-ci.yml             全門の再実行＋red-first証明＋commit-msg履歴再検査
  guardrails-trusted.yml        pull_request_target。base側コードのみでPR headを検査
.github/CODEOWNERS             workflow群・検査器・CODEOWNERS自身を人間ownerへ固定
  ↓ 言語固有値を充填
bindings/catalog.md            TS/React・Python・Dart/Flutter・Rust の具象paste-block
  ↓ 機械配置
scripts/install_kit.py         対象リポジトリへ配置（INSTALLED/MERGED/KEPT/CONFLICT・冪等）
  ↓ 進捗の実行検証
.guardrails/BOOTSTRAP.md       導入先のStep 0〜10進捗台帳（✅はcheck_bootstrap.pyが再実行検証）
```

依存方向は上記の一方向のみ（GOALS → GUARDRAILS → 検査器実装 → 具象値 → 配置 → 検証）。
自身の構造契約は `.guardrails/GUARDRAILS.md` §7・`scripts/check_structure.py` が機械強制する。

## 技術選定理由

- **Python + uv**: 全検査器・フックの実行系。v2.23 でbash/jqへの依存を廃し、Windows/PowerShell
  経路も含めて単一ランタイムに統一した（README_SETUP.md v2.23）。
- **pre-commit フレームワーク**: コミット時の門の配線基盤。ローカルフックとCIの
  `guardrails-ci.yml` が**同一定義**を再実行することで、フック未導入環境を最終防衛線でも塞ぐ。
- **GitHub Actions + pull_request_target**: `guardrails-trusted.yml` はbase branchのコードだけを
  実行し、PR headはGit blobとしてのみ読む。required checkがjob名しか識別しない性質を
  `.github/CODEOWNERS` の人間レビュー必須化で補う（Phase 52/53）。
- **Markdown＋機械可読な部分書式（JSON Schemaでなく）**: 契約の正本（GOALS/GUARDRAILS）は人間が
  読み書きする文書のまま、Phase台帳・タスク記法・バインディング刻印だけ固定書式にして
  正規表現で検査する。文書と機械契約を同じファイルに同居させ、二重正本を作らない（G5）。
- **gitタグ＋Release zip（コミットしない）**: 配布物の正本をリポジトリ内に二重化しない
  （木とzipの二重正本はドリフトの温床——README.md「このリポジトリ自体の運用」）。

## 判断の方針（README.md「設計原則」の要約）

- **門 > 心得**: 機械検査できる規律はプロンプトでなく検査器に実装する。書くのは
  機械化できない残余だけ。
- **単一の正**: 同じ情報を2箇所に持たない（AGENTS.mdは二分——複製でなく分割。STRUCTURE.mdは
  生成物のまま追跡し、鮮度検査の前提にする）。
- **fail-closed / fail-open の明記**: 破壊を止める門はfail-closed、利便のための門はfail-open。
  機構ごとにどちらへ倒すかを`.guardrails/GUARDRAILS.md`の当該Phase節へ明記する。
- **完了＝実行結果**: 「わざと違反して落ちるのを見た」だけを完了と定義する。DoDは違反注入込みで
  実測し、Phase節に記録する。自己申告の完了は認めない。
- **不採用も記録する**: 検討して入れなかったもの（Serena・Merge Queue等）を理由つきで
  `surveys/`と`.guardrails/GUARDRAILS.md`「保留」節に残し、再提案ループを塞ぐ。復活条件は
  トリガーとして明文化する。

## 運用

- 版はgitタグを正本とする。zipはコミットしない（配布はReleaseのみ）。現時点では初回タグを
  未作成——`.guardrails-kit-source`マーカーを持つ本リポジトリが原本。
- 変更履歴・是正記録の正本は `README_SETUP.md` の各版セクション（直近はv2.49〜v2.52）。
  追記はチャット口調でなく監査記録として書く。
- 出荷状態は自己検査に意図的な指摘5件を残す（AGENTS.md/CLAUDE.mdがテンプレのため）——
  原本マーカーによりこのリポジトリ自身は3件softへ降格・exit 0（v2.14）。導入先では
  Step 1で解消が強制される。
- `uv run scripts/dev.py gates` が実状態つきの全機能一覧（文書でなくコマンドで見る、が方針）。

## ロードマップ

1. **完了**: Phase 1〜53（Python/uv移植・全門の実装・PR必須契約統一・workflow自己改変防御・
   CODEOWNERS必須レビュー——直近はv2.52 CODEOWNERS分離と外部Actionのコミット固定）。
2. **保留（トリガー未成立——`.guardrails/GUARDRAILS.md`「保留」節が正本、実装しない）**:
   免除・接頭辞の乱用点検指標／効果の評価設計（最初の実採用プロジェクトが発火条件）／
   Chrome DevTools MCP・Context7 MCP・Serena MCPの再評価／Skills化／GitHub Merge Queue／
   UI第二層の回帰固定（visual regression）／PostToolUse秘密マスク。
3. **次のマイルストーン**: 初回gitタグの切り出しとRelease公開（現状は未タグ）。

タスク粒度の設計根拠は `docs/plans/` に置く（feat⇔plan対——`.guardrails/GUARDRAILS.md` §3.4）。
機能単位の判断記録は `surveys/`。

## タスク（機械可読）

書式:
- `- [ ] タイトル` … 未完了。行末に `` `状態タグ` `` が無ければ `backlog` 扱い
- `- [x] タイトル` … 完了。行末にタグが無ければ `done` 扱い
- 状態を明示したい時だけ行末にタグを付ける: `` `next` `` / `` `in_progress` `` /
  `` `blocked` `` / `` `cancelled` ``（`done`/`backlog` はチェック状態で表せるため省略可）
- `unknown` はこの記法では書かない——収集側が行を解釈できなかった場合にのみ付与する
- タスクのidはこのリポジトリ名とタイトルから収集側が導出する（このファイルには書かない）

- [x] PR必須契約の統一（既定ブランチ直接push禁止・1Step=1コミット=1ブランチ=1PR）
- [x] workflow自己改変防御（guardrails-trusted.yml＋check_workflow_integrity.py）
- [x] required check同名job偽装の封鎖（.github/CODEOWNERS＋code owner review必須化）
- [x] 配布元CODEOWNERSと導入先テンプレートの分離・外部ActionのコミットSHA固定
- [ ] 初回gitタグの切り出しとRelease公開 `next`
- [ ] 免除・接頭辞（RED-FIRST-EXEMPT等）の乱用点検指標スクリプト `backlog`
- [ ] 効果の評価設計（hard違反率・soft無視率・免除率・fix再発率の計測） `backlog`

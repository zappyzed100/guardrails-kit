# SURVEY_MCP_ECOSYSTEM.md — MCP・エコシステム・Plugin 連携の調査報告（キット v2.10 時点）

> **位置づけ**: 採否判定のための**調査報告**。実装は含まない（ユーザー指示）。
> 前提: LLM = Claude Code。採用が確定した項目だけが .guardrails/GUARDRAILS.md §10（保留/Phase）へ
> 登録されて本書の役目は終わる——UPDATE_PLAN と同じ建付けで、本書自体は正本にしない（G5）。
> 判定原則はユーザー指示の3点をキットの G に翻訳した「採用ゲート」（§1）:
> ①役割が被るなら既存機構優先（明らかに性能が大きい時のみ逆転） ②常駐トークンの節約
> ③改善の必要がないなら改善しない。

---

## 0. 結論サマリ

**即時に採用すべき新規 MCP・エコシステムは無い。** 現構成（Playwright MCP 1本＋CLI 群＋
kit-native 動詞）は、2026年時点でコミュニティが収斂しつつある推奨形
「**MCP は最小・CLI と Skills で大半を賄う**」に既に一致している。よって本調査の成果物は
「何を入れるか」ではなく「**何を入れない判断をしたか（＋将来入れるトリガー）**」の記録。

- **継続採用 1件**: Playwright MCP（操作レール §12.4 の実体・Web 列のみ・v2.3 から採用済み）
- **不採用 7群**: Serena／GitHub MCP／Supabase・Postgres 系 MCP／filesystem・git 等の
  基本ツール重複系／sequential-thinking／memory 系 MCP／プロンプト集型エコシステム
  （SuperClaude 等）・plugins によるキット代替
- **保留 4件**（トリガー明記——§6）: Chrome DevTools MCP／Context7／Serena（大規模既存
  リポジトリ限定の再評価）／Skills 化（AGENTS.md 常駐の分割）
- **対象外**: 製品都合の SaaS 系 MCP（Sentry 等）・個人ツール（ccusage・mgrep 等——
  Repomix 前例どおり個人利用自由・キット正本に入れない）

---

## 1. 判定の前提 — 採用ゲート3条（Gレンズからの導出）

ユーザー指示「役割が被る場合はエコシステムの方が明らかに性能が大きいときのみ採用」
「トークン消費が激しくなるため不要なものは入れない」「改善の必要がないなら改善するな」を、
キットの語彙で判定可能にする:

- **ゲートM1（重複排除 — G5/G2）**: Claude Code のネイティブツール（Read/Grep/Glob/Bash/
  WebSearch）・汎用 CLI（gh 等）・キットの既存機構（dev.py 動詞・STRUCTURE.md 索引・
  §12 レール）で同じ役割が果たせるなら不採用。逆転条件は「実測で明らかに性能が大きい」
  のみ（伝聞・宣伝文句は根拠にしない——完了=実行結果の思想）。
- **ゲートM2（常駐予算 — G3）**: MCP のツール定義は接続するだけでコンテキストを消費する。
  採用は「常駐する価値があるか」で判定し、スポット用途は**タスク単位の add/remove** に
  格下げする。実測の目安（§2）: GitHub MCP フルセットは定義だけで 42,000〜55,000
  トークン（200K の 21〜28%）。外部の運用推奨はアクティブ MCP < 10・ツール < 80。
- **ゲートM3（契約との整合 — G7/G5/§13）**: ①**書込可能ツールを持つ MCP は、キットの
  門（§2/§3）の外に変更経路を作る**——原則不採用か read-only 限定 ②メモリファイルを
  生やす MCP は §13「中央メモは作らない」・Memory Bank 不採用（v2.4 §5-1）と衝突
  ③外部サービス内容を読み込む MCP はプロンプトインジェクション面が広がる
  （GitHub MCP の toxic agent flow 実証 2025-05 が代表例）。

## 2. 事実確認（2026-07 時点。実装時に再確認すること）

1. **常駐コストの実態**: MCP ツール定義（名前・説明・スキーマ）は接続時にコンテキストへ
   載る。実測報告: GitHub MCP フル 93 ツール ≈ 42,000〜55,000 トークン。gh CLI で同等
   処理をした比較では MCP 約145,000 トークン vs CLI 約4,150 トークン（約35倍差）の報告。
   「MCP 5個で実効コンテキスト 200K→150K」級の目安も流通。
2. **Claude Code 側の緩和機構（公式）**: **Tool Search が既定で有効**——MCP ツールは
   遅延ロードされ、実際に使うツールだけがコンテキストに入る（約85%削減の報告。
   `ENABLE_TOOL_SEARCH` / サーバー毎 `alwaysLoad` で制御）。MCP **出力**は既定上限
   25,000 トークン・10,000 で警告（`MAX_MCP_OUTPUT_TOKENS`）。
   → 常駐コスト問題は v2.3 調査時より緩和されたが、「出力の巨大さ」「誤選択リスク」
   「サーバー数の管理」は残る＝ゲートM2 は依然有効。
3. **Anthropic 公式の方向性**: 「code execution with MCP」（中間結果をコードで処理し
   要約だけ返す——実測 98.7% 削減例）と「手順は Skills へ・CLAUDE.md は薄く」が公式
   ガイダンス。キットの dev.py（CLI 集約）・単一出口ログ・1違反1行は既にこの形。
4. **ブラウザ系**: Playwright MCP（Microsoft・21ツール前後・クロスブラウザ・a11yツリー）と
   Chrome DevTools MCP（Google・26ツール前後・Chrome限定・**performance trace /
   Core Web Vitals / Lighthouse 統合が独自**・トークンはやや軽いとの実測報告）。
   操作系の能力はほぼ同等（両者とも a11y ツリー参照）で、独自価値は性能分析のみ。
   コミュニティの収斂: 「普段は Playwright、性能調査の時だけ DevTools を足す。
   両方常駐はコンテキストの無駄」。
5. **Serena**: LSP 統合の MCP（find_symbol・参照追跡・シンボル編集、対応言語は LSP 次第）。
   実測は割れている——(a) タスクレベルでは「Serena 無しの方がトークン効率が良い」測定
   （laiso 検証）(b) 性能は向上したがトークンは減らず・余計な編集が混入（Zenn 検証）
   (c) 単純照会での削減例（Qiita）。導入時に **`.serena/memories/`（手書き状態ファイル群
   6本）とオンボーディング**が生成される。
6. **Plugins / マーケットプレイス**: `/plugin marketplace add` で commands・agents・
   hooks・MCP を束ねて配布する公式機構が稼働（Chrome DevTools MCP も plugin 配布あり）。
   インストールは**ユーザー環境層**であり、リポジトリのコミットには入らない。
7. **多エージェント制約（v2.10 の前提）**: MCP 設定・Skills・plugins・サブエージェントは
   いずれも Claude Code（または各ツール）固有の層。キットは v2.10 で規約の正本を
   AGENTS.md（ツール非依存）へ二分したばかり——Claude Code 固有層を厚くする採用は
   この方針と逆行するコストを持つ（採用時は CLAUDE.md 側=フック層の隣に置く）。

## 3. 判定表 — MCP

| MCP | 判定 | ゲート | 一行根拠 |
|---|---|---|---|
| **Playwright MCP** | **継続採用**（ts-react-web 列・`.mcp.json`） | M1〜M3 通過 | 操作レール（§12.4）の実体。実UI操作＋コンソール/ネットワーク読取＝観察レールを1本で兼ね、E2E 資産（playwright spec）と地続き。CLI で代替不能な領域（実ブラウザ操作）。クロスブラウザ対応で E2E の将来もカバー |
| **Chrome DevTools MCP** | **保留（タスク単位）** | M1 で被り | 操作系は Playwright と同等（両者 a11y ツリー）＝「明らかに性能が大きい」に該当せず。独自価値は performance trace / Web Vitals / Lighthouse のみ → 常駐させず**性能調査タスクの間だけ** `claude mcp add/remove`。トリガーは §6 |
| **Serena** | **不採用**（§4 で詳説） | M1・M3 抵触 | 索引=STRUCTURE.md＋500行/7ファイル上限＋ネイティブ検索で役割充足。`.serena/memories` は §13「中央メモ禁止」と正面衝突。トークン削減も実測が割れている |
| **GitHub MCP** | **不採用** | M1・M2・M3 抵触 | `gh` CLI が完全代替（実測 約35倍のトークン差・常駐 42〜55k）。公式に対する toxic agent flow 実証（2025-05）＝読込内容経由の注入面。Claude Code は gh を素で使える |
| **Supabase MCP / Postgres MCP** | **不採用** | M1・M3 抵触 | 観察レールは `dev.py db`（読み取り専用・ローカル限定）が既に正本。CLI（supabase / psql）で全用途代替可。書込可能ツールは §2/§3 の門の外の変更経路（G7）で、SQL 注入実証事例もある領域 |
| **filesystem / git / fetch 等の基本系** | **不採用** | M1 抵触 | Claude Code ネイティブツール（Read/Write/Bash/WebFetch）と完全重複。定義分だけ損 |
| **sequential-thinking** | **不採用** | M1 抵触 | 拡張思考（ネイティブ機能）と重複 |
| **memory / knowledge-graph 系** | **不採用（再確認）** | M3 抵触 | §13 中央メモ禁止・Memory Bank 不採用（v2.4 §5-1）と同根。Claude Code の auto memory も既存 |
| **Context7**（最新ライブラリドキュメント） | **保留** | M2 は軽い（2ツール・オンデマンド）／M1 は部分被り | 「LLM が旧作法を書く」問題の**供給側**対策（門側は deprecated-api が既設）。WebSearch で部分代替可だがバージョン特定ドキュメントは Context7 が強い。ただし呼ぶかは心得依存＝キットの思想では弱い機構。トリガーは §6 |
| **Sentry / CircleCI 等 SaaS 系** | **対象外** | — | 製品都合。実例として「入れたが使用頻度が低く、定義だけがコンテキストを圧迫→削除で改善」の報告あり——入れるなら列でなくタスク単位。キット正本には入れない |

## 4. Serena 詳説（名指しの論点のため単独節）

**何であるか**: LSP を MCP 化し、find_symbol・参照追跡・シンボル単位編集を提供する
「エージェントの IDE」。対応言語は LSP 依存（Py/TS/Java/Go/Rust 等）。uv 前提（キットと同じ）。

**不採用の根拠3点**:
1. **役割の被り（M1）**: キットは「リポジトリを検索可能な小ささに保つ」側に賭けた設計
   ——STRUCTURE.md（公開シンボル索引・自動生成・鮮度機械検査）＋500行/7ファイル上限
   （soft）＋レイヤー一方向（hard）で、素の Grep/Glob が届く形を**構造の側**で維持する。
   Serena が解く「巨大ファイル・巨大リポジトリでシンボルが見つからない」問題は、
   キット導入リポジトリでは発生しにくい前提が既に機械強制されている。
2. **契約との衝突（M3）**: 導入時に `.serena/memories/`（project_overview・
   codebase_structure・suggested_commands 等の手書き状態ファイル6本）が生成される。
   これは §13「中央メモは作らない」と、Memory Bank 不採用（「鮮度を機械検査できない
   第二の状態正本」）の判定に**正面から衝突**する。codebase_structure.md は
   STRUCTURE.md と、suggested_commands.md は dev.py 動詞と、それぞれ正本が二重化する
   （G5）。
3. **効果の実測が割れている（完了=実行結果）**: タスクレベル比較で「Serena 無しの方が
   トークン効率が良い」という逆転測定、性能は向上したが余計なファイルまで編集した測定が
   公開されている。「明らかに性能が大きい」の閾値を満たさない。

**それでも効く条件（＝保留トリガーの根拠）**: PROMPT_claude_code_existing で敷く
**大規模・レガシーな既存リポジトリ**（500行制限の清掃 Phase が長期化し、参照追跡が
素の grep で溢れる規模）では、LSP の参照解決が「明らかに大きい」側に入り得る。
その場合も導入条件を付ける: `.serena/memories/` は生成させないか .gitignore（中央メモ
禁止の維持）・編集系ツールは使わずリードオンリー運用（編集はキットの門の内側で）。

## 5. 判定表 — エコシステム（MCP 以外）

| 対象 | 判定 | 一行根拠 |
|---|---|---|
| **Skills（Agent Skills）** | **保留** | オンデマンド読込は G3 に適合し、公式も「手順は Skills へ」を推奨。ただし現状 AGENTS.md は §6 の二分で薄く保たれており、常駐が問題化した実測が無い（改善の必要がないなら改善しない）。かつ Skills は Claude Code 固有層＝v2.10 の多エージェント方針と逆行するコストがある（`.agents/skills` 相互運用は発展途上）。トリガーは §6 |
| **Plugins / マーケットプレイス（キットの配布手段として）** | **不採用** | プラグインは**ユーザー環境層**に入り、リポジトリのコミットに固定されない——「規約はそれが統治するコードと同じコミットに固定」（Agent Rules MCP 不採用と同根・G5/G1）に反する。門（フック・pre-commit・CI）が環境依存になれば CI の再現性も壊れる。配布は install_kit.py（in-repo・冪等・履歴が安全網）が正本のまま |
| **サブエージェント（特化型エージェント集）** | **不採用（再確認）** | v2.4 §5-5 の判定を維持——正本の分裂と可動部増。公式の「重い探索の文脈隔離」用途は個人利用自由・キット正本に入れない |
| **プロンプト集型フレームワーク（SuperClaude 等）** | **不採用** | 反迎合プロンプト不採用（v2.4 §5-3）と同根: 大量の「心得」を常駐させる設計はキットの「機械化できる部分はすべて門」と正反対で、常駐トークンも大きい |
| **hooks 集（cc-discipline 等）** | **不採用（済）** | 必要な発想（ストリークブレーカー等）は v2.4〜v2.9 で門として自作・コーパス回帰済み。外部 hooks はコーパスの回帰保護外 |
| **ccusage・mgrep 等の個人効率化ツール** | **対象外** | Repomix 前例（v2.4 §5-2）——個人利用は自由、キットの正本には入れない |

## 6. 保留（トリガーを明記して寝かせる——採用時は .guardrails/GUARDRAILS.md §10 保留節へ転記）

1. **Chrome DevTools MCP（タスク単位・常駐しない）** — トリガー: Web 列の採用先で
   **性能調査**（Web Vitals・遅延レンダリング・ネットワーク詳細）が実タスクとして発生した時。
   運用形: `claude mcp add chrome-devtools npx chrome-devtools-mcp@latest` → 調査 →
   remove。列の `.mcp.json`（常駐枠）には入れない——操作レールは Playwright のまま。
2. **Context7** — トリガー: `deprecated-api` の検出やレビューで、**同一ライブラリの
   旧作法生成が繰り返し実測**された時（門で止まってはいるが再発が続く＝供給側の欠乏）。
   採用時は列の `.mcp.json` へ2ツールのみ・AGENTS.md §12 手順に「新規ライブラリ API を
   書く前に照会」を1行（心得依存の弱さは残ることを明記）。
3. **Serena（大規模既存リポジトリ限定）** — トリガー: PROMPT_claude_code_existing の
   導入先で、清掃 Phase 中の参照追跡がネイティブ検索で**溢れる実測**（コンテキスト超過・
   誤編集）が出た時。導入条件: memories 無効化 or .gitignore・リードオンリー運用（§4）。
4. **Skills 化（AGENTS.md の手順章の分割）** — トリガー: `/context` の実測で
   AGENTS.md＋フォルダ CLAUDE.md の常駐が問題化した時（目安: 起動時固定分が肥大して
   context rot の兆候）。かつ `.agents/skills` 相互運用の成熟を確認してから
   （多エージェント方針との整合——v2.10 Phase 22 の境界）。

## 7. 「入れる」時の置き場と規律（実装はしない。判断の正本メモ）

- MCP の採用 = **列の `.mcp.json` paste-block**（既に ts 列で運用中。
  `enableAllProjectMcpServers` は settings.json で配線済み——G5/G13 に適合する唯一の経路）。
  タスク単位 MCP（保留1・2）は列に入れず、AGENTS.md §12 の手順に運用メモを1行足すだけ。
- 採用のたびに本書の**採用ゲート3条で判定し、判定ごと catalog か §10 に記録**する
  （不採用も記録——再提案ループ防止は v2.4 からの運用）。
- 予算の実測手段: `/context`（常駐内訳）・`/mcp`（接続一覧）。Tool Search 既定有効でも
  **出力の巨大さ**は別問題（MAX_MCP_OUTPUT_TOKENS 既定 25k）——Playwright の snapshot
  等を丸ごと会話へ入れない運用は §12.3 の観察レールの流儀どおり。

## 8. 推奨アクション

**今回の実装: ゼロ。** 現構成は既に「MCP 最小（Playwright 1本・Web 列のみ）＋ CLI 集約
（dev.py / gh / supabase / psql）＋常時読込は薄い AGENTS.md」という、調査で確認した
推奨形に一致しており、「改善の必要がないなら改善するな」に該当する。

実装する価値がある最小の将来作業（ユーザーが望んだ時のみ・半日未満）:
本書 §6 の保留4件をトリガー付きで .guardrails/GUARDRAILS.md §10 保留節へ転記し、§1 の採用ゲート
3条を catalog の注記（deprecated-api の出典規律と同格の「MCP 採用規律」）として登録する
——判断基準だけを正本化し、機構は増やさない。

---

### 主な情報源（2026-07 時点）
- Claude Code 公式 docs（MCP・Tool Search・出力上限）: code.claude.com/docs/ja/mcp
- GitHub MCP 常駐 42〜55k・toolset 絞込・toxic agent flow: ai-revolution.co.jp（2026-05）
- gh CLI vs MCP 実測 35倍・「Skills + CLI で十分」論: zenn.dev/ashunar0（2026-02）
- MCP 棚卸しで /context 改善の実例: zenn.dev/medley（2025-10）
- Serena 検証（トークン逆転）: blog.lai.so ／（性能↑・余計な編集）: zenn.dev/hcproduce_blog
  ／（memories 生成の実態）: qiita.com/YasuhiroKawano・light11.hatenadiary.com
- Playwright vs Chrome DevTools MCP: mcp.directory（2026-05）・zenn.dev/nexta_・
  stevekinney.com（2026-04）・yatta47.hateblo.jp（2026-03）
- code execution with MCP（98.7%削減）: Anthropic engineering blog／dev.classmethod.jp

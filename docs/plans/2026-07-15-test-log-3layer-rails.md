# 導入計画: テストとログの3層レール——「サンプルは示すが強制しない」の構造化（2026-07-15）

> **実施結果（同日・v2.48・Phase 50）**: Phase A/B とも計画どおり実施済み。実装記録と DoD は
> GUARDRAILS §10 Phase 50・catalog ts-react-web@12 注記が正本。計画からの変更なし。
> 実測2件（被覆検査4ケース・契約テスト2件緑）に加え、`fill_bindings ts-react-web@12` の
> 一時適用で列DoD 15ケース DOD:PASS・未充填状態での SKIP(unfilled) も実測した。

## 0. 入力と検証状態

入力は「テストとログの規律を、機械強制ではなく『規定のやり方が一番楽な道になる』レールとして
設計し直す」という要求。同日、ts-react-web 相当の試作リポジトリ（Vite + React 19 + TS 5.8 +
Vitest 3 + Testing Library / Node 24）で以下を動作確認済み——ただし試作は破棄済みのため、
**採用値の正式な実測は本計画の Phase A で kit 側の scratch にて取り直す**（実測なき充填は
しない——G13）。

試作で確認した事実:

- `logOp(tag, op, detail, {error, elapsedMs})`（catalog ts-react-web@8 の同梱サンプル）は
  そのまま採用可能。出口の**契約テスト**（1行1JSON・必須フィールド・error 時の level 昇格を
  固定するテスト2件）が vitest で緑。
- eslint `no-console: error`＋出口ファイルのみ off で、console 直呼びの違反注入が実際に落ちる。
- 境界（fetch 呼び出し・catch 節）へのログ被覆は、フェイク API と固定時計（Clock 抽象）の
  注入シームがあれば参照実装1機能（コンポーネント＋テスト2件）で無理なく実演できる。

## 1. 方針（拘束条件）

課題は「サンプルの記述は重要だが、強制するとまずい。しかし規定のやり方で実装するレールは
敷きたい」の両立。採る設計は3層で、**hard 検査は増やさない**:

1. **第1層——レール=コードの形で与える**: 規則を文章にせず実装を先に置く（ログ単一出口・
   注入シーム・テストヘルパー）。従う側は「規約を守る」のではなく「用意された部品を使う」
   だけになる。既存の paste-block サンプル（§8.2）がこれ——本計画で追加はするが変質させない
   （貼り替え自由・中身は検査しない、は不変）。
2. **第2層——サンプル=実行される参照実装（本計画の新規概念）**: ドキュメント内のサンプルは
   腐る。CI が常に実行する本物のコード（出口の契約テスト＋雛形1機能）として置けば、緑で
   ある限りコピー元として古くならない。「記述はするが強制はしない」の実体。
3. **第3層——検査=最小限の hard＋理由付き免除の soft（既存・変更なし）**: 重要度の判断は
   機械化できない（§8.4 の結論）。hard は正当な例外が原理的に存在しないもの
   （`log-direct-call` 等）だけ、境界被覆は soft＋`NO-LOG: 理由`、非決定は
   `NONDETERMINISM-EXEMPT: 理由`——逸脱を禁止せず、目に見える形でしか存在できなくする。

## 2. Phase A — catalog ts-react-web@12: ログ境界の充填と契約テスト sample（G13/G9/G4）

@8 が別件として残した `LOG_BOUNDARY_PATTERNS`/`LOG_CALL_PATTERN` の充填を、§8.4 の
被覆検査DoDを伴って実施する。

- 充填値（python-uv 列と同型: 外部HTTP＋エラーハンドラ節）:
  `fetch(` を外部HTTP境界、`catch` 節開始（`catch(`/`catch {`——promise の `.catch(` も
  同じ字面で拾う）をエラーハンドラ境界、`logOp(` を単一出口呼び出しとする。
  **axios / XMLHttpRequest は境界に含めない**——列は fetch 想定であり、`\baxios\b` は
  import 行にも当たる偽陽性源。axios 採用リポジトリが現れた時に版上げで追加する（判断ごと記録）。
- DoD①（被覆検査4ケース・python-uv@6 と同じ方法）: 新値を `check_log_boundary_coverage` に
  直接通す——catch 無ログ→SOFT発火／fetch 無ログ→SOFT発火／窓内 `logOp`→無音／
  `NO-LOG: 理由`→無音。
- DoD②（列コーパス）: `tests/injections/ts-react-web.json` へ `missing-log-coverage`（SOFT）
  ケースを追加。未充填リポジトリで不発を PASS と偽らないよう `"requires":
  ["LOG_BOUNDARY_PATTERNS"]` を付ける（G9）。paste-block 全体を一時適用した状態で
  `check_rule_dod.py ts-react-web` が PASS することを実測する。
- 第2層の具体物: ログ出口の**契約テスト sample**（`src/lib/log.test.ts`——1行1JSON・
  必須フィールド・error 時 level 昇格を固定）を paste-block として追加し、scratch の最小
  vitest プロジェクトで緑を実測する。

## 3. Phase B — GUARDRAILS.md v2.48 / Phase 50: 「実行される参照実装」の明文化（G5/G6/G8）

- **§8.2 追記**: サンプルを貼った採用先は出口の**契約テスト**を同梱し、CI が形式を保証する
  （＝サンプルの正本が「動く実物」になる——G5）。サンプルの中身検査はしない（不変）。
- **§9.7 新設**: 「実行される参照実装（雛形）」。注入シーム（API/Clock——G8）・固定時計・
  testid・境界ログ記録（G6）までを1機能で実演する参照実装＋テストを1つ置き、AGENTS/CLAUDE.md
  からは「新機能はこれを雛形にする」と参照するだけにする。強制しない——hard 検査は増やさない。
- **§11 組み込み**: Step 7 の DoD に「出口の契約テスト同梱」を追加。Step 8b（ランタイム
  レール——E2E ≥1 を既に要求）に「参照実装1機能の配置と CI 対象化」を追加。
- Phase 50 エントリ＋状態表1行＋v2.48。

## 4. 実施順序と規模感

1. 本計画の登録（docs コミット）
2. Phase A（catalog @12＋コーパス1ケース——実測2件を先に取る。feat コミット1つ）
3. Phase B（GUARDRAILS.md のみ。feat コミット1つ）

## 5. この計画が変えないもの

- hard/soft の線引き（§8.4・§9.5）。新しい hard 検査は作らない。
- サンプル実装の「貼り替え自由・中身は検査しない」原則（§8.2）。
- 他列（rust / dart-flutter）の `LOG_BOUNDARY_PATTERNS` 充填は未実施のまま——列ごとに
  採用リポジトリでの実測を伴って別件で行う（G13 の「値ごとに実測状態を持つ」）。
- `missing-log-coverage` の soft 運用（偽陽性率の実測前に hard 昇格しない——GOALS.md の
  非対称閾値②）。

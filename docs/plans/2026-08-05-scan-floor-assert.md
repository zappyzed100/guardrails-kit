# scan-without-floor: 走査型テストの空定義域検出（2026-08-05・提案①）

> **実施結果（同日・v2.66・Phase 67）**: 下記方針のまま実装済み。詳細と DoD は
> `.guardrails/GUARDRAILS.md` §3.3・Phase 67。4同梱列（ts-react-web@14 / python-uv@12 /
> dart-flutter@10 / rust@11）に既定値を定義し、各列の DoD コーパスへ `requires` 付き
> 1ケースを追加、fill 一時適用で4列すべて DOD:PASS・抑制2型の沈黙を実測した。

## 背景

採用先の実測で「**空集合の上の緑**」が最大の教訓として露出した: fixture 走査型の
テストが CWD 解決ミスにより恒久的に 0 ファイル走査＝空虚に合格し続け、走査を直した
瞬間に 16 件の登録漏れが噴出した。採用先の規約文書には「登録≠実行」の罠として
類例が 3 件記録済みだったにもかかわらず再発した——**心得の記録では防げない型**であり、
「門 > 心得」（PLAN.md 判断の方針）に従い検査器へ昇格する。

キットは同族の fail-open を既に 2 規則で守っている:

- `binding-dead-pattern`（hard）: 充填**時**のパターン辞書の拡張子取りこぼし
- `binding-dead-path`（soft）: 充填**後**のファイル移動によるパス型バインディングの定義域空化

ただし両者の対象は**バインディング変数**のみで、**テストコード自身が持つ走査ループ**の
定義域が空になる経路は未被覆（G9: 沈黙の禁止）。今回の事故はまさにこの未被覆領域で
起きた。なお採用先では「実測件数の等値ピン留め」（EXPECTED_TOTALS 型——走査総数を
定数で assert する慣行）が機能していた実績があり、本検査はその**下限方向の一般化**。

## 検討した2案

1. **実行時計測案**: テストランナーをラップして走査件数を実測する。正確だが、キットは
   テスト実行系を持たず（言語なし——G13）、ランナー非依存に作れない。不採用。
2. **静的存在検査案（採用）**: テストファイル内にディレクトリ走査呼び出しがあるのに、
   件数下限の assert（または等値ピン）も免除コメントも同一ファイルに無ければ警告する。
   存在検査のみ・assert の質は検査しない（`NO-LOG:` / `RED-FIRST-EXEMPT:` と同じ境界）。

## 設計

- `repo_scan.py` に 2 変数を追加（いずれも `dict[拡張子, list[正規表現]]`・列充填）:
  - `SCAN_CALL_PATTERNS` — ディレクトリ走査呼び出し。充填が空なら不発（`var:` 型）。
  - `SCAN_FLOOR_PATTERNS` — 件数下限 assert とみなす形。
- 4 同梱列には既定値を定義して出荷する（例。確定は実装時の各列 DoD で）:
  - python-uv: `glob(` / `rglob(` / `iterdir(` / `listdir(` / `walk(` / `scandir(` ⇔
    `assert len(` / `assert .* > 0` / `assertGreater(` / `== 実数` 等
  - ts-react-web: `readdirSync(` / `globby(` / `fast-glob` ⇔ `toBeGreaterThan(` /
    `toHaveLength(` 等
  - rust: `read_dir(` / `glob::glob(` ⇔ `assert!(...len()` / `assert_eq!(...len()` 等
  - dart-flutter: `Directory(...).list` ⇔ `expect(...length` 等
- 判定単位は**ファイル**: `rs.is_test_file()` かつ `CODE_EXTS` のファイルに走査呼び出しが
  あり、同一ファイル内に floor パターンが 1 つも無ければ `SOFT:scan-without-floor`。
  行近傍への厳密化は偽陽性の実測後に判断する（最初から厳しくして「無視される soft」を
  作らない）。
- 免除は `SCAN-FLOOR-EXEMPT: 理由`（存在検査のみ——§9.5 の免除群と同じ扱い）。
- **soft 導入**。走査 API パターンの網羅性・偽陽性率は採用先の実測でしか検証できない
  （`.guardrails/GOALS.md` 非対称閾値②。前例: `feat-without-plan` soft→hard）。
- 登録レシピ（§3.3）に従い、`GATE_REGISTRY` へ `var:SCAN_CALL_PATTERNS` で 1 行、
  違反注入コーパスは**言語別 json**（`tests/injections/python-uv.json` 等）へ各 1 ケース
  （走査呼び出しあり・floor なしのテストファイルを注入）。

## 対象外として明記する範囲

- **「意図した部分集合を走査しているか」は判定できない**。今回噴出した 16 件の登録漏れ
  そのものを塞ぐのは下限ではなく**等値ピン**（EXPECTED_TOTALS 型）だが、等値は仕様変更の
  たびに更新が要り、機械強制すると儀式化する。本検査が強制するのは「空集合で緑になら
  ない」の下限のみとし、等値ピンは採用列のカタログ注記で**推奨**に留める。
- キット自身の検査器（`scripts/check_*.py`）は `is_test_file()` 対象外のため本検査の
  範囲外。検査器側は probe / 実測ピンの慣行（`check_guard_corpus.py` の probe 事前照会
  等）が既にあり、重複させない（G5）。検査器自身への拡張は運用実測後の別提案とする。

## 移植時の安全弁

`var:` 型のため未充填の導入先では不発だが、その不発は `dev.py gates` の台帳に
「充填で有効化」として**見える**（`binding-unstamped` と同じ「見える猶予」の性質）。
4 同梱列は既定値充填で出荷するため、同梱列を採用する限り Step 0 の列選択だけで有効化
される（G13: 移植の定数時間）。

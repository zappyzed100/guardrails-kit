# check_rule_dod.py — 列の違反注入コーパスを再生し、各規則が実際に発火することを機械証明する（契約: .guardrails/GUARDRAILS.md §11 Step 2・Phase 47）
"""check_rule_dod.py — 規則DoD（違反注入→発火→除去→沈黙）の自動再生器。

導入 Step の DoD「わざと違反して落ちるのを見届ける」（§0）を、エージェントの手作業から
コーパス再生へ移す。guard コーパス（§2——門番の回帰）の構造検査版。

使い方: uv run scripts/check_rule_dod.py [列ID]
  列ID 省略時は repo_scan.py の BINDING-SOURCE 刻印から解決する（列ID@版 → 列ID）。
  コーパスは tests/injections/<列ID>.json:
    {"column": "<列ID>", "cases": [{"rule","severity","path","content"}, ...]}

再生手順（2回の check 実行に束ねる——性能予算 §7.7）:
  1. 基準線: check_structure を実行し、注入予定の規則がまだ発火していないことを確認
  2. 全ケースのファイルを書き込み・git add（check は追跡ファイルだけ走査するため）
  3. check_structure を実行し、各ケースの `<severity>:<rule>` が出力に在ることを検証
  4. 全ケースを index・作業ツリーから除去し、check が基準線へ戻ることを確認

出力: 1行1ケース `DOD:PASS/FAIL <rule>`（G4）。
exit: 0 = 全PASS（コーパス無しは表示つき素通し——DoD 道具であり門ではない） /
      1 = FAIL あり / 2 = 内部エラー。
Windows 絶対規則（§7.2）: encoding/newline 明示・shell 非経由。
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import repo_scan as rs  # noqa: E402


def run_check(root: Path) -> tuple[int, str]:
    proc = subprocess.run(
        ["uv", "run", "scripts/check_structure.py"], cwd=str(root),
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def git(root: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(root), *args],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")


def resolve_column(root: Path) -> str | None:
    text = rs.read_text(root, "scripts/repo_scan.py")
    m = rs.BINDING_SOURCE_PATTERN.search(text)
    return m.group(1).split("@", 1)[0] if m else None


def main(argv: list[str]) -> int:
    rs.reconfigure_stdio()
    root = rs.repo_root()
    column = argv[0] if argv else resolve_column(root)
    if not column:
        print("[rule-dod] 対象列なし（BINDING-SOURCE 未刻印・引数なし）——Step 0 の充填後に"
              "再実行する（コーパスの有無は列ごと — 表示つき素通し・門ではない）")
        return 0
    corpus_rel = f"tests/injections/{column}.json"
    corpus_path = root / corpus_rel
    if not corpus_path.is_file():
        print(f"[rule-dod] コーパス未同梱: {corpus_rel}（列にコーパスが無い間は各 Step の"
              "手動違反注入が DoD——カタログの列注記を参照。表示つき素通し）")
        return 0
    data = json.loads(corpus_path.read_text(encoding="utf-8"))
    cases = data.get("cases", [])
    if not cases:
        print(f"INTERNAL コーパスが空: {corpus_rel}")
        return 2

    rc, baseline = run_check(root)
    tokens = {f"{c['severity']}:{c['rule']}" for c in cases}
    already = sorted(t for t in tokens if t in baseline)
    if already:
        print("[rule-dod] 基準線に注入予定の規則が既に発火している——発火の帰属が"
              f"できないため中止: {', '.join(already)}（先に既存違反を解消する）")
        return 1

    written: list[str] = []
    try:
        for c in cases:
            p = root / c["path"]
            p.parent.mkdir(parents=True, exist_ok=True)
            with open(p, "w", encoding="utf-8", newline="\n") as f:
                f.write(c["content"])
            written.append(c["path"])
        add = git(root, "add", "-f", "--", *written)
        if add.returncode != 0:
            print(f"INTERNAL git add 失敗: {add.stderr.strip()}")
            return 2
        _, injected = run_check(root)
        failed = False
        for c in cases:
            token = f"{c['severity']}:{c['rule']}"
            ok = token in injected
            print(f"DOD:{'PASS' if ok else 'FAIL'} {c['rule']} "
                  f"({token} が{'発火' if ok else '不発——パターン充填/区画を確認'})")
            failed |= not ok
    finally:
        if written:
            git(root, "rm", "-q", "--cached", "-f", "--", *written)
            for rel in written:
                try:
                    (root / rel).unlink()
                except OSError as exc:
                    print(f"[rule-dod] 後片付け失敗 {rel}: {exc}（手で削除する）",
                          file=sys.stderr)
                    failed = True

    _, after = run_check(root)
    leftover = sorted(t for t in tokens if t in after)
    if leftover:
        print(f"DOD:FAIL 除去後も発火が残る: {', '.join(leftover)}（後片付け漏れ）")
        failed = True

    n = len(cases)
    if failed:
        print(f"\nrule-dod: FAIL あり（{n} ケース中）——不発の規則は充填値と管理区画を確認")
        return 1
    print(f"\nrule-dod: 全 {n} ケース PASS（注入→発火→除去→沈黙を実測——完了=実行結果 §0）")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except rs.ScanError as exc:
        print(f"rule-dod: 内部エラー: {exc}", file=sys.stderr)
        sys.exit(2)
    except Exception as exc:  # 内部エラーは exit 2（§7.5）
        print(f"INTERNAL {type(exc).__name__}: {exc}")
        sys.exit(2)

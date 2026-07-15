# check_fill_bindings.py — fill_bindings の失敗時無変更・正常充填を回帰検査する
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import install_kit as ik  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
FILL = ROOT / "scripts" / "fill_bindings.py"


def run(root: Path, *columns: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(FILL), *columns], cwd=root,
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    if not {".ruff_cache", ".pytest_cache", ".venv", "node_modules"} <= ik.EXCLUDE_DIRS:
        print("HARD:installer-cache-leak 生成キャッシュの除外が欠落", file=sys.stderr)
        return 1
    if not ik.is_meta(".claude/scheduled_tasks.lock"):
        print("HARD:installer-cache-leak Claudeランタイム状態の除外が欠落", file=sys.stderr)
        return 1
    with tempfile.TemporaryDirectory(prefix="fill-bindings-") as tmp:
        root = Path(tmp)
        (root / "bindings").mkdir()
        (root / "scripts").mkdir()
        target = root / "scripts" / "repo_scan.py"
        yaml_target = root / ".pre-commit-config.yaml"
        original = (
            "# >>> GUARDRAILS BINDING >>>\n"
            "# BINDING-SOURCE: <列ID@版をここに>\n"
            "# <<< GUARDRAILS BINDING <<<\n"
        )
        target.write_text(original, encoding="utf-8", newline="\n")
        yaml_original = (
            "# BINDING-SOURCE: <列ID@版をここに>\n"
            "repos:\n"
            "  # >>> GUARDRAILS BINDING: pre-push >>>\n"
            "  # <<< GUARDRAILS BINDING: pre-push <<<\n"
        )
        yaml_target.write_text(yaml_original, encoding="utf-8", newline="\n")
        (root / "bindings" / "catalog.md").write_text(
            "## 列: valid@1\n\n"
            "<!-- FILL scripts/repo_scan.py -->\n"
            "```python\nX = 1\n```\n"
            "<!-- FILL .pre-commit-config.yaml#pre-push -->\n"
            "```yaml\n  - id: probe\n```\n",
            encoding="utf-8", newline="\n",
        )
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)

        source = root / "kit-source"
        source.mkdir()
        subprocess.run(["git", "init", "-q"], cwd=source, check=True)
        (source / "tracked.txt").write_text("tracked\n", encoding="utf-8")
        (source / "PLAN.md").write_text("private worktree note\n", encoding="utf-8")
        subprocess.run(["git", "add", "tracked.txt"], cwd=source, check=True)
        source_files = {p.relative_to(source).as_posix() for p in ik.kit_source_files(source)}
        if source_files != {"tracked.txt"}:
            print("HARD:installer-untracked-leak Git checkoutの未追跡ファイルを配布対象にした",
                  file=sys.stderr)
            return 1

        bad = run(root, "missing@1", "valid@1")
        if (bad.returncode != 1 or target.read_text(encoding="utf-8") != original
                or yaml_target.read_text(encoding="utf-8") != yaml_original):
            print("HARD:fill-bindings-partial 事前検証失敗後にファイルが変更された", file=sys.stderr)
            return 1

        good = run(root, "valid@1")
        text = target.read_text(encoding="utf-8")
        yaml_text = yaml_target.read_text(encoding="utf-8")
        if (good.returncode != 0 or "X = 1" not in text or "BINDING-SOURCE: valid@1" not in text
                or "id: probe" not in yaml_text or "BINDING-SOURCE: valid@1" not in yaml_text):
            print("HARD:fill-bindings-regression 正常な列を充填・刻印できない", file=sys.stderr)
            return 1
        new_yaml = yaml_original.replace("<列ID@版をここに>", "<新版>")
        spliced = ik.splice_managed(new_yaml, yaml_text)
        if spliced is None or "id: probe" not in spliced or "BINDING-SOURCE: valid@1" not in spliced:
            print("HARD:fill-bindings-upgrade 名前付き管理区画を更新時に保持できない", file=sys.stderr)
            return 1

        owner_src = (
            f"{ik.CODEOWNERS_BEGIN}\n"
            "# managed\n"
            "/.github/workflows/ @GUARDRAILS-HUMAN-REVIEWER\n"
            "/scripts/ @GUARDRAILS-HUMAN-REVIEWER\n"
            "/tests/ @GUARDRAILS-HUMAN-REVIEWER\n"
            f"{ik.CODEOWNERS_END}\n"
        )
        legacy = (
            "# project owners\n"
            "* @app-owner\n"
            "/docs/ @docs-owner\n"
            "/.github/workflows/ @human-owner @security-owner\n"
            "/scripts/ @script-owner\n"
        )
        owners = ik.splice_managed(owner_src, legacy)
        if (owners is None or "* @app-owner" not in owners or "/docs/ @docs-owner" not in owners
                or "/scripts/ @script-owner" not in owners
                or "/tests/ @human-owner @security-owner" not in owners
                or owners.count(ik.CODEOWNERS_BEGIN) != 1):
            print("HARD:codeowners-upgrade 独自規則・複数owner・パス別ownerを保持できない", file=sys.stderr)
            return 1
        owner_src_v2 = owner_src.replace(
            f"{ik.CODEOWNERS_END}\n",
            "/bindings/catalog.md @GUARDRAILS-HUMAN-REVIEWER\n"
            f"{ik.CODEOWNERS_END}\n",
        )
        owners_v2 = ik.splice_managed(owner_src_v2, owners)
        if (owners_v2 is None or owners_v2.count(ik.CODEOWNERS_BEGIN) != 1
                or owners_v2.count("* @app-owner") != 1
                or "/bindings/catalog.md @human-owner @security-owner" not in owners_v2):
            print("HARD:codeowners-upgrade 管理区画の再更新が冪等でない", file=sys.stderr)
            return 1
        broad_after = owners + "* @late-owner\n"
        reordered = ik.splice_managed(owner_src_v2, broad_after)
        if reordered is None or not reordered.rstrip().endswith(ik.CODEOWNERS_END):
            print("HARD:codeowners-order 後勝ちの独自規則がguardrails保護を上書きする", file=sys.stderr)
            return 1
        invalid = legacy.replace("@human-owner @security-owner", ik.CODEOWNER_PLACEHOLDER)
        if ik.splice_managed(owner_src, invalid) is not None:
            print("HARD:codeowners-upgrade placeholder残置を更新で黙認した", file=sys.stderr)
            return 1
    print("[fill-bindings] 失敗時無変更・正常充填 PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())

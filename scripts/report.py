#!/usr/bin/env python3
"""Regenerate the FINDINGS summary table and sync status into candidates.tsv
from the machine-readable results/*.json files.

Usage: scripts/report.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
RESULTS = ROOT / "results"
FINDINGS = ROOT / "FINDINGS.md"
CANDIDATES = ROOT / "seeds" / "candidates.tsv"


def load_results():
    # bootstrap probes live in bootstrap/ and are reported separately, not as
    # languages — exclude them from the language summary.
    bootstrap = {p.name for p in (ROOT / "bootstrap").glob("*") if p.is_dir()}
    out = {}
    for f in sorted(RESULTS.glob("*.json")):
        if f.stem in bootstrap:
            continue
        try:
            out[f.stem] = json.loads(f.read_text())
        except Exception as e:  # noqa
            print(f"warn: bad json {f}: {e}")
    return out


def fmt_bytes(n):
    n = int(n or 0)
    if n <= 0:
        return "—"
    if n < 1024:
        return f"{n} B"
    if n < 1024 * 1024:
        return f"{n/1024:.0f} KB"
    return f"{n/1024/1024:.1f} MB"


def render_table(results):
    rows = ["| name | outcome | build (s) | binary | smoke |",
            "|------|---------|-----------|--------|-------|"]
    for name in sorted(results):
        r = results[name]
        smoke = (r.get("smoke") or "").strip()[:48]
        rows.append(
            f"| {name} | {r.get('outcome','?')} | {r.get('build_seconds','?')} "
            f"| {fmt_bytes(r.get('binary_bytes'))} | {smoke} |"
        )
    return "\n".join(rows)


def update_findings(results):
    table = render_table(results)
    text = FINDINGS.read_text()
    new = re.sub(
        r"<!-- REPORT:BEGIN -->.*<!-- REPORT:END -->",
        f"<!-- REPORT:BEGIN -->\n{table}\n<!-- REPORT:END -->",
        text,
        flags=re.S,
    )
    FINDINGS.write_text(new)
    n_ok = sum(1 for r in results.values() if r.get("outcome") == "ok")
    print(f"FINDINGS updated: {n_ok}/{len(results)} ok")


def update_candidates(results):
    if not CANDIDATES.exists():
        return
    lines = CANDIDATES.read_text().splitlines()
    header = lines[0].split("\t")
    try:
        i_name = header.index("name")
        i_status = header.index("status")
    except ValueError:
        return
    out = [lines[0]]
    for line in lines[1:]:
        if not line.strip():
            out.append(line)
            continue
        cols = line.split("\t")
        name = cols[i_name]
        if name in results and i_status < len(cols):
            cols[i_status] = results[name].get("outcome", cols[i_status])
        out.append("\t".join(cols))
    CANDIDATES.write_text("\n".join(out) + "\n")
    print("candidates.tsv statuses synced")


def main():
    results = load_results()
    update_findings(results)
    update_candidates(results)


if __name__ == "__main__":
    main()

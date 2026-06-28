#!/usr/bin/env python3
"""enrich.py — enrich data/pool_repos.txt with GitHub metadata (via batched
GraphQL) and triage for tiny-language candidates.

Outputs:
  data/pool.tsv      — every resolvable repo with metadata
  data/shortlist.tsv — ranked candidates not already in seeds/candidates.tsv

Requires: gh (authenticated).
"""
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
POOL_IN = DATA / "pool_repos.txt"
POOL_TSV = DATA / "pool.tsv"
SHORTLIST = DATA / "shortlist.tsv"
CANDIDATES = ROOT / "seeds" / "candidates.tsv"

# Languages whose programs tend to be small + portable (good "tiny" implementers).
GOOD_LANGS = {"C", "C++", "Rust", "Go", "Zig", "Assembly", "Nim", "D",
              "OCaml", "Forth", "Pascal", "Lua"}
KEYWORDS = ("interpret", "compiler", " lang", "language", "scheme", "lisp",
            "forth", " vm", "bytecode", "scripting", "embeddable", "tiny",
            "small", "minimal", "esolang", "repl", "wasm", "webassembly")


def gql_batch(chunk):
    """Resolve a chunk of <=50 owner/name pairs in one GraphQL call."""
    parts = []
    valid = []
    for i, repo in enumerate(chunk):
        if repo.count("/") != 1:
            continue
        owner, name = repo.split("/")
        # GraphQL string-escape
        o = owner.replace("\\", "\\\\").replace('"', '\\"')
        n = name.replace("\\", "\\\\").replace('"', '\\"')
        parts.append(
            f'r{i}: repository(owner: "{o}", name: "{n}") {{ '
            f"nameWithOwner diskUsage stargazerCount isArchived isFork "
            f"pushedAt primaryLanguage {{ name }} description }}"
        )
        valid.append(i)
    if not parts:
        return {}
    query = "query {" + " ".join(parts) + "}"
    proc = subprocess.run(
        ["gh", "api", "graphql", "-f", f"query={query}"],
        capture_output=True, text=True,
    )
    if not proc.stdout.strip():
        sys.stderr.write(proc.stderr[:500] + "\n")
        return {}
    try:
        data = json.loads(proc.stdout).get("data") or {}
    except json.JSONDecodeError:
        return {}
    return {k: v for k, v in data.items() if v}


def score(r):
    """Heuristic 'tiny language candidate' score; higher is more promising."""
    s = 0
    disk = r.get("diskUsage") or 0  # KB
    if disk and disk < 1000:
        s += 4
    elif disk and disk < 5000:
        s += 2
    elif disk and disk < 20000:
        s += 1
    lang = (r.get("primaryLanguage") or {}).get("name")
    if lang in GOOD_LANGS:
        s += 2
    text = ((r.get("description") or "") + " " + r.get("nameWithOwner", "")).lower()
    if any(k in text for k in KEYWORDS):
        s += 2
    if r.get("stargazerCount", 0) >= 100:
        s += 1
    if r.get("isArchived"):
        s -= 2
    return s


def existing_names():
    names = set()
    if CANDIDATES.exists():
        for line in CANDIDATES.read_text().splitlines()[1:]:
            cols = line.split("\t")
            if len(cols) >= 2 and "github.com/" in cols[1]:
                names.add(cols[1].split("github.com/")[1].rstrip("/").lower())
    return names


def main():
    repos = [r.strip() for r in POOL_IN.read_text().splitlines() if r.strip()]
    rows = []
    CHUNK = 50
    for start in range(0, len(repos), CHUNK):
        chunk = repos[start:start + CHUNK]
        got = gql_batch(chunk)
        rows.extend(got.values())
        sys.stderr.write(f"\renriched {start + len(chunk)}/{len(repos)} "
                         f"({len(rows)} resolved)")
        sys.stderr.flush()
    sys.stderr.write("\n")

    rows.sort(key=lambda r: (-score(r), -(r.get("stargazerCount") or 0)))

    with POOL_TSV.open("w") as f:
        f.write("repo\tscore\tdisk_kb\tlang\tstars\tarchived\tdescription\n")
        for r in rows:
            f.write("\t".join([
                r.get("nameWithOwner", ""),
                str(score(r)),
                str(r.get("diskUsage") or ""),
                (r.get("primaryLanguage") or {}).get("name") or "",
                str(r.get("stargazerCount") or 0),
                "yes" if r.get("isArchived") else "",
                (r.get("description") or "").replace("\t", " ")[:120],
            ]) + "\n")

    have = existing_names()
    with SHORTLIST.open("w") as f:
        f.write("repo\tscore\tdisk_kb\tlang\tstars\tdescription\n")
        for r in rows:
            name = r.get("nameWithOwner", "").lower()
            if name in have or score(r) < 5 or r.get("isArchived"):
                continue
            f.write("\t".join([
                r.get("nameWithOwner", ""),
                str(score(r)),
                str(r.get("diskUsage") or ""),
                (r.get("primaryLanguage") or {}).get("name") or "",
                str(r.get("stargazerCount") or 0),
                (r.get("description") or "").replace("\t", " ")[:120],
            ]) + "\n")

    print(f"pool.tsv: {len(rows)} repos; "
          f"shortlist.tsv: {sum(1 for _ in SHORTLIST.open()) - 1} candidates")


if __name__ == "__main__":
    main()

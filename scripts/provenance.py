#!/usr/bin/env python3
"""provenance.py — extract the build/bootstrap provenance of each verified
language from its recipe, and inject a table into BOOTSTRAP.md.

For each recipe we record:
  - base libc      (musl via alpine, or glibc via debian)
  - impl language  (from seeds/candidates.tsv)
  - build deps     (apk/apt packages beyond the base toolchain)
  - build system   (make / cmake / cargo / go / rake / configure / cc / tarball)
  - host language  (a pre-existing LANGUAGE toolchain required to build it)
  - arch           (native, or amd64 emulation)

Outputs data/provenance.tsv and refreshes the table in BOOTSTRAP.md.
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
RECIPES = ROOT / "recipes"
RESULTS = ROOT / "results"
CANDIDATES = ROOT / "seeds" / "candidates.tsv"
PROV_TSV = ROOT / "data" / "provenance.tsv"
BOOTSTRAP = ROOT / "BOOTSTRAP.md"

# packages that are just the base C toolchain (assumed present at "tier C")
BASE_TOOLCHAIN = {"build-base", "build-essential", "git", "ca-certificates",
                  "gcc", "g++", "make", "musl-dev", "wget", "curl"}
# package -> a pre-existing language toolchain it implies
HOST_LANG_PKGS = {"go": "Go", "cargo": "Rust", "rustc": "Rust",
                  "ruby": "Ruby", "ruby-rake": "Ruby", "nodejs": "Node",
                  "npm": "Node", "openjdk": "Java", "ghc": "Haskell",
                  "ocaml": "OCaml"}
BUILD_TOOL_PKGS = {"cmake", "bison", "flex", "ninja", "samurai", "meson",
                   "autoconf", "automake", "libtool", "python3", "rake"}


def impl_langs():
    out = {}
    if not CANDIDATES.exists():
        return out
    rows = CANDIDATES.read_text().splitlines()
    hdr = rows[0].split("\t")
    iname, ilang = hdr.index("name"), hdr.index("impl_lang")
    for line in rows[1:]:
        c = line.split("\t")
        if len(c) > max(iname, ilang):
            out[c[iname]] = c[ilang]
    return out


def parse_recipe(name):
    df = RECIPES / name / "Dockerfile"
    text = df.read_text()
    base = "glibc (debian)" if "debian" in text.split("\n")[0:3].__str__() else None
    if base is None:
        base = "glibc (debian)" if re.search(r"FROM\s+debian", text) else "musl (alpine)"

    pkgs = []
    for m in re.finditer(r"(?:apk add|apt-get install)([^\n]*)", text):
        for tok in re.split(r"\s+", m.group(1)):
            tok = tok.strip().rstrip("\\").strip()
            if not tok or tok.startswith("-") or tok in ("add", "install", "&&"):
                continue
            if tok in ("update", "rm"):
                break
            pkgs.append(tok)
    pkgs = [p for p in pkgs if p not in BASE_TOOLCHAIN]

    host = sorted({HOST_LANG_PKGS[p] for p in pkgs if p in HOST_LANG_PKGS})
    tools = sorted({p for p in pkgs if p in BUILD_TOOL_PKGS})
    libs = sorted({p for p in pkgs
                   if p not in HOST_LANG_PKGS and p not in BUILD_TOOL_PKGS})

    # build system
    bs = []
    if re.search(r"\bcmake\b", text): bs.append("cmake")
    if re.search(r"\bcargo build", text): bs.append("cargo")
    if re.search(r"\bgo build", text): bs.append("go")
    if re.search(r"\brake\b", text): bs.append("rake")
    if re.search(r"\./configure", text): bs.append("configure")
    if re.search(r"tar x", text): bs.append("tarball")
    if not bs and re.search(r"\bmake\b", text): bs.append("make")
    if not bs and re.search(r"\bcc |\bgcc ", text): bs.append("cc")

    arch_file = RECIPES / name / "arch"
    arch = arch_file.read_text().strip() if arch_file.exists() else "native"

    return {"base": base, "host": host, "tools": tools, "libs": libs,
            "build": bs, "arch": arch}


def outcome(name):
    p = RESULTS / f"{name}.json"
    if p.exists():
        return json.loads(p.read_text()).get("outcome", "?")
    return "?"


def main():
    langs = impl_langs()
    rows = []
    for d in sorted(RECIPES.iterdir()):
        if not (d / "Dockerfile").exists():
            continue
        name = d.name
        r = parse_recipe(name)
        rows.append({
            "name": name,
            "outcome": outcome(name),
            "impl": langs.get(name, "?"),
            "host_lang": ", ".join(r["host"]) or "—",
            "base": r["base"],
            "build": "+".join(r["build"]) or "?",
            "tools": ", ".join(r["tools"]) or "—",
            "libs": ", ".join(r["libs"]) or "—",
            "arch": r["arch"],
        })

    cols = ["name", "outcome", "impl", "host_lang", "base", "build", "tools", "libs", "arch"]
    with PROV_TSV.open("w") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")

    # markdown table (verified only), sorted: C-bootstrappable first
    ok = [r for r in rows if r["outcome"] == "ok"]
    ok.sort(key=lambda r: (r["host_lang"] != "—", r["host_lang"], r["name"]))
    md = ["| language | impl | needs host lang | libc | build | extra libs |",
          "|----------|------|-----------------|------|-------|------------|"]
    for r in ok:
        md.append(f"| {r['name']} | {r['impl']} | {r['host_lang']} | "
                  f"{'glibc' if 'glibc' in r['base'] else 'musl'} | {r['build']} "
                  f"| {r['libs']} |")
    table = "\n".join(md)

    if BOOTSTRAP.exists():
        text = BOOTSTRAP.read_text()
        text = re.sub(r"<!-- PROV:BEGIN -->.*<!-- PROV:END -->",
                      f"<!-- PROV:BEGIN -->\n{table}\n<!-- PROV:END -->",
                      text, flags=re.S)
        BOOTSTRAP.write_text(text)

    n_chain = sum(1 for r in ok if r["host_lang"] != "—")
    print(f"provenance: {len(ok)} verified; "
          f"{len(ok) - n_chain} C-toolchain-bootstrappable, "
          f"{n_chain} need another language runtime")


if __name__ == "__main__":
    main()

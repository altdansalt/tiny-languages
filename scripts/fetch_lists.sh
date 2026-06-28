#!/usr/bin/env bash
# fetch_lists.sh — mine the source awesome-lists for candidate language repos.
#
# For each list repo named in seeds/lists.md, fetch its README via the GitHub API
# and extract every github.com/<owner>/<repo> link. Dedupe to data/pool_repos.txt.
# Requires: gh (authenticated).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="$ROOT/data"
mkdir -p "$DATA"
POOL="$DATA/pool_repos.txt"

# Source lists to mine (owner/repo). Extend freely.
LISTS=(
  hummanta/awesome-compilers
  BaseMax/AwesomeInterpreter
  ChessMax/awesome-programming-languages
  appcypher/awesome-wasm-langs
  marcobambini/awesome-interpreters
  aalhour/awesome-compilers
  angrykoala/awesome-esolangs
)

tmp="$(mktemp)"
for list in "${LISTS[@]}"; do
  echo "fetch: $list" >&2
  # README (base64) -> text. Some lists keep content in other .md files too;
  # README is where the link tables live for all of the above.
  if ! gh api "repos/$list/readme" --jq '.content' 2>/dev/null | base64 -d >>"$tmp" 2>/dev/null; then
    echo "  (skip: no README or API error)" >&2
  fi
  printf '\n' >>"$tmp"
done

# Extract owner/repo from github.com links, drop the list repos themselves and
# obvious non-project paths (sponsors, topics, search, gists, raw, etc.).
grep -oiE 'github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+' "$tmp" \
  | sed -E 's#.*github\.com/##; s/\.git$//; s#/$##' \
  | tr '[:upper:]' '[:lower:]' \
  | grep -viE '^(sponsors|topics|search|about|features|pricing|collections|orgs|users|marketplace|notifications|settings|apps)/' \
  | grep -vE '^[^/]+/(blob|tree|raw|wiki|issues|pull|releases|actions|stargazers|network)$' \
  | sort -u >"$POOL"

rm -f "$tmp"
echo "wrote $(wc -l < "$POOL") unique repos to $POOL" >&2

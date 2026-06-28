#!/usr/bin/env bash
# build.sh <name> [<name> ...]
# Build and smoke-test a tiny language recipe in a minimal container.
# A recipe is recipes/<name>/Dockerfile that:
#   - builds the language
#   - runs a smoke test as a RUN step (so build FAILS if the smoke fails)
#   - sets CMD to the smoke command (so we can re-run and capture output)
#
# Result: container build exit 0 == known-working. Records results/<name>.json.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RECIPES="$ROOT/recipes"
RESULTS="$ROOT/results"
mkdir -p "$RESULTS"

build_one() {
  local name="$1"
  local dir="$RECIPES/$name"
  local log="$RESULTS/$name.log"
  local json="$RESULTS/$name.json"
  local tag="tinylang/$name"

  if [[ ! -f "$dir/Dockerfile" ]]; then
    echo "SKIP  $name (no recipe)"
    return 2
  fi

  echo "BUILD $name ..."
  local start end status size smoke
  start=$(date +%s)
  container build -t "$tag" -f "$dir/Dockerfile" "$dir" >"$log" 2>&1
  status=$?
  end=$(date +%s)

  size=""
  smoke=""
  local binsize=0
  if [[ $status -eq 0 ]]; then
    # capture smoke output by re-running the recipe's CMD
    smoke=$(container run --rm "$tag" 2>/dev/null | tr '\n' ' ' | head -c 400)
    # image size as reported by the runtime
    size=$(container image ls 2>/dev/null | awk -v t="$tag" '$1==t {print $0}' | head -1)
    # binary size from the recipe's "BINSIZE <bytes> <name>" marker
    binsize=$(grep -oE 'BINSIZE [0-9]+' "$log" | tail -1 | awk '{print $2}')
    [[ -z "$binsize" ]] && binsize=0
  fi

  local outcome="ok"
  [[ $status -ne 0 ]] && outcome="fail"

  cat >"$json" <<EOF
{
  "name": "$name",
  "outcome": "$outcome",
  "build_exit": $status,
  "build_seconds": $((end - start)),
  "binary_bytes": ${binsize:-0},
  "smoke": $(json_str "$smoke"),
  "image_line": $(json_str "$size"),
  "log": "results/$name.log"
}
EOF

  if [[ $status -eq 0 ]]; then
    echo "OK    $name  ($((end - start))s)  smoke: $smoke"
  else
    echo "FAIL  $name  (exit $status) — see $log"
    tail -3 "$log" | sed 's/^/        /'
  fi
  return $status
}

# minimal JSON string escaper
json_str() {
  local s="${1//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//	/ }"
  printf '"%s"' "$s"
}

rc=0
for name in "$@"; do
  build_one "$name" || rc=1
done
exit $rc

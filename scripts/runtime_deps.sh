#!/usr/bin/env bash
# runtime_deps.sh — capture the real runtime library linkage of each verified
# language binary by running `ldd` inside its built image. Writes
# data/runtime_libs.tsv (name <TAB> sorted unique library sonames).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/data/runtime_libs.tsv"
printf 'name\tlibs\n' > "$OUT"

for dir in "$ROOT"/recipes/*/; do
  name="$(basename "$dir")"
  [[ -f "$dir/Dockerfile" ]] || continue
  # only verified images
  grep -q '"outcome": "ok"' "$ROOT/results/$name.json" 2>/dev/null || continue

  # binary basename. Two recipe formats:
  #   A) printf 'BINSIZE %s NAME\n' ...            -> name right after "%s "
  #   B) printf 'BINSIZE %s %s\n' "..." "NAME"     -> name is the last quoted word
  local_line="$(grep -m1 'BINSIZE' "$dir/Dockerfile")"
  bname="$(sed -nE 's/.*BINSIZE %s ([A-Za-z0-9_.+-]+).*/\1/p' <<<"$local_line")"
  if [[ -z "$bname" || "$bname" == "%s" ]]; then
    bname="$(grep -oE '"[A-Za-z0-9_.+-]+"' <<<"$local_line" | tr -d '"' | tail -1)"
  fi
  [[ -z "$bname" ]] && { printf '%s\t%s\n' "$name" "(no binary name)" >> "$OUT"; continue; }

  archrun=""
  [[ -f "$dir/arch" ]] && archrun="--arch $(tr -d '[:space:]' < "$dir/arch")"

  libs="$(container run --rm $archrun "tinylang/$name" sh -c "
      B=\$(command -v $bname 2>/dev/null || find / -type f -name $bname -perm -u+x 2>/dev/null | head -1)
      ldd \"\$B\" 2>/dev/null | grep -oE '(lib[a-zA-Z0-9_.+-]+\.so[0-9.]*|ld-musl-[a-z0-9]+\.so[0-9.]*)' | sort -u | tr '\n' ' '
    " 2>/dev/null)"

  [[ -z "$libs" ]] && libs="(static or none)"
  printf '%s\t%s\n' "$name" "$libs" >> "$OUT"
  echo "$name: $libs"
done

echo "wrote $OUT"

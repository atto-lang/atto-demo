#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

validate_manifest() {
  local manifest="$1"
  local family="$2"
  local allowed_prefix="$3"
  local line=0 count=0

  while IFS=$'\t' read -r name file source_ref mode expected extra; do
    line=$((line + 1))
    [[ -z "${name:-}" || "$name" == \#* ]] && continue

    [[ -z "${extra:-}" ]] || { echo "$manifest:$line: too many columns" >&2; return 1; }
    [[ "$name" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
      { echo "$manifest:$line: invalid contract name" >&2; return 1; }
    [[ "$file" == "$allowed_prefix"* && "$file" != *".."* && "$file" == *.ores ]] ||
      { echo "$manifest:$line: invalid source path" >&2; return 1; }
    [[ "$source_ref" =~ ^[0-9a-f]{40}$ ]] ||
      { echo "$manifest:$line: source_ref must be an exact lowercase commit SHA" >&2; return 1; }
    [[ -n "$expected" ]] || { echo "$manifest:$line: expected output/diagnostic is required" >&2; return 1; }

    case "$family:$mode" in
      keyword:run|keyword:fail|feature:run|feature:fail|feature:import-graph) ;;
      *) echo "$manifest:$line: unsupported mode '$mode'" >&2; return 1 ;;
    esac

    local full="$root/$file"
    [[ -f "$full" && ! -L "$full" ]] ||
      { echo "$manifest:$line: source must be a regular non-symlink file" >&2; return 1; }
    count=$((count + 1))
  done < "$manifest"

  (( count > 0 )) || { echo "$manifest: no contracts declared" >&2; return 1; }
}

validate_manifest "$root/examples/keywords/manifest.tsv" keyword "examples/keywords/"
validate_manifest "$root/examples/features/manifest.tsv" feature "examples/features/"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/oreslang-manifest-check.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

awk -F '\t' '!/^#/ && NF { print $2 }' "$root/examples/keywords/manifest.tsv" | LC_ALL=C sort > "$tmp/keyword-declared"
find "$root/examples/keywords" -maxdepth 1 -type f -name '*.ores' -print |
  sed "s#^$root/##" | LC_ALL=C sort > "$tmp/keyword-actual"
diff -u "$tmp/keyword-declared" "$tmp/keyword-actual"

awk -F '\t' '!/^#/ && NF { print $2 }' "$root/examples/features/manifest.tsv" | LC_ALL=C sort > "$tmp/feature-declared"
find "$root/examples/features" -type f -name '*.ores' ! -path '*/imports/math.ores' -print |
  sed "s#^$root/##" | LC_ALL=C sort > "$tmp/feature-actual"
diff -u "$tmp/feature-declared" "$tmp/feature-actual"

echo "feature/keyword manifests validated"

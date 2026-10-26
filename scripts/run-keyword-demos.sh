#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$repo_root/scripts/validate-manifests.sh"
manifest="$repo_root/examples/keywords/manifest.tsv"

if [[ ! -f "$manifest" ]]; then
  echo "keyword manifest not found: $manifest" >&2
  exit 66
fi

passed=0
failed=0
total=0

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/oreslang-keywords.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

while IFS=$'\t' read -r name file source_ref mode expected; do
  [[ -z "${name:-}" || "$name" == \#* ]] && continue

  total=$((total + 1))
  output_file="$tmp_dir/$name.log"

  echo
  echo "================================================================"
  echo "==> Keyword contract: $name"
  echo "==> Source revision: $source_ref"
  echo "==> Expected mode: $mode"

  set +e
  (
    cd "$repo_root"
    ORESLANG_SOURCE_REF_OVERRIDE="$source_ref" \
      bash scripts/run.sh "$file"
  ) >"$output_file" 2>&1
  status=$?
  set -e

  case "$mode" in
    run)
      if [[ "$status" -eq 0 ]] && grep -Fq -- "$expected" "$output_file"; then
        cat "$output_file"
        echo "CONTRACT PASS: $name"
        passed=$((passed + 1))
      else
        cat "$output_file"
        echo "CONTRACT FAIL: $name (expected success containing: $expected)" >&2
        failed=$((failed + 1))
      fi
      ;;
    fail)
      if [[ "$status" -ne 0 ]] && grep -Fq -- "$expected" "$output_file"; then
        cat "$output_file"
        echo "EXPECTED FAILURE PASS: $name"
        passed=$((passed + 1))
      else
        cat "$output_file"
        if [[ "$status" -eq 0 ]]; then
          echo "CONTRACT FAIL: $name unexpectedly succeeded" >&2
        else
          echo "CONTRACT FAIL: $name failed for the wrong reason; expected: $expected" >&2
        fi
        failed=$((failed + 1))
      fi
      ;;
    *)
      cat "$output_file"
      echo "unknown keyword demo mode '$mode' for $name" >&2
      failed=$((failed + 1))
      ;;
  esac
done < "$manifest"

echo
echo "$passed/$total keyword contracts passed"

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

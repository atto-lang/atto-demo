#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected="120:102:13:15"
output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

bash "$repo_root/scripts/run.sh" "$repo_root/examples/05_nlex_callables.ores" | tee "$output_file"

if ! grep -Fq "$expected" "$output_file"; then
  echo "expected nlex demo output '$expected'" >&2
  exit 1
fi

echo "nlex demo ok: $expected"

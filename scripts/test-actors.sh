#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected="01:singleton:DOWN:failed"
output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

bash "$repo_root/scripts/run.sh" "$repo_root/examples/06_actors_gc.ores" | tee "$output_file"

if ! grep -Fq "$expected" "$output_file"; then
  echo "expected actor demo output '$expected'" >&2
  exit 1
fi

echo "actor demo ok: $expected"

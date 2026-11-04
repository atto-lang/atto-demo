#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: bash scripts/run.sh <example.atto|example.ores>" >&2
  exit 64
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/runtime.sh
source "$repo_root/scripts/lib/runtime.sh"

input="$1"
if [[ "$input" = /* ]]; then
  example="$input"
else
  example="$repo_root/$input"
fi

ores_validate_example "$example"

ores_require_tools
ores_resolve_source
ores_print_source

echo "==> Building Oreslang runtime..."
ores_build_runtime
echo "BUILD PASS"

echo
echo "==> $(basename "$example")"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/oreslang-demo.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

if ores_exec_example "$example" >"$tmp_dir/stdout" 2>"$tmp_dir/stderr"; then
  cat "$tmp_dir/stdout"
  ores_emit_success_stderr "$tmp_dir/stderr"
  echo "PASS"
else
  status=$?
  cat "$tmp_dir/stdout"
  cat "$tmp_dir/stderr" >&2
  echo "FAIL" >&2
  exit "$status"
fi

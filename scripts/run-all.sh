#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/runtime.sh
source "$repo_root/scripts/lib/runtime.sh"

ores_require_tools
ores_resolve_source
ores_print_source

examples=("$repo_root"/examples/*.ores)
if [[ ! -e "${examples[0]}" ]]; then
  echo "no .ores examples found under $repo_root/examples" >&2
  exit 66
fi

echo "==> Building Oreslang runtime..."
ores_build_runtime
echo "BUILD PASS"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/oreslang-demo-all.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

passed=0
failed=0
total="${#examples[@]}"

for example in "${examples[@]}"; do
  name="$(basename "$example")"
  stdout_file="$tmp_dir/$name.stdout"
  stderr_file="$tmp_dir/$name.stderr"

  echo
  echo "==> $name"

  if ores_exec_example "$example" >"$stdout_file" 2>"$stderr_file"; then
    cat "$stdout_file"
    ores_emit_success_stderr "$stderr_file"
    echo "PASS"
    passed=$((passed + 1))
  else
    cat "$stdout_file"
    cat "$stderr_file" >&2
    echo "FAIL" >&2
    failed=$((failed + 1))
  fi
done

echo
echo "$passed/$total demos passed"

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

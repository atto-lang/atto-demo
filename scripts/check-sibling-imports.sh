#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: bash scripts/check-sibling-imports.sh <source-directory>" >&2
  exit 64
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/scripts/lib/runtime.sh"

input="$1"
if [[ "$input" = /* ]]; then
  source_dir="$input"
else
  source_dir="$repo_root/$input"
fi

if [[ ! -d "$source_dir" ]]; then
  echo "source directory not found: $source_dir" >&2
  exit 66
fi

ores_require_tools
ores_resolve_source
ores_print_source

echo "==> Building Oreslang runtime..."
ores_build_runtime
echo "BUILD PASS"

tmp_dir="$(mktemp -d "/tmp/oreslang-import-graph.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

mvn -B -ntp -q   -f "$ORESLANG_RESOLVED_SOURCE_DIR/pom.xml"   -DincludeScope=runtime   -Dmdep.outputFile="$tmp_dir/classpath"   org.apache.maven.plugins:maven-dependency-plugin:3.8.1:build-classpath

classpath="$ORESLANG_RESOLVED_SOURCE_DIR/target/classes:$(cat "$tmp_dir/classpath")"

java --class-path "$classpath"   "$repo_root/scripts/java/ImportGraphCheck.java"   "$source_dir"

#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: bash scripts/compile-feature-dir.sh <directory>" >&2
  exit 64
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/runtime.sh
source "$repo_root/scripts/lib/runtime.sh"

target="$1"
if [[ "$target" = /* ]]; then
  feature_dir="$target"
else
  feature_dir="$repo_root/$target"
fi

if [[ ! -d "$feature_dir" ]]; then
  echo "feature directory not found: $feature_dir" >&2
  exit 66
fi

ores_require_tools
ores_resolve_source
ores_print_source

echo "==> Building Oreslang compiler..."
ores_build_runtime
echo "BUILD PASS"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/oreslang-feature-compile.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

mvn -B -ntp -q   -f "$ORESLANG_RESOLVED_SOURCE_DIR/pom.xml"   -DincludeScope=compile   -Dmdep.outputFile="$tmp_dir/classpath"   dependency:build-classpath

classpath="$ORESLANG_RESOLVED_SOURCE_DIR/target/classes:$(cat "$tmp_dir/classpath")"
mkdir -p "$tmp_dir/classes"

javac --release 21   -cp "$classpath"   -d "$tmp_dir/classes"   "$repo_root/scripts/java/CompileFeatureDir.java"

java -cp "$tmp_dir/classes:$classpath" CompileFeatureDir "$feature_dir"

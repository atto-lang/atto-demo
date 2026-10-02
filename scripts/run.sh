#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: bash scripts/run.sh <example.ores>" >&2
  exit 64
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
input="$1"

if [[ "$input" = /* ]]; then
  example="$input"
else
  example="$repo_root/$input"
fi

if [[ ! -f "$example" ]]; then
  echo "example not found: $example" >&2
  exit 66
fi

source_ref="$(tr -d '[:space:]' < "$repo_root/SOURCE_REF")"
source_dir="${ORESLANG_SOURCE_DIR:-$repo_root/../oreslang-source.java}"

if [[ ! -f "$source_dir/pom.xml" ]]; then
  source_dir="$repo_root/.cache/oreslang-source.java"

  if [[ ! -f "$source_dir/pom.xml" ]]; then
    if ! command -v gh >/dev/null 2>&1; then
      echo "oreslang-source.java is not adjacent to this repo and gh is unavailable" >&2
      echo "set ORESLANG_SOURCE_DIR=/path/to/oreslang-source.java" >&2
      exit 69
    fi

    mkdir -p "$repo_root/.cache"
    gh repo clone ores-truffle-oreslang/oreslang-source.java "$source_dir"
  fi

  git -C "$source_dir" fetch --quiet origin "$source_ref"
  git -C "$source_dir" checkout --quiet --detach "$source_ref"
fi

if ! command -v mvn >/dev/null 2>&1; then
  echo "mvn is required" >&2
  exit 69
fi

echo "==> Oreslang source: $source_dir"
echo "==> Demo: $(basename "$example")"

mvn -B -ntp -q \
  -f "$source_dir/pom.xml" \
  -DskipTests \
  exec:java \
  -Dexec.args="$example"

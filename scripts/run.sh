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

if ! command -v mvn >/dev/null 2>&1; then
  echo "mvn is required" >&2
  exit 69
fi

source_ref="$(tr -d '[:space:]' < "$repo_root/SOURCE_REF")"
managed_source_dir="$repo_root/.cache/oreslang-source.java"
sibling_source_dir="$repo_root/../oreslang-source.java"

prepare_managed_source() {
  local source_dir="$managed_source_dir"

  if [[ ! -f "$source_dir/pom.xml" ]]; then
    mkdir -p "$repo_root/.cache"

    if [[ -d "$sibling_source_dir/.git" ]]; then
      # Seed the managed checkout from the user's local clone. This is fast,
      # works without gh, and never mutates the sibling worktree.
      git clone --quiet --no-checkout "$sibling_source_dir" "$source_dir"
    elif command -v gh >/dev/null 2>&1; then
      gh repo clone ores-truffle-oreslang/oreslang-source.java "$source_dir"
    else
      echo "the pinned Oreslang source checkout is unavailable and gh is not installed" >&2
      echo "either install gh or set ORESLANG_SOURCE_DIR=/path/to/oreslang-source.java" >&2
      exit 69
    fi
  fi

  if ! git -C "$source_dir" cat-file -e "$source_ref^{commit}" 2>/dev/null; then
    git -C "$source_dir" fetch --quiet origin "$source_ref"
  fi

  git -C "$source_dir" checkout --quiet --detach "$source_ref"
  printf '%s\n' "$source_dir"
}

if [[ -n "${ORESLANG_SOURCE_DIR:-}" ]]; then
  source_dir="$ORESLANG_SOURCE_DIR"

  if [[ ! -f "$source_dir/pom.xml" ]]; then
    echo "ORESLANG_SOURCE_DIR does not contain pom.xml: $source_dir" >&2
    exit 66
  fi

  source_mode="explicit local checkout"
elif [[ -f "$sibling_source_dir/pom.xml" ]] \
  && git -C "$sibling_source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  && [[ "$(git -C "$sibling_source_dir" rev-parse HEAD 2>/dev/null || true)" == "$source_ref" ]]; then
  source_dir="$sibling_source_dir"
  source_mode="adjacent pinned checkout"
else
  if [[ -f "$sibling_source_dir/pom.xml" ]]; then
    sibling_head="$(git -C "$sibling_source_dir" rev-parse HEAD 2>/dev/null || printf 'unknown')"
    echo "==> Adjacent oreslang-source.java is not at SOURCE_REF; leaving it untouched."
    echo "    adjacent HEAD: $sibling_head"
    echo "    required HEAD: $source_ref"
  fi

  source_dir="$(prepare_managed_source)"
  source_mode="managed pinned checkout"
fi

echo "==> Oreslang source: $source_dir ($source_mode)"
echo "==> Source revision: $(git -C "$source_dir" rev-parse HEAD 2>/dev/null || printf 'local/unversioned')"
echo "==> Demo: $(basename "$example")"

# exec:java does not implicitly run Maven's compile lifecycle. Compile first so a
# fresh source checkout has dev.oreslang.launcher.OresMain and generated Truffle
# classes available before the launcher is invoked.
mvn -B -ntp -e \
  -f "$source_dir/pom.xml" \
  -DskipTests \
  compile \
  exec:java \
  -Dexec.args="$example"

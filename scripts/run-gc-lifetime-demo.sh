#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORESLANG_SOURCE_REF_OVERRIDE="051d1a19ee66ff51e1097924ebefcbb24c429028" \
  bash "$repo_root/scripts/run.sh" "$repo_root/examples/experimental/15_gc_and_lifetimes.ores"

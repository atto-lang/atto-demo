#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for example in "$repo_root"/examples/*.ores; do
  echo
  echo "----------------------------------------------------------------"
  bash "$repo_root/scripts/run.sh" "$example"
done

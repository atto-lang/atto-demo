#!/usr/bin/env bash
# Real hermetic Git fixture for the existing source policy; no AttoLang guest execution.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp"
git -C "$tmp" config user.name 'Policy fixture'
git -C "$tmp" config user.email 'policy@example.invalid'
mkdir -p "$tmp/src"
printf 'define module Demo as\nend\n' > "$tmp/src/main.ores"
printf 'a%.0s' {1..40} > "$tmp/SOURCE_REF"
printf '\n' >> "$tmp/SOURCE_REF"
git -C "$tmp" add .
git -C "$tmp" commit -qm baseline
head="$(git -C "$tmp" rev-parse HEAD)"
check_ok() {
  SOURCE_POLICY_ROOT="$tmp" EXPECTED_DEMO_SHA="$1" SOURCE_POLICY_MODE="${2:-strict}" \
    bash "$root/ci/source-policy.sh" >/dev/null
}
check_bad() {
  if SOURCE_POLICY_ROOT="$tmp" EXPECTED_DEMO_SHA="$1" SOURCE_POLICY_MODE="${2:-strict}" \
      bash "$root/ci/source-policy.sh" >/dev/null 2>&1; then
    echo 'SOURCE_POLICY_HEAD_BYPASS' >&2
    exit 1
  fi
}
check_ok ''
check_ok "$head"
check_ok "$head" rest-legacy
check_bad 'not-a-commit'
check_bad "$(printf '0%.0s' {1..40})"
check_bad "$head" unsupported-mode
printf 'define module Next as\nend\n' > "$tmp/src/next.ores"
git -C "$tmp" add src/next.ores
git -C "$tmp" commit -qm next
check_bad "$head"
check_ok "$(git -C "$tmp" rev-parse HEAD)"
test -z "$(git -C "$tmp" status --porcelain --untracked-files=all)"
printf 'SOURCE_POLICY_EXACT_HEAD_HOST_PASS cases=9 guest=NOT_EXECUTED\n'

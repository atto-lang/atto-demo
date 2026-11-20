#!/usr/bin/env bash
# Source-free hermetic SOURCE_REF exact-byte checks against the real policy.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp"
git -C "$tmp" config user.name 'Source policy test'
git -C "$tmp" config user.email 'policy@example.invalid'
mkdir -p "$tmp/src"
printf 'define module Example as\nend\n' > "$tmp/src/app.ores"
printf 'a%.0s' {1..40} > "$tmp/SOURCE_REF"
printf '\n' >> "$tmp/SOURCE_REF"
git -C "$tmp" add .
expect_ok() {
  SOURCE_POLICY_ROOT="$tmp" SOURCE_POLICY_MODE="$1" bash "$root/ci/source-policy.sh" > /dev/null
}
expect_bad() {
  if SOURCE_POLICY_ROOT="$tmp" SOURCE_POLICY_MODE="$1" bash "$root/ci/source-policy.sh" >/dev/null 2>&1; then
    echo "source policy unexpectedly admitted a malformed pin" >&2
    exit 1
  fi
}
expect_ok strict
expect_ok rest-legacy
printf 'A%.0s' {1..40} > "$tmp/SOURCE_REF"; printf '\n' >> "$tmp/SOURCE_REF"
expect_bad strict
printf 'a%.0s' {1..40} > "$tmp/SOURCE_REF"
expect_bad strict
printf 'a%.0s' {1..40} > "$tmp/SOURCE_REF"; printf '\r\n' >> "$tmp/SOURCE_REF"
expect_bad strict
printf 'a%.0s' {1..39} > "$tmp/SOURCE_REF"; printf '\n' >> "$tmp/SOURCE_REF"
expect_bad strict
printf 'a%.0s' {1..41} > "$tmp/SOURCE_REF"; printf '\n' >> "$tmp/SOURCE_REF"
expect_bad strict
printf 'a%.0s' {1..40} > "$tmp/SOURCE_REF"; printf '\n\n' >> "$tmp/SOURCE_REF"
expect_bad rest-legacy
printf 'a%.0s' {1..40} > "$tmp/SOURCE_REF"; printf ' \n' >> "$tmp/SOURCE_REF"
expect_bad strict
printf 'a%.0s' {1..40} > "$tmp/SOURCE_REF"; printf '\n' >> "$tmp/SOURCE_REF"
expect_ok strict
echo 'SOURCE_REF_EXACT_BYTES_TESTS_PASS host_only=10 guest=NOT_EXECUTED'

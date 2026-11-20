#!/usr/bin/env bash
# Source-backed host admission checks on disposable Git history; no guest execution.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp"
git -C "$tmp" config user.name 'Source policy regression'
git -C "$tmp" config user.email 'fixture@example.invalid'
mkdir -p "$tmp/src"
printf 'pub fnc main(): int { return 0; }\n' > "$tmp/src/main.ores"
git -C "$tmp" add src/main.ores
git -C "$tmp" commit -qm 'pin source tree'
head="$(git -C "$tmp" rev-parse HEAD)"
run() { SOURCE_POLICY_ROOT="$tmp" EXPECTED_DEMO_SHA="$1" SOURCE_POLICY_MODE="$2" bash "$root/ci/source-policy.sh" 2>&1; }
pass() { local out; out="$(run "$1" "$2")"; [[ "$out" == *'SOURCE_POLICY_STRUCTURAL_PASS'* ]] || { echo "$out" >&2; exit 1; }; }
deny() { local expected="$1" sha="$2" mode="$3" out; if out="$(run "$sha" "$mode")"; then echo "unexpected policy acceptance: $expected" >&2; exit 1; fi; [[ "$out" == *"$expected"* ]] || { echo "unexpected denial: $out" >&2; exit 1; }; }
pass "$head" strict
pass "$head" rest-legacy
deny 'invalid expected head' AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA strict
deny 'invalid expected head' invalid strict
deny 'mismatched head' 0000000000000000000000000000000000000000 strict
deny 'unknown mode' "$head" 'unrecognized-mode'
printf '%040d\n' 0 > "$tmp/SOURCE_REF"
git -C "$tmp" add SOURCE_REF
pass "$head" strict
for raw in $(printf 'without-lf\ncrlf\nupper\ntwo-lines\ntrailing-space\n'); do
  case "$raw" in
    without-lf) printf '%040d' 0 > "$tmp/SOURCE_REF" ;;
    crlf) printf '%040d\r\n' 0 > "$tmp/SOURCE_REF" ;;
    upper) printf '%040X\n' 11259375 > "$tmp/SOURCE_REF" ;;
    two-lines) printf '%040d\n%040d\n' 0 0 > "$tmp/SOURCE_REF" ;;
    trailing-space) printf '%040d \n' 0 > "$tmp/SOURCE_REF" ;;
  esac
  deny 'SOURCE_REF requires exactly 40 lowercase hex characters and newline' "$head" strict
done
printf 'WAVE28_SOURCE_HEAD_REF_PASS source_only=12 guest=NOT_EXECUTED\n'

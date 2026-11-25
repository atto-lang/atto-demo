#!/usr/bin/env bash
# Hermetic host-only adversarial tests for the semantic coverage index.
set -euo pipefail
script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/semantic-coverage.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
mkdir -p "$repo/conformance" "$repo/examples/features/imports" "$repo/examples/features/negatives" "$repo/examples/keywords" "$repo/examples/experimental"
git -C "$repo" init -q
git -C "$repo" config user.name "Coverage test"
git -C "$repo" config user.email "coverage@example.invalid"
printf 'a%.0s' {1..40} > "$repo/SOURCE_REF"; printf '\n' >> "$repo/SOURCE_REF"
for path in examples/00_hello.ores examples/features/01_async.ores examples/features/imports/main.ores examples/features/imports/math.ores examples/features/negatives/bad.ores examples/keywords/01_keyword.ores examples/experimental/01_future.ores; do
  printf 'test fixture\n' > "$repo/$path"
done
pin="$(printf 'b%.0s' {1..40})"
printf 'async\texamples/features/01_async.ores\t%s\trun\tok\nimport\texamples/features/imports/main.ores\t%s\timport-graph\tok\nbad\texamples/features/negatives/bad.ores\t%s\tfail\trejected\n' "$pin" "$pin" "$pin" > "$repo/examples/features/manifest.tsv"
printf 'keyword\texamples/keywords/01_keyword.ores\t%s\trun\tok\n' "$pin" > "$repo/examples/keywords/manifest.tsv"
cat > "$repo/conformance/coverage.tsv" <<'CATALOG'
# id	path	track	mode	capability	evidence
legacy-hello	examples/00_hello.ores	legacy	run	hello	not-attested
feature-async	examples/features/01_async.ores	feature	run	async	not-attested
feature-import-main	examples/features/imports/main.ores	feature	import-graph	import	not-attested
feature-import-helper	examples/features/imports/math.ores	feature	support	import	not-attested
feature-negative-bad	examples/features/negatives/bad.ores	feature	fail	ownership	not-attested
keyword-basic	examples/keywords/01_keyword.ores	keyword	run	keyword	not-attested
experimental-future	examples/experimental/01_future.ores	experimental	excluded	future	not-attested
CATALOG
git -C "$repo" add -A
git -C "$repo" commit -qm "baseline"
run_gate() { SEMANTIC_COVERAGE_ROOT="$repo" bash "$script_root/ci/check-semantic-coverage.sh"; }
bad() {
  if run_gate >"$tmp/out" 2>&1; then
    echo "TEST_FAILURE: accepted invalid case: $1" >&2; exit 1
  fi
  grep -Fq 'COVERAGE_FAILURE:' "$tmp/out" || {
    echo "TEST_FAILURE: unexpected error in $1" >&2
    cat "$tmp/out" >&2; exit 1
  }
  git -C "$repo" reset --hard -q HEAD
  git -C "$repo" clean -fdq
}
run_gate | grep -Fq 'SEMANTIC_COVERAGE_SOURCE_ONLY_PASS' || { echo 'baseline failed' >&2; exit 1; }
printf 'extra\n' > "$repo/examples/unindexed.atto"; git -C "$repo" add -A; bad unindexed-source
grep -vF 'legacy-hello' "$repo/conformance/coverage.tsv" > "$tmp/edit"; cp "$tmp/edit" "$repo/conformance/coverage.tsv"; bad omitted-catalog-row
tail -n 1 "$repo/conformance/coverage.tsv" >> "$repo/conformance/coverage.tsv"; bad duplicate-row
printf 'wrong\texamples/../../escape.ores\tlegacy\trun\twrong\tnot-attested\n' >> "$repo/conformance/coverage.tsv"; bad traversal
sed 's/not-attested/guest-passed/g' "$repo/conformance/coverage.tsv" > "$tmp/edit"; cp "$tmp/edit" "$repo/conformance/coverage.tsv"; bad forged-evidence
sed 's/feature-async.*$/feature-async\texamples\/features\/01_async.ores\tfeature\tfail\tasync\tnot-attested/' "$repo/conformance/coverage.tsv" > "$tmp/edit"; cp "$tmp/edit" "$repo/conformance/coverage.tsv"; bad wrong-mode
sed 's/\trun\tok/\tunknown\tok/' "$repo/examples/keywords/manifest.tsv" > "$tmp/edit"; cp "$tmp/edit" "$repo/examples/keywords/manifest.tsv"; bad invalid-manifest
sed 's/\tbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\t/\tbogus\t/g' "$repo/examples/features/manifest.tsv" > "$tmp/edit"; cp "$tmp/edit" "$repo/examples/features/manifest.tsv"; bad invalid-pin
ln -s 00_hello.ores "$repo/examples/link.ores"; printf 'legacy-link\texamples/link.ores\tlegacy\trun\tlink\tnot-attested\n' >> "$repo/conformance/coverage.tsv"; git -C "$repo" add -A; bad symlink
printf 'duplicate\n' > "$repo/examples/00_hello.atto"; printf 'legacy-hello-atto\texamples/00_hello.atto\tlegacy\trun\thello\tnot-attested\n' >> "$repo/conformance/coverage.tsv"; git -C "$repo" add -A; bad extension-collision
echo 'SEMANTIC_COVERAGE_NEGATIVE_TESTS_PASS scenarios=10'

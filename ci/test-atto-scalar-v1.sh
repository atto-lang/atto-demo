#!/usr/bin/env bash
# Host-only adversarial checks of the canonical six-fixture provenance gate.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/atto-scalar-regressions.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
scratch="$tmp/repo"
mkdir -p "$scratch/ci" "$scratch/conformance/atto-scalar-v1"
cp "$root/ci/check-atto-scalar-v1.sh" "$scratch/ci/"
cp "$root/conformance/atto-scalar-v1/"* "$scratch/conformance/atto-scalar-v1/"
cp -R "$root/examples" "$scratch/"
git -C "$scratch" init -q
git -C "$scratch" config user.name "Atto source-only regression"
git -C "$scratch" config user.email atto-regression@example.invalid
git -C "$scratch" add -A
git -C "$scratch" commit -qm baseline
run() { ATTO_SCALAR_ROOT="$scratch" bash "$root/ci/check-atto-scalar-v1.sh"; }
assert_bad() {
  local label="$1" expected="$2"
  if run >"$tmp/output" 2>&1; then
    echo "REGRESSION_FAIL: accepted $label" >&2; exit 1
  fi
  if ! grep -Fq "ATTO_SCALAR_SOURCE_FAILURE: $expected" "$tmp/output"; then
    echo "REGRESSION_FAIL: wrong rejection for $label" >&2
    cat "$tmp/output" >&2; exit 1
  fi
  git -C "$scratch" reset -q --hard HEAD
  git -C "$scratch" clean -fdq
}
run | grep -Fq 'ATTO_SCALAR_SOURCE_ONLY_PASS cases=6' || { echo 'REGRESSION_FAIL: baseline' >&2; exit 1; }
printf '// mutation\n' >> "$scratch/examples/atto/scalar-v1/positive/canonical-add.atto"
assert_bad changed-source 'upstream blob mismatch'
sed 's/\t42$/\t43/' "$scratch/conformance/atto-scalar-v1/manifest.tsv" >"$tmp/m"; cp "$tmp/m" "$scratch/conformance/atto-scalar-v1/manifest.tsv"
assert_bad forged-oracle 'reviewed manifest bytes diverged'
sed 's/015f8b0f79aafa796a148d2adeff1574e8d6c491/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/' "$scratch/conformance/atto-scalar-v1/manifest.tsv" >"$tmp/m"; cp "$tmp/m" "$scratch/conformance/atto-scalar-v1/manifest.tsv"
assert_bad forged-blob 'reviewed manifest bytes diverged'
tail -n 1 "$scratch/conformance/atto-scalar-v1/manifest.tsv" >> "$scratch/conformance/atto-scalar-v1/manifest.tsv"
assert_bad duplicate-case 'reviewed manifest bytes diverged'
sed '2d' "$scratch/conformance/atto-scalar-v1/manifest.tsv" >"$tmp/m"; cp "$tmp/m" "$scratch/conformance/atto-scalar-v1/manifest.tsv"
assert_bad deleted-case 'reviewed manifest bytes diverged'
printf 'pub fnc main(): int { return 0; }\n' > "$scratch/examples/atto/scalar-v1/positive/extra.atto"
git -C "$scratch" add -A
assert_bad unindexed-tracked 'unindexed tracked source'
rm "$scratch/examples/atto/scalar-v1/positive/canonical-add.atto"
ln -s precedence.atto "$scratch/examples/atto/scalar-v1/positive/canonical-add.atto"
assert_bad symlink 'nonregular/symlinked/missing file'
printf 'bad\n' > "$scratch/conformance/atto-scalar-v1/SOURCE_REF"
assert_bad malformed-pin 'invalid pin length'
printf '%s\n' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa > "$scratch/conformance/atto-scalar-v1/UPSTREAM_CASES_BLOB"
assert_bad upstream-manifest-change 'unexpected upstream manifest blob'
sed 's/negative\/removed-caret/positive\/removed-caret/' "$scratch/conformance/atto-scalar-v1/manifest.tsv" >"$tmp/m"; cp "$tmp/m" "$scratch/conformance/atto-scalar-v1/manifest.tsv"
assert_bad wrong-kind 'reviewed manifest bytes diverged'
echo 'ATTO_SCALAR_SOURCE_NEGATIVE_TESTS_PASS scenarios=10'
echo 'SOURCE_ONLY: no compiler or AttoLang guest executed'

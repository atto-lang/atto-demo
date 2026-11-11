#!/usr/bin/env bash
# Executes REAL Java/GraalVM compiler + guest in an explicit, pinned local source checkout.
# No source cloning/mirroring or GitHub-token fallback. Nonzero guest exit can be a PASS.
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM
export GIT_NO_REPLACE_OBJECTS=1
fail() { printf 'ATTO_JAVA_GUEST_FAILURE: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "required tool unavailable: $1"; }
need git
need mvn
need java
need mktemp
need grep
need wc

repo="$(cd "$(dirname "\${BASH_SOURCE[0]}")/.." && pwd -P)"
[[ "$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)" == "$repo" ]] || fail "demo Git root mismatch"
[[ -z "$(git -C "$repo" status --porcelain --untracked-files=all)" ]] || fail "dirty demo checkout"
if [[ -n "\${ATTO_EXPECTED_DEMO_HEAD:-}" ]]; then
  [[ "$ATTO_EXPECTED_DEMO_HEAD" =~ ^[0-9a-f]{40}$ ]] || fail "invalid expected demo head"
  [[ "$(git -C "$repo" rev-parse HEAD)" == "$ATTO_EXPECTED_DEMO_HEAD" ]] || fail "wrong demo head"
fi
bash "$repo/ci/check-atto-scalar-v1.sh"
bash "$repo/ci/check-semantic-coverage.sh"
manifest="$repo/conformance/atto-scalar-v1/manifest.tsv"
pin="$(cat "$repo/conformance/atto-scalar-v1/SOURCE_REF")"
[[ "$pin" =~ ^[a-f0-9]{40}$ ]] || fail "invalid compiler pin"

[[ -n "\${ATTO_JAVA_SOURCE_DIR:-}" ]] || fail "set ATTO_JAVA_SOURCE_DIR to an already authorized compiler checkout"
[[ -d "$ATTO_JAVA_SOURCE_DIR" && ! -L "$ATTO_JAVA_SOURCE_DIR" ]] || fail "compiler source not a physical directory"
source_dir="$(cd "$ATTO_JAVA_SOURCE_DIR" && pwd -P)" || fail "invalid compiler source path"
[[ -f "$source_dir/pom.xml" && ! -L "$source_dir/pom.xml" ]] || fail "regular compiler pom.xml required"
[[ "$(git -C "$source_dir" rev-parse --show-toplevel 2>/dev/null)" == "$source_dir" ]] || fail "compiler Git checkout root mismatch"

assert_source_identity() {
  local actual dirty ignored
  actual="$(git -C "$source_dir" rev-parse 'HEAD^{commit}' 2>/dev/null)" || fail "compiler HEAD absent"
  [[ "$actual" == "$pin" ]] || fail "compiler mismatch (required $pin, observed $actual)"
  dirty="$(git -C "$source_dir" status --porcelain --untracked-files=all)" || fail "compiler Git status error"
  [[ -z "$dirty" ]] || fail "dirty compiler checkout"
  ignored="$(git -C "$source_dir" ls-files --others --ignored --exclude-standard -- src core stdlib)" || fail "cannot inventory ignored compiler sources"
  [[ -z "$ignored" ]] || fail "ignored/untracked source in compiler checkout"
}
assert_source_identity

tmp="$(mktemp -d "\${TMPDIR:-/tmp}/atto-java-guest.XXXXXXXX")"
trap 'rm -rf "$tmp"' EXIT
demo_head="$(git -C "$repo" rev-parse HEAD)"
demo_tree="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
source_tree="$(git -C "$source_dir" rev-parse 'HEAD^{tree}')"
printf 'ATTO_JAVA_GUEST_START demo=%s demo_tree=%s compiler=%s compiler_tree=%s\n' \
  "$demo_head" "$demo_tree" "$pin" "$source_tree"
java -version 2>&1
mvn -version

# Build from source, never trust a pre-existing target/classes or an exec:java stub.
if ! mvn -B -ntp -q -f "$source_dir/pom.xml" -DskipTests compile >"$tmp/build.out" 2>"$tmp/build.err"; then
  cat "$tmp/build.out" >&2; cat "$tmp/build.err" >&2
  fail "real Java compiler build failed"
fi
assert_source_identity
if ! mvn -B -ntp -q -f "$source_dir/pom.xml" \
    org.apache.maven.plugins:maven-dependency-plugin:3.7.1:build-classpath \
    "-Dmdep.outputFile=$tmp/dependencies" >"$tmp/deps.out" 2>"$tmp/deps.err"; then
  cat "$tmp/deps.out" >&2; cat "$tmp/deps.err" >&2
  fail "dependency classpath creation failed"
fi
assert_source_identity
[[ -s "$tmp/dependencies" ]] || fail "empty runtime dependency classpath"
[[ -f "$source_dir/target/classes/dev/oreslang/launcher/OresMain.class" ]] || fail "real compiled Java launcher absent"
deps="$(cat "$tmp/dependencies")"
[[ "$deps" != *$'\n'* ]] || fail "multiline dependency classpath"
classpath="$source_dir/target/classes:$deps"
if command -v sha256sum >/dev/null 2>&1; then
  launcher_sha="$(sha256sum "$source_dir/target/classes/dev/oreslang/launcher/OresMain.class" | cut -d ' ' -f 1)"
  echo "ATTO_JAVA_LAUNCHER_CLASS_SHA256=$launcher_sha (not standalone executable/AOT digest)"
fi

pass=0
failures=0
while IFS=$'\t' read -r id kind rel blob oracle; do
  [[ -z "$id" || "$id" == \#* ]] && continue
  assert_source_identity
  [[ "$(git -C "$repo" hash-object -- "$rel")" == "$blob" ]] || fail "fixture changed before execution: $id"
  fixture="$repo/$rel"
  check_out="$tmp/$id.check.out"
  check_err="$tmp/$id.check.err"
  set +e
  java -cp "$classpath" dev.oreslang.launcher.OresMain --check "$fixture" >"$check_out" 2>"$check_err"
  check_status=$?
  set -e
  if [[ "$kind" == positive ]]; then
    if [[ "$check_status" -ne 0 ]]; then
      echo "ATTO_JAVA_CASE_FAIL id=$id stage=compiler-check status=$check_status" >&2
      cat "$check_out" >&2; cat "$check_err" >&2
      failures=$((failures + 1))
      continue
    fi
    [[ "$oracle" =~ ^[0-9]+$ ]] || fail "non-numeric positive oracle: $id"
    (( oracle >= 0 && oracle <= 255 )) || fail "oracle cannot be encoded in process exit status: $id"
    set +e
    java -cp "$classpath" dev.oreslang.launcher.OresMain "$fixture" >"$tmp/$id.run.out" 2>"$tmp/$id.run.err"
    actual=$?
    set -e
    if [[ "$actual" -eq "$oracle" ]]; then
      echo "ATTO_JAVA_CASE_PASS id=$id mode=executed-guest expected_exit=$oracle actual_exit=$actual"
      pass=$((pass + 1))
    else
      echo "ATTO_JAVA_CASE_FAIL id=$id mode=executed-guest expected_exit=$oracle actual_exit=$actual" >&2
      cat "$tmp/$id.run.out" >&2; cat "$tmp/$id.run.err" >&2
      failures=$((failures + 1))
    fi
  else
    # No guest execution for deliberately invalid fixtures. A CLI usage error (2)
    # or unrelated missing-file failure must never be accepted as a compiler denial.
    expected_pattern=""
    case "$id" in
      removed-modulo) expected_pattern='[%]' ;;
      removed-caret) expected_pattern='[\^]' ;;
      type-first-reassignment) expected_pattern='immutab|read.?only|cannot[[:space:]]+(reassign|assign)|not mutable|non.mutable|not assignable' ;;
      *) fail "unexpected negative fixture: $id" ;;
    esac
    if [[ "$check_status" -eq 1 ]] && grep -Eiq "$expected_pattern" "$check_err"; then
      echo "ATTO_JAVA_CASE_PASS id=$id mode=compiler-rejected family=$oracle check_exit=$check_status"
      pass=$((pass + 1))
    else
      echo "ATTO_JAVA_CASE_FAIL id=$id mode=compiler-rejected family=$oracle check_exit=$check_status" >&2
      cat "$check_out" >&2; cat "$check_err" >&2
      failures=$((failures + 1))
    fi
  fi
done < "$manifest"
assert_source_identity
printf 'ATTO_JAVA_GUEST_RESULT passed=%s failed=%s total=%s compiler=%s\n' "$pass" "$failures" "$((pass + failures))" "$pin"
[[ "$pass" -eq 6 && "$failures" -eq 0 ]] || fail "required actual Java guest/compiler semantic cases not established"
echo 'ATTO_JAVA_GUEST_PASS backend=java execution=real'

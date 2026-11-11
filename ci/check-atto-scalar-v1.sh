#!/usr/bin/env bash
# Host-only fixture provenance check. This never executes an AttoLang guest.
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM
export GIT_NO_REPLACE_OBJECTS=1
fail() { printf 'ATTO_SCALAR_SOURCE_FAILURE: %s\n' "$*" >&2; exit 2; }
root="${ATTO_SCALAR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
root="$(cd "$root" && pwd -P)" || fail "invalid repo root"
cd "$root"
[[ "$(git rev-parse --show-toplevel 2>/dev/null)" == "$root" ]] || fail "repo root mismatch"
pin="conformance/atto-scalar-v1/SOURCE_REF"
upstream="conformance/atto-scalar-v1/UPSTREAM_CASES_BLOB"
manifest="conformance/atto-scalar-v1/manifest.tsv"
for f in "$pin" "$upstream" "$manifest"; do
  [[ -f "$f" && ! -L "$f" ]] || fail "nonregular or missing contract: $f"
done
for f in "$pin" "$upstream"; do
  [[ "$(wc -c < "$f")" -eq 41 && "$(wc -l < "$f")" -eq 1 ]] || fail "invalid pin length: $f"
  grep -Eq '^[0-9a-f]{40}$' "$f" || fail "invalid pin format: $f"
done
[[ "$(cat "$upstream")" == 43c4d295a237e483f70722bd90ec10d273b73854 ]] || fail "unexpected upstream manifest blob"
[[ "$(cat "$pin")" == 6d8eb70048eafc9a84c5aebe9c1bb06104f16e76 ]] || fail "unexpected Java pin"
declare -A seen=()
positive=0 negative=0 total=0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  [[ "$line" != *$'\r'* ]] || fail "CR in manifest"
  stripped="${line//$'\t'/}"
  (( ${#line} - ${#stripped} == 4 )) || fail "invalid manifest column count"
  IFS=$'\t' read -r id kind path blob oracle <<< "$line"
  [[ "$id" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "bad id"
  [[ "$kind" == positive || "$kind" == negative ]] || fail "bad kind: $id"
  [[ "$path" == "examples/atto/scalar-v1/$kind/$id.atto" ]] || fail "bad file path: $id"
  [[ "$blob" =~ ^[a-f0-9]{40}$ ]] || fail "bad blob: $id"
  [[ -z "${seen[$path]+exists}" ]] || fail "duplicate path: $path"
  [[ -f "$path" && ! -L "$path" ]] || fail "nonregular/symlinked/missing file: $path"
  git ls-files --error-unmatch -- "$path" >/dev/null 2>&1 || fail "not tracked: $path"
  [[ "$(git hash-object -- "$path")" == "$blob" ]] || fail "upstream blob mismatch: $path"
  if [[ "$kind" == positive ]]; then
    [[ "$oracle" =~ ^-?(0|[1-9][0-9]*)$ ]] || fail "invalid numeric oracle: $id"
    positive=$((positive + 1))
  else
    [[ "$oracle" == removed-operator || "$oracle" == immutable-binding ]] || fail "invalid rejection family: $id"
    negative=$((negative + 1))
  fi
  seen["$path"]=1
  total=$((total + 1))
done < "$manifest"
[[ "$total" -eq 6 && "$positive" -eq 3 && "$negative" -eq 3 ]] || fail "expected six-case manifest"
tracked=0
while IFS= read -r -d '' path; do
  [[ "$path" == *.atto ]] || fail "non-atto extension in scalar directory: $path"
  [[ -n "${seen[$path]+exists}" ]] || fail "unindexed tracked source: $path"
  tracked=$((tracked + 1))
done < <(git ls-files -z --cached -- examples/atto/scalar-v1)
[[ "$tracked" -eq "$total" ]] || fail "source inventory mismatch"
printf 'ATTO_SCALAR_SOURCE_ONLY_PASS cases=%d positive=%d negative=%d\n' "$total" "$positive" "$negative"
echo 'NOT_EXECUTED: no compiler/guest/backend invoked'

#!/usr/bin/env bash
# SOURCE-ONLY check: an indexed fixture is NOT proof of compiler or guest execution.
set -euo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM
export GIT_NO_REPLACE_OBJECTS=1
fail() { printf 'COVERAGE_FAILURE: %s\n' "$*" >&2; exit 2; }
root="${SEMANTIC_COVERAGE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
root="$(cd "$root" && pwd -P)" || fail "missing repository root"
cd "$root"
[[ "$(git rev-parse --show-toplevel 2>/dev/null)" == "$root" ]] || fail "repository root mismatch"
index="conformance/coverage.tsv"
[[ -f "$index" && ! -L "$index" ]] || fail "index missing or symlinked"
[[ -f SOURCE_REF && ! -L SOURCE_REF ]] || fail "SOURCE_REF missing or symlinked"
[[ "$(wc -c < SOURCE_REF)" -eq 41 && "$(wc -l < SOURCE_REF)" -eq 1 ]] || fail "SOURCE_REF length"
grep -Eq '^[a-f0-9]{40}$' SOURCE_REF || fail "SOURCE_REF format"
for manifest in examples/features/manifest.tsv examples/keywords/manifest.tsv; do
  [[ -f "$manifest" && ! -L "$manifest" ]] || fail "manifest missing or symlinked: $manifest"
done

declare -A manifest_modes=() indexed=() ids=() stems=()
manifest_count=0
load_manifest() {
  local manifest="$1" line name path pin mode oracle stripped
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" != *$'\r'* ]] || fail "CR in $manifest"
    stripped="${line//$'\t'/}"
    (( ${#line} - ${#stripped} == 4 )) || fail "malformed manifest row: $manifest"
    IFS=$'\t' read -r name path pin mode oracle <<< "$line"
    [[ "$name" =~ ^[a-z0-9-]+$ && "$pin" =~ ^[a-f0-9]{40}$ && -n "$oracle" ]] || fail "invalid manifest fields: $manifest"
    [[ "$mode" == run || "$mode" == fail || "$mode" == import-graph ]] || fail "invalid manifest mode: $name"
    [[ "$path" == examples/features/* || "$path" == examples/keywords/* ]] || fail "invalid manifest path: $path"
    if [[ "$manifest" == examples/features/* ]]; then
      [[ "$path" == examples/features/* ]] || fail "feature manifest scope: $path"
    else
      [[ "$path" == examples/keywords/* ]] || fail "keyword manifest scope: $path"
    fi
    [[ -z "${manifest_modes[$path]+present}" ]] || fail "duplicate manifest path: $path"
    manifest_modes["$path"]="$mode"
    manifest_count=$((manifest_count + 1))
  done < "$manifest"
}
load_manifest examples/features/manifest.tsv
load_manifest examples/keywords/manifest.tsv

count=0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  [[ "$line" != *$'\r'* ]] || fail "CR in catalog"
  stripped="${line//$'\t'/}"
  (( ${#line} - ${#stripped} == 5 )) || fail "expected six tab-delimited columns"
  IFS=$'\t' read -r id path track mode capability evidence <<< "$line"
  [[ "$id" =~ ^[a-z][a-z0-9-]*$ ]] || fail "invalid id: $id"
  [[ "$capability" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "invalid capability: $id"
  [[ "$evidence" == not-attested ]] || fail "guest evidence cannot be asserted by an index: $id"
  [[ "$path" =~ ^examples/[a-zA-Z0-9_./-]+\.(atto|ores)$ ]] || fail "invalid path: $path"
  [[ "$path" != *"/../"* && "$path" != *"/./"* && "$path" != *"//"* ]] || fail "path traversal: $path"
  [[ -f "$path" && ! -L "$path" ]] || fail "missing/non-regular/symlinked fixture: $path"
  git ls-files --error-unmatch -- "$path" >/dev/null 2>&1 || fail "untracked indexed fixture: $path"
  [[ -z "${ids[$id]+present}" && -z "${indexed[$path]+present}" ]] || fail "duplicate id/path: $id"
  ids["$id"]=1
  indexed["$path"]=1
  stem="${path%.*}"
  [[ -z "${stems[$stem]+present}" ]] || fail "ambiguous .atto/.ores stems: $stem"
  stems["$stem"]=1
  case "$track" in
    legacy)
      [[ "$path" == examples/* && "$path" != examples/*/* && "$mode" == run ]] || fail "legacy track/mode: $id"
      ;;
    feature)
      [[ "$path" == examples/features/* ]] || fail "feature scope: $id"
      if [[ "$mode" == support ]]; then
        [[ "$path" == examples/features/imports/math.ores ]] || fail "unapproved support fixture: $id"
      else
        [[ -n "${manifest_modes[$path]+present}" && "${manifest_modes[$path]}" == "$mode" ]] || fail "feature manifest mismatch: $id"
      fi
      ;;
    keyword)
      [[ "$path" == examples/keywords/* && -n "${manifest_modes[$path]+present}" && "${manifest_modes[$path]}" == "$mode" ]] || fail "keyword manifest mismatch: $id"
      ;;
    atto-scalar)
      [[ "$path" == examples/atto/scalar-v1/* ]] || fail "scalar scope: $id"
      case "$path" in
        examples/atto/scalar-v1/positive/*.atto) [[ "$mode" == run ]] || fail "positive scalar mode: $id" ;;
        examples/atto/scalar-v1/negative/*.atto) [[ "$mode" == fail ]] || fail "negative scalar mode: $id" ;;
        *) fail "invalid scalar path: $id" ;;
      esac
      ;;
    experimental)
      [[ "$path" == examples/experimental/* && "$mode" == excluded ]] || fail "experimental quarantine: $id"
      ;;
    *) fail "unknown track: $track" ;;
  esac
  count=$((count + 1))
done < "$index"

tracked=0
while IFS= read -r -d '' path; do
  case "$path" in
    *.ores|*.atto)
      [[ -f "$path" && ! -L "$path" ]] || fail "tracked symlink or missing source: $path"
      [[ -n "${indexed[$path]+present}" ]] || fail "source omitted from catalog: $path"
      tracked=$((tracked + 1))
      ;;
  esac
done < <(git ls-files -z --cached -- examples)
(( count == tracked )) || fail "catalog/index count mismatch"
for path in "${!manifest_modes[@]}"; do
  [[ -n "${indexed[$path]+present}" ]] || fail "manifest fixture absent from catalog: $path"
done
printf 'SEMANTIC_COVERAGE_SOURCE_ONLY_PASS indexed=%s manifests=%s\n' "$count" "$manifest_count"
echo 'NOT_EXECUTED: no AttoLang compiler, native guest or backend was invoked'

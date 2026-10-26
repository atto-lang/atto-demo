#!/usr/bin/env bash

# Shared runner plumbing for oreslang-demo.
# This file is sourced by run.sh and run-all.sh.

ORESLANG_DEMO_ROOT="${ORESLANG_DEMO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ORESLANG_SOURCE_REF="${ORESLANG_SOURCE_REF_OVERRIDE:-$(tr -d '[:space:]' < "$ORESLANG_DEMO_ROOT/SOURCE_REF")}"
if [[ -z "$ORESLANG_SOURCE_REF" ]]; then
  echo "Oreslang source revision cannot be empty" >&2
  return 64 2>/dev/null || exit 64
fi
if [[ ! "$ORESLANG_SOURCE_REF" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Oreslang source revision must be an exact 40-character lowercase commit SHA" >&2
  return 64 2>/dev/null || exit 64
fi
ORESLANG_MANAGED_SOURCE_DIR="$ORESLANG_DEMO_ROOT/.cache/oreslang-source.java"
ORESLANG_SIBLING_SOURCE_DIR="$ORESLANG_DEMO_ROOT/../oreslang-source.java"

ores_require_tools() {
  if ! command -v mvn >/dev/null 2>&1; then
    echo "mvn is required" >&2
    return 69
  fi
}

ores_prepare_managed_source() {
  local source_dir="$ORESLANG_MANAGED_SOURCE_DIR"
  local upstream_url=""

  if [[ ! -f "$source_dir/pom.xml" ]]; then
    mkdir -p "$ORESLANG_DEMO_ROOT/.cache"

    if [[ -d "$ORESLANG_SIBLING_SOURCE_DIR/.git" ]]; then
      git clone --quiet --no-checkout "$ORESLANG_SIBLING_SOURCE_DIR" "$source_dir"
    elif command -v gh >/dev/null 2>&1; then
      gh repo clone ores-truffle-oreslang/oreslang-source.java "$source_dir"
    else
      echo "the pinned Oreslang source checkout is unavailable and gh is not installed" >&2
      echo "either install gh or set ORESLANG_SOURCE_DIR=/path/to/oreslang-source.java" >&2
      return 69
    fi
  fi

  # Older versions of this runner seeded .cache from the sibling checkout, which
  # left origin pointing at a local filesystem path. Repair that origin on every
  # run so future SOURCE_REF bumps can fetch commits the sibling does not have.
  if [[ -d "$ORESLANG_SIBLING_SOURCE_DIR/.git" ]]; then
    upstream_url="$(git -C "$ORESLANG_SIBLING_SOURCE_DIR" remote get-url origin 2>/dev/null || true)"
    if [[ -n "$upstream_url" ]]; then
      git -C "$source_dir" remote set-url origin "$upstream_url"
    fi
  fi

  if ! git -C "$source_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "managed Oreslang source cache is not a Git worktree: $source_dir" >&2
    return 65
  fi

  if ! git -C "$source_dir" cat-file -e "$ORESLANG_SOURCE_REF^{commit}" 2>/dev/null; then
    git -C "$source_dir" fetch --quiet --no-tags origin "$ORESLANG_SOURCE_REF"
  fi

  git -C "$source_dir" checkout --quiet --detach "$ORESLANG_SOURCE_REF"
  if [[ "$(git -C "$source_dir" rev-parse HEAD)" != "$ORESLANG_SOURCE_REF" ]]; then
    echo "managed Oreslang source checkout did not resolve to SOURCE_REF" >&2
    return 65
  fi
  if [[ -n "$(git -C "$source_dir" status --porcelain --untracked-files=all)" ]]; then
    echo "managed Oreslang source checkout is dirty; refusing to execute it" >&2
    return 65
  fi
  ORESLANG_RESOLVED_SOURCE_DIR="$source_dir"
  ORESLANG_SOURCE_MODE="managed pinned checkout"
}

ores_resolve_source() {
  local sibling_head=""

  if [[ -n "${ORESLANG_SOURCE_DIR:-}" ]]; then
    ORESLANG_RESOLVED_SOURCE_DIR="$ORESLANG_SOURCE_DIR"

    if [[ ! -f "$ORESLANG_RESOLVED_SOURCE_DIR/pom.xml" ]]; then
      echo "ORESLANG_SOURCE_DIR does not contain pom.xml: $ORESLANG_RESOLVED_SOURCE_DIR" >&2
      return 66
    fi

    ORESLANG_SOURCE_MODE="explicit local checkout"
  elif [[ -f "$ORESLANG_SIBLING_SOURCE_DIR/pom.xml" ]] \
    && git -C "$ORESLANG_SIBLING_SOURCE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    && [[ "$(git -C "$ORESLANG_SIBLING_SOURCE_DIR" rev-parse HEAD 2>/dev/null || true)" == "$ORESLANG_SOURCE_REF" ]]; then
    ORESLANG_RESOLVED_SOURCE_DIR="$ORESLANG_SIBLING_SOURCE_DIR"
    ORESLANG_SOURCE_MODE="adjacent pinned checkout"
  else
    if [[ -f "$ORESLANG_SIBLING_SOURCE_DIR/pom.xml" ]]; then
      sibling_head="$(git -C "$ORESLANG_SIBLING_SOURCE_DIR" rev-parse HEAD 2>/dev/null || printf 'unknown')"
      echo "==> Adjacent oreslang-source.java is not at SOURCE_REF; leaving it untouched."
      echo "    adjacent HEAD: $sibling_head"
      echo "    required HEAD: $ORESLANG_SOURCE_REF"
    fi

    ores_prepare_managed_source || return $?
  fi

  ORESLANG_RESOLVED_SOURCE_REVISION="$(git -C "$ORESLANG_RESOLVED_SOURCE_DIR" rev-parse HEAD 2>/dev/null || printf 'local/unversioned')"
}

ores_print_source() {
  echo "==> Oreslang source: $ORESLANG_RESOLVED_SOURCE_DIR ($ORESLANG_SOURCE_MODE)"
  echo "==> Source revision: $ORESLANG_RESOLVED_SOURCE_REVISION"
}

ores_build_runtime() {
  mvn -B -ntp -q -e \
    -f "$ORESLANG_RESOLVED_SOURCE_DIR/pom.xml" \
    -DskipTests \
    compile
}

ores_exec_example() {
  local example="$1"

  mvn -B -ntp -q -e \
    -f "$ORESLANG_RESOLVED_SOURCE_DIR/pom.xml" \
    -DskipTests \
    exec:java \
    -Dexec.args="$example"
}

ores_emit_success_stderr() {
  local stderr_file="$1"

  if [[ "${ORESLANG_SHOW_RUNTIME_WARNINGS:-0}" == "1" ]]; then
    cat "$stderr_file" >&2
    return
  fi

  # Graal/Truffle 25.x emits this JDK Unsafe deprecation block once per Maven
  # launcher process on Java 25. Hide only those exact warning lines on
  # successful demos; all other stderr remains visible.
  sed -E \
    -e '/^WARNING: A terminally deprecated method in sun\.misc\.Unsafe has been called$/d' \
    -e '/^WARNING: sun\.misc\.Unsafe::objectFieldOffset has been called by com\.oracle\.truffle\.api\.nodes\.NodeClassImpl\$NodeFieldData /d' \
    -e '/^WARNING: Please consider reporting this to the maintainers of class com\.oracle\.truffle\.api\.nodes\.NodeClassImpl\$NodeFieldData$/d' \
    -e '/^WARNING: sun\.misc\.Unsafe::objectFieldOffset will be removed in a future release$/d' \
    "$stderr_file" >&2
}

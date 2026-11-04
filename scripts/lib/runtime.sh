#!/usr/bin/env bash

# Shared runner plumbing for oreslang-demo.
# This file is sourced by run.sh and run-all.sh.

ORESLANG_DEMO_ROOT="${ORESLANG_DEMO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# A SHA pin is a security input. Never silently strip characters from it.
# Ignore caller-supplied Git indirection when verifying compiler provenance.
unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
unset GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_GRAFT_FILE GIT_REPLACE_REF_BASE
export GIT_NO_REPLACE_OBJECTS=1
if [[ -n "${ORESLANG_SOURCE_REF_OVERRIDE:-}" ]]; then
  ORESLANG_SOURCE_REF="$ORESLANG_SOURCE_REF_OVERRIDE"
else
  ref_file="$ORESLANG_DEMO_ROOT/SOURCE_REF"
  if [[ ! -f "$ref_file" || -L "$ref_file" ]] ||
     [[ "$(wc -c < "$ref_file")" -ne 41 ]] ||
     [[ "$(wc -l < "$ref_file")" -ne 1 ]] ||
     ! grep -Eq '^[0-9a-f]{40}$' "$ref_file"; then
    echo "invalid SOURCE_REF: require one regular 40-hex SHA plus newline" >&2
    return 64 2>/dev/null || exit 64
  fi
  IFS= read -r ORESLANG_SOURCE_REF < "$ref_file" || {
    echo "unable to read SOURCE_REF" >&2
    return 64 2>/dev/null || exit 64
  }
fi
if [[ ! "$ORESLANG_SOURCE_REF" =~ ^[0-9a-f]{40}$ ]]; then
  echo "invalid source revision: require exactly 40 lowercase hex characters" >&2
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

  if ! git -C "$source_dir" cat-file -e "$ORESLANG_SOURCE_REF^{commit}" 2>/dev/null; then
    git -C "$source_dir" fetch --quiet origin "$ORESLANG_SOURCE_REF"
  fi

  git -C "$source_dir" checkout --quiet --detach "$ORESLANG_SOURCE_REF"
  ORESLANG_RESOLVED_SOURCE_DIR="$source_dir"
  ORESLANG_SOURCE_MODE="managed pinned checkout"
}

# All source resolution paths, including explicit ORESLANG_SOURCE_DIR, must
# bind the exact pinned commit and reject dirty tracked/untracked source.
ores_verify_resolved_source() {
  local source_dir="$1" physical_root="" git_root="" actual_head=""
  if [[ ! -d "$source_dir/.git" || -L "$source_dir/.git" ||
        ! -f "$source_dir/pom.xml" || -L "$source_dir/pom.xml" ]]; then
    echo "source provenance failure: expected regular checkout and pom.xml" >&2
    return 65
  fi
  physical_root="$(cd "$source_dir" && pwd -P)" || return 65
  git_root="$(git -C "$physical_root" rev-parse --show-toplevel 2>/dev/null)" || {
    echo "source provenance failure: invalid Git worktree" >&2
    return 65
  }
  if [[ "$git_root" != "$physical_root" ]]; then
    echo "source provenance failure: source directory must be Git root" >&2
    return 65
  fi
  actual_head="$(git -C "$physical_root" rev-parse --verify 'HEAD^{commit}' 2>/dev/null)" || {
    echo "source provenance failure: missing Git HEAD" >&2
    return 65
  }
  if [[ "$actual_head" != "$ORESLANG_SOURCE_REF" ]]; then
    echo "source provenance failure: selected HEAD differs from SOURCE_REF" >&2
    return 65
  fi
  local untracked="" ignored_source=""
  untracked="$(git -C "$physical_root" ls-files --others --exclude-standard --)" || {
    echo "source provenance failure: unreadable Git source inventory" >&2
    return 65
  }
  # Maven compiles source under src and the language libraries; even ignored
  # untracked source files must not be silently added to an exact-HEAD build.
  ignored_source="$(git -C "$physical_root" ls-files --others -- src stdlib core)" || {
    echo "source provenance failure: unreadable source directory inventory" >&2
    return 65
  }
  if ! git -C "$physical_root" diff --no-ext-diff --quiet HEAD -- ||
     ! git -C "$physical_root" diff --no-ext-diff --cached --quiet HEAD -- ||
     [[ -n "$untracked" || -n "$ignored_source" ]]; then
    echo "source provenance failure: dirty source checkout" >&2
    return 65
  fi
  ORESLANG_RESOLVED_SOURCE_DIR="$physical_root"
  ORESLANG_RESOLVED_SOURCE_REVISION="$actual_head"
  echo "ATTO_DEMO_CLEAN_HEAD_MATCH=$actual_head"
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

  ores_verify_resolved_source "$ORESLANG_RESOLVED_SOURCE_DIR" || return $?
}

ores_print_source() {
  echo "==> Oreslang source: $ORESLANG_RESOLVED_SOURCE_DIR ($ORESLANG_SOURCE_MODE)"
  echo "==> Source revision: $ORESLANG_RESOLVED_SOURCE_REVISION"
}

ores_build_runtime() {
  # Reduce check/build TOCTOU: validate immediately before invoking Maven.
  ores_verify_resolved_source "$ORESLANG_RESOLVED_SOURCE_DIR" >/dev/null || return $?
  mvn -B -ntp -q -e \
    -f "$ORESLANG_RESOLVED_SOURCE_DIR/pom.xml" \
    -DskipTests \
    compile
}

ores_validate_example() {
  local example="$1"

  if [[ -L "$example" || ! -f "$example" ]]; then
    echo "refusing non-regular or symlinked example: $example" >&2
    return 66
  fi
  if [[ "$example" != *.ores && "$example" != *.atto ]]; then
    echo "refusing non-.atto/.ores example: $example" >&2
    return 65
  fi
}

ores_exec_example() {
  local example="$1"
  ores_validate_example "$example" || return $?
  ores_verify_resolved_source "$ORESLANG_RESOLVED_SOURCE_DIR" >/dev/null || return $?

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

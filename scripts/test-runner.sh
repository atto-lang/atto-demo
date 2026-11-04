#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/oreslang-runner-test.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

demo="$tmp_root/oreslang-demo"
source_repo="$tmp_root/oreslang-source.java"
bin_dir="$tmp_root/bin"
mvn_log="$tmp_root/mvn.log"

mkdir -p "$demo/scripts/lib" "$demo/examples" "$bin_dir"
cp "$repo_root/scripts/run.sh" "$demo/scripts/run.sh"
cp "$repo_root/scripts/run-all.sh" "$demo/scripts/run-all.sh"
cp "$repo_root/scripts/lib/runtime.sh" "$demo/scripts/lib/runtime.sh"

mkdir -p "$source_repo"
git -C "$source_repo" init -q
git -C "$source_repo" config user.email "runner-test@example.invalid"
git -C "$source_repo" config user.name "Runner Test"

printf '<project/>\n' > "$source_repo/pom.xml"
git -C "$source_repo" add pom.xml
git -C "$source_repo" commit -qm "first"
pinned_ref="$(git -C "$source_repo" rev-parse HEAD)"

printf 'newer local worktree\n' > "$source_repo/local.txt"
git -C "$source_repo" add local.txt
git -C "$source_repo" commit -qm "second"
sibling_head="$(git -C "$source_repo" rev-parse HEAD)"

printf 'experimental keyword revision\n' > "$source_repo/experimental.txt"
git -C "$source_repo" add experimental.txt
git -C "$source_repo" commit -qm "experimental"
override_ref="$(git -C "$source_repo" rev-parse HEAD)"
git -C "$source_repo" branch keyword-contract "$override_ref"
git -C "$source_repo" checkout --quiet --detach "$sibling_head"

printf '%s\n' "$pinned_ref" > "$demo/SOURCE_REF"
printf 'demo one\n' > "$demo/examples/00_one.ores"
printf 'demo two\n' > "$demo/examples/01_two.ores"

cat > "$bin_dir/mvn" <<'MVN'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MVN_LOG"

for arg in "$@"; do
  case "$arg" in
    -Dexec.args=*)
      example="${arg#-Dexec.args=}"
      printf 'output:%s\n' "$(basename "$example")"
      ;;
  esac
done
if [[ "${MUTATE_SOURCE_ON_COMPILE:-0}" == 1 && "${*: -1}" == compile ]]; then
  printf '<!-- unexpected compiler source change -->\n' >> "$SOURCE_REPO_TO_MUTATE/pom.xml"
fi
MVN
chmod +x "$bin_dir/mvn"

output="$(
  cd "$demo"
  PATH="$bin_dir:$PATH" MVN_LOG="$mvn_log" bash scripts/run-all.sh
)"

if [[ "$(git -C "$source_repo" rev-parse HEAD)" != "$sibling_head" ]]; then
  echo "runner mutated the sibling source checkout" >&2
  exit 1
fi

if [[ "$(git -C "$demo/.cache/oreslang-source.java" rev-parse HEAD)" != "$pinned_ref" ]]; then
  echo "managed checkout is not pinned to SOURCE_REF" >&2
  exit 1
fi

if [[ "$(grep -c ' compile$' "$mvn_log")" -ne 1 ]]; then
  echo "expected exactly one Maven compile invocation" >&2
  cat "$mvn_log" >&2
  exit 1
fi

if [[ "$(grep -c ' exec:java ' "$mvn_log")" -ne 2 ]]; then
  echo "expected one exec:java invocation per demo" >&2
  cat "$mvn_log" >&2
  exit 1
fi

case "$output" in
  *"BUILD PASS"*"output:00_one.ores"*"PASS"*"output:01_two.ores"*"PASS"*"2/2 demos passed"*)
    ;;
  *)
    echo "unexpected run-all output:" >&2
    printf '%s\n' "$output" >&2
    exit 1
    ;;
esac

override_output="$(
  cd "$demo"
  PATH="$bin_dir:$PATH" MVN_LOG="$mvn_log" \
    ORESLANG_SOURCE_REF_OVERRIDE="$override_ref" \
    bash scripts/run.sh examples/00_one.ores
)"

if [[ "$(git -C "$source_repo" rev-parse HEAD)" != "$sibling_head" ]]; then
  echo "source-ref override mutated the sibling checkout" >&2
  exit 1
fi

if [[ "$(git -C "$demo/.cache/oreslang-source.java" rev-parse HEAD)" != "$override_ref" ]]; then
  echo "managed checkout did not honor ORESLANG_SOURCE_REF_OVERRIDE" >&2
  exit 1
fi

case "$override_output" in
  *"Source revision: $override_ref"*"output:00_one.ores"*"PASS"*)
    ;;
  *)
    echo "unexpected source-ref override output:" >&2
    printf '%s\n' "$override_output" >&2
    exit 1
    ;;
esac

ln -s "$demo/examples/00_one.ores" "$demo/examples/02_link.ores"
if (
  cd "$demo"
  PATH="$bin_dir:$PATH" MVN_LOG="$mvn_log" bash scripts/run.sh examples/02_link.ores
) >/dev/null 2>&1; then
  echo "runner accepted a symlinked example" >&2
  exit 1
fi
rm "$demo/examples/02_link.ores"

printf 'not oreslang\n' > "$demo/examples/not-oreslang.txt"
if (
  cd "$demo"
  PATH="$bin_dir:$PATH" MVN_LOG="$mvn_log" bash scripts/run.sh examples/not-oreslang.txt
) >/dev/null 2>&1; then
  echo "runner accepted a non-.ores example" >&2
  exit 1
fi

# Canonical AttoLang inputs must travel through the same pinned runner path.
# This fake-Maven test proves argument transport only, not compiler acceptance.
printf 'canonical AttoLang example\n' > "$demo/examples/new.atto"
atto_output="$(
  cd "$demo"
  PATH="$bin_dir:$PATH" MVN_LOG="$mvn_log" bash scripts/run.sh examples/new.atto
)"
case "$atto_output" in
  *"output:new.atto"*"PASS"*) ;;
  *) echo "runner failed .atto argument transport" >&2; exit 1 ;;
esac
ln -s "$demo/examples/new.atto" "$demo/examples/link.atto"
if (
  cd "$demo"
  PATH="$bin_dir:$PATH" MVN_LOG="$mvn_log" bash scripts/run.sh examples/link.atto
) >/dev/null 2>&1; then
  echo "runner accepted symlinked .atto example" >&2
  exit 1
fi
rm "$demo/examples/link.atto"

# run-all must discover both migration suffixes and fail closed on a
# conflicting basename rather than compiling whichever happens to sort first.
all_with_atto="$(
  cd "$demo"
  PATH="$bin_dir:$PATH" MVN_LOG="$mvn_log" bash scripts/run-all.sh
)"
case "$all_with_atto" in
  *"output:new.atto"*"3/3 demos passed"*) ;;
  *) echo "run-all failed to enumerate canonical .atto example" >&2; exit 1 ;;
esac
printf 'legacy collision\n' > "$demo/examples/new.ores"
if (
  cd "$demo"
  PATH="$bin_dir:$PATH" MVN_LOG="$mvn_log" bash scripts/run-all.sh
) >/dev/null 2>&1; then
  echo "run-all accepted conflicting .atto and .ores stems" >&2
  exit 1
fi
rm "$demo/examples/new.ores"

# This harness uses a fake Maven executable only to test runner admission.
# A matching printed HEAD is not sufficient evidence of compiled guest behavior.
expect_source_rejection() {
  local scenario="$1" diagnostic="$2"
  shift 2
  local before result
  before="$(wc -l < "$mvn_log")"
  if result="$(
    cd "$demo"
    PATH="$bin_dir:$PATH" MVN_LOG="$mvn_log" "$@" 2>&1
  )"; then
    echo "runner source-policy false acceptance: $scenario" >&2
    exit 1
  fi
  if [[ "$result" != *"$diagnostic"* ]]; then
    echo "runner rejected $scenario for wrong reason; expected $diagnostic" >&2
    printf '%s\n' "$result" >&2
    exit 1
  fi
  if [[ "$(wc -l < "$mvn_log")" != "$before" ]]; then
    echo "runner invoked Maven before rejecting source: $scenario" >&2
    exit 1
  fi
  echo "SOURCE_REJECTION_VERIFIED=$scenario"
}

# A caller-specified source directory must not bypass the exact SHA pin.
expect_source_rejection explicit-wrong-head 'selected HEAD differs from SOURCE_REF' \
  env ORESLANG_SOURCE_DIR="$source_repo" bash scripts/run.sh examples/00_one.ores
expect_source_rejection malformed-override 'invalid source revision' \
  env ORESLANG_SOURCE_REF_OVERRIDE='--version' bash scripts/run.sh examples/00_one.ores
expect_source_rejection short-override 'invalid source revision' \
  env ORESLANG_SOURCE_REF_OVERRIDE=abcd bash scripts/run.sh examples/00_one.ores

# Valid explicit checkout remains supported when it is exact-head and clean.
valid_explicit="$(
  cd "$demo"
  PATH="$bin_dir:$PATH" MVN_LOG="$mvn_log" \
    ORESLANG_SOURCE_DIR="$demo/.cache/oreslang-source.java" \
    bash scripts/run.sh examples/00_one.ores
)"
case "$valid_explicit" in
  *"ATTO_DEMO_PINNED_SOURCE_VERIFIED=$pinned_ref"*"output:00_one.ores"*"PASS"*) ;;
  *) echo "runner broke legitimate exact-head explicit checkout" >&2; exit 1 ;;
esac

# Neither tracked modifications nor new files may be laundered through the
# explicit-directory path. Both must reject *before* fake Maven is invoked.
cache="$demo/.cache/oreslang-source.java"
printf '<!-- altered -->\n' >> "$cache/pom.xml"
expect_source_rejection explicit-dirty-tracked 'dirty source checkout' \
  env ORESLANG_SOURCE_DIR="$cache" bash scripts/run.sh examples/00_one.ores
git -C "$cache" checkout -- pom.xml
printf 'untracked source\n' > "$cache/rogue.atto"
expect_source_rejection explicit-dirty-untracked 'dirty source checkout' \
  env ORESLANG_SOURCE_DIR="$cache" bash scripts/run.sh examples/00_one.ores
rm "$cache/rogue.atto"

# SOURCE_REF itself must be a regular one-line file, not a symlink or a
# whitespace-normalized value that transforms arbitrary input into a SHA.
printf '%s  \n' "$pinned_ref" > "$demo/SOURCE_REF"
expect_source_rejection padded-ref 'invalid SOURCE_REF' \
  bash scripts/run.sh examples/00_one.ores
printf '%s\n' "$pinned_ref" > "$demo/SOURCE_REF"
mv "$demo/SOURCE_REF" "$demo/SOURCE_REF.pinned"
ln -s SOURCE_REF.pinned "$demo/SOURCE_REF"
expect_source_rejection symlink-ref 'invalid SOURCE_REF' \
  bash scripts/run.sh examples/00_one.ores
rm "$demo/SOURCE_REF"
mv "$demo/SOURCE_REF.pinned" "$demo/SOURCE_REF"

# A matching adjacent HEAD but modified compiler file must not satisfy pin.
git -C "$source_repo" checkout --quiet --detach "$pinned_ref"
printf '<!-- sibling dirty -->\n' >> "$source_repo/pom.xml"
expect_source_rejection adjacent-dirty-tracked 'dirty source checkout' \
  bash scripts/run.sh examples/00_one.ores
git -C "$source_repo" checkout -- pom.xml
git -C "$source_repo" checkout --quiet --detach "$sibling_head"

# A Git-ignored generated Atto source under src/ still affects a compiler
# input path. Ordinary 'git status' misses it, but the source inventory must not.
mkdir -p "$cache/src"
printf 'src/ignored.atto\n' >> "$cache/.git/info/exclude"
printf 'ignored guest source\n' > "$cache/src/ignored.atto"
expect_source_rejection explicit-ignored-source 'dirty source checkout' \
  env ORESLANG_SOURCE_DIR="$cache" bash scripts/run.sh examples/00_one.ores
rm -f "$cache/src/ignored.atto"
rmdir "$cache/src"
: > "$cache/.git/info/exclude"

# Mutations between Maven compile and exec must be caught by a *second*
# identity validation, not only by the initial command's SOURCE_REF check.
before_recheck="$(wc -l < "$mvn_log")"
if late_result="$(
  cd "$demo"
  PATH="$bin_dir:$PATH" MVN_LOG="$mvn_log" \
    MUTATE_SOURCE_ON_COMPILE=1 SOURCE_REPO_TO_MUTATE="$cache" \
    ORESLANG_SOURCE_DIR="$cache" \
    bash scripts/run.sh examples/00_one.ores 2>&1
)"; then
  echo "runner executed after source was modified between build and exec" >&2
  exit 1
fi
if [[ "$late_result" != *'dirty source checkout'* ]] ||
   [[ "$(wc -l < "$mvn_log")" -ne $(( before_recheck + 1 )) ]]; then
  echo "runner failed late mutation admission check or invoked guest Maven" >&2
  printf '%s\n' "$late_result" >&2
  exit 1
fi
git -C "$cache" checkout -- pom.xml
echo "SOURCE_REJECTION_VERIFIED=postcompile-mutation"

echo "runner self-test passed"

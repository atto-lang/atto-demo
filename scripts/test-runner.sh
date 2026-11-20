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

echo "runner self-test passed"

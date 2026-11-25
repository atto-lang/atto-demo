#!/usr/bin/env bash
# Real source-policy.sh exercised only on a disposable Git repository.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp"
git -C "$tmp" config user.name 'Host policy fixture'
git -C "$tmp" config user.email 'policy@example.invalid'
mkdir -p "$tmp/src"
printf 'define module App as\nend\n' > "$tmp/src/app.ores"
git -C "$tmp" add src/app.ores
check_ok() {
  SOURCE_POLICY_ROOT="$tmp" SOURCE_POLICY_MODE="$1" bash "$root/ci/source-policy.sh" > /dev/null
}
check_bad() {
  local diagnostic="$1" mode="$2" output
  if output="$(SOURCE_POLICY_ROOT="$tmp" SOURCE_POLICY_MODE="$mode" bash "$root/ci/source-policy.sh" 2>&1)"; then
    echo "unexpected source-policy acceptance: $diagnostic" >&2
    exit 1
  fi
  [[ "$output" == *"$diagnostic"* ]] || { echo "missing denial: $diagnostic; got: $output" >&2; exit 1; }
}
check_ok strict
ln -s src/app.ores "$tmp/alias.ores"
git -C "$tmp" add alias.ores
check_bad 'symlinked source: alias.ores' strict
check_bad 'symlinked source: alias.ores' rest-legacy
git -C "$tmp" rm -fq alias.ores
check_ok strict
printf '#!/usr/bin/env python3\nprint(1)\n' > "$tmp/src/task.ores"
git -C "$tmp" add src/task.ores
check_bad 'Python interpreter shebang: src/task.ores' strict
printf '#!/usr/bin/env pypy3\nprint(1)\n' > "$tmp/src/task.ores"
check_bad 'Python interpreter shebang: src/task.ores' strict
printf '#!/usr/bin/env bash\necho okay\n' > "$tmp/src/task.ores"
check_ok strict
check_ok rest-legacy
printf 'SOURCE_POLICY_SYMLINK_SHEBANG_PASS host_only=7 guest=NOT_EXECUTED\n'

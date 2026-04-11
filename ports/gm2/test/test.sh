#!/usr/bin/env bash
#
# Integration test suite for the gm2 port of m2assem.
#
# For each fixture listed in CASES, the runner:
#   1. copies the .asm source into a fresh scratch directory under tmp/
#   2. invokes the built m2assem on it
#   3. compares the generated .OBJ byte-for-byte against test/golden/<name>.OBJ
#   4. compares the generated .LST after normalising the three fields
#      that vary legitimately between runs:
#        - page header date/time ("Version 1.0  11/ 4/2026  10:18:41")
#        - "Assembly Time: <elapsed>"
#        - "Assembly Rate: <rate>"
#      The golden .LST stores those slots as <DATETIME> / <ELAPSED> /
#      <RATE> placeholders.
#
# Each fixture is either a copy of the historical src/demo/<name>.asm
# (for sample.asm) or lives under test/fixtures/<name>.asm (new test
# cases the port adds on top of the historical reference).
#
# Usage:
#   ./test.sh          — assumes the build is already done
#   BUILD=1 ./test.sh  — runs ../build.sh first, then tests
#
# Exit status:
#   0 — all checks passed
#   1 — a check failed (diff printed to stderr)
#   2 — setup failure (missing binary, missing fixture, etc.)

set -euo pipefail

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT_DIR="$(cd "$TEST_DIR/.." && pwd)"
SRC_DIR="$PORT_DIR/src"
BUILD_DIR="$PORT_DIR/build"
BIN="$BUILD_DIR/m2assem"
GOLDEN_DIR="$TEST_DIR/golden"
FIXTURE_DIR="$TEST_DIR/fixtures"
WORK_DIR="$TEST_DIR/tmp"

# List of test cases.  Each entry is "<name>:<path-to-.asm>".  The name
# is the stem used for m2assem's output files and for the golden
# filenames; the path is where the .asm source lives.
CASES=(
  "sample:$SRC_DIR/demo/sample.asm"
  "bubble:$FIXTURE_DIR/bubble.asm"
  "math:$FIXTURE_DIR/math.asm"
  "branches:$FIXTURE_DIR/branches.asm"
  "dbcc:$FIXTURE_DIR/dbcc.asm"
  "shifts:$FIXTURE_DIR/shifts.asm"
  "setcc:$FIXTURE_DIR/setcc.asm"
  "arith:$FIXTURE_DIR/arith.asm"
  "bits:$FIXTURE_DIR/bits.asm"
  "system:$FIXTURE_DIR/system.asm"
  "pseudo:$FIXTURE_DIR/pseudo.asm"
  "call:$FIXTURE_DIR/call.asm"
  "modes:$FIXTURE_DIR/modes.asm"
)

fail() { printf '%s\n' "$*" >&2; exit 1; }

# If gm2 isn't already on PATH, add the default install prefix used by
# the project's build instructions so BUILD=1 works in a fresh shell.
if ! command -v gm2 >/dev/null 2>&1; then
  if [[ -x /usr/local/gcc-m2/bin/gm2 ]]; then
    export PATH="/usr/local/gcc-m2/bin:$PATH"
  fi
fi

if [[ "${BUILD:-}" == "1" ]]; then
  (cd "$PORT_DIR" && ./build.sh) >/dev/null
fi

[[ -x "$BIN" ]]        || fail "m2assem binary not found at $BIN — run ./build.sh first (or pass BUILD=1)"
[[ -d "$GOLDEN_DIR" ]] || fail "golden dir not found: $GOLDEN_DIR"

normalise_lst() {
  sed -e 's|Version 1\.0 .*$|Version 1.0 <DATETIME>|' \
      -e 's|^Assembly Time: .*$|Assembly Time: <ELAPSED>|' \
      -e 's|^Assembly Rate: .*$|Assembly Rate: <RATE>|' \
      "$1"
}

run_case() {
  local name="$1"
  local asm="$2"
  local case_dir="$WORK_DIR/$name"

  [[ -f "$asm" ]]                  || { printf '  FAIL  %s: fixture missing: %s\n' "$name" "$asm" >&2; return 1; }
  [[ -f "$GOLDEN_DIR/$name.OBJ" ]] || { printf '  FAIL  %s: missing golden %s.OBJ\n' "$name" "$name" >&2; return 1; }
  [[ -f "$GOLDEN_DIR/$name.LST" ]] || { printf '  FAIL  %s: missing golden %s.LST\n' "$name" "$name" >&2; return 1; }

  mkdir -p "$case_dir"
  cp "$asm" "$case_dir/$name.asm"
  (cd "$case_dir" && "$BIN" "$name") > "$case_dir/stdout.log" 2>&1

  if ! grep -q "There were 0 exception(s)" "$case_dir/stdout.log"; then
    printf '  FAIL  %s: m2assem reported exceptions:\n' "$name" >&2
    sed 's/^/    /' "$case_dir/stdout.log" >&2
    return 1
  fi

  local rc=0

  if cmp -s "$case_dir/$name.OBJ" "$GOLDEN_DIR/$name.OBJ"; then
    printf '  OK    %s.OBJ byte-identical to golden\n' "$name"
  else
    printf '  FAIL  %s.OBJ differs from golden:\n' "$name" >&2
    diff "$GOLDEN_DIR/$name.OBJ" "$case_dir/$name.OBJ" | sed 's/^/    /' >&2 || true
    rc=1
  fi

  normalise_lst "$case_dir/$name.LST" > "$case_dir/$name.LST.normalised"
  if cmp -s "$case_dir/$name.LST.normalised" "$GOLDEN_DIR/$name.LST"; then
    printf '  OK    %s.LST matches golden (after normalising date/time/rate)\n' "$name"
  else
    printf '  FAIL  %s.LST differs from golden:\n' "$name" >&2
    diff "$GOLDEN_DIR/$name.LST" "$case_dir/$name.LST.normalised" | sed 's/^/    /' >&2 || true
    rc=1
  fi

  return $rc
}

# Fresh scratch dir every run so we don't confuse ourselves with stale
# artefacts, and so the test is idempotent.
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

printf 'Running integration tests against %s\n\n' "$BIN"

pass=0
fail_count=0
for entry in "${CASES[@]}"; do
  name="${entry%%:*}"
  asm="${entry#*:}"
  if run_case "$name" "$asm"; then
    pass=$((pass + 1))
  else
    fail_count=$((fail_count + 1))
  fi
done

printf '\n%d passed, %d failed\n' "$pass" "$fail_count"
[[ $fail_count -eq 0 ]] || exit 1

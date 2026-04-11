#!/usr/bin/env bash
#
# Integration test for the gm2 port of m2assem.
#
# Runs the built m2assem against ports/gm2/src/demo/sample.asm and
# compares the generated sample.OBJ / sample.LST against known-good
# golden files under test/golden/.
#
# The OBJ file is compared byte-for-byte — its content is deterministic.
# The LST file is normalised first to strip the three fields that vary
# legitimately between runs:
#
#   - page header date/time ("Version 1.0  11/ 4/2026  10:18:41")
#   - "Assembly Time: <elapsed>"
#   - "Assembly Rate: <rate>"
#
# The golden LST has placeholders (<DATETIME> / <ELAPSED> / <RATE>) in
# the same spots, so a simple diff after normalisation tells us whether
# the deterministic parts of the listing are byte-identical to the
# reference.
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
FIXTURE="$SRC_DIR/demo/sample.asm"
WORK_DIR="$TEST_DIR/tmp"

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

[[ -x "$BIN" ]]            || fail "m2assem binary not found at $BIN — run ./build.sh first (or pass BUILD=1)"
[[ -f "$FIXTURE" ]]        || fail "fixture not found: $FIXTURE"
[[ -d "$GOLDEN_DIR" ]]     || fail "golden dir not found: $GOLDEN_DIR"
[[ -f "$GOLDEN_DIR/sample.OBJ" ]] || fail "missing golden sample.OBJ"
[[ -f "$GOLDEN_DIR/sample.LST" ]] || fail "missing golden sample.LST"

# Fresh working dir every run so we don't confuse ourselves with stale
# artefacts, and so the test is idempotent.
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp "$FIXTURE" "$WORK_DIR/sample.asm"

(cd "$WORK_DIR" && "$BIN" sample) > "$WORK_DIR/stdout.log" 2>&1

# Sanity check — m2assem reports exception count on its own stdout,
# so we can fail early if pass 1 or pass 2 had any trouble.
if ! grep -q "There were 0 exception(s)" "$WORK_DIR/stdout.log"; then
  cat "$WORK_DIR/stdout.log" >&2
  fail "m2assem reported exceptions during the test run"
fi

pass=0
fail_count=0

check_obj() {
  if cmp -s "$WORK_DIR/sample.OBJ" "$GOLDEN_DIR/sample.OBJ"; then
    printf '  OK  sample.OBJ byte-identical to golden\n'
    pass=$((pass + 1))
  else
    printf '  FAIL  sample.OBJ differs from golden:\n' >&2
    diff "$GOLDEN_DIR/sample.OBJ" "$WORK_DIR/sample.OBJ" | sed 's/^/    /' >&2 || true
    fail_count=$((fail_count + 1))
  fi
}

check_lst() {
  local normalised="$WORK_DIR/sample.LST.normalised"
  sed -e 's|Version 1\.0 .*$|Version 1.0 <DATETIME>|' \
      -e 's|^Assembly Time: .*$|Assembly Time: <ELAPSED>|' \
      -e 's|^Assembly Rate: .*$|Assembly Rate: <RATE>|' \
      "$WORK_DIR/sample.LST" > "$normalised"

  if cmp -s "$normalised" "$GOLDEN_DIR/sample.LST"; then
    printf '  OK  sample.LST matches golden (after normalising date/time/rate)\n'
    pass=$((pass + 1))
  else
    printf '  FAIL  sample.LST differs from golden:\n' >&2
    diff "$GOLDEN_DIR/sample.LST" "$normalised" | sed 's/^/    /' >&2 || true
    fail_count=$((fail_count + 1))
  fi
}

printf 'Running integration tests against %s\n\n' "$BIN"
check_obj
check_lst

printf '\n%d passed, %d failed\n' "$pass" "$fail_count"
[[ $fail_count -eq 0 ]] || exit 1

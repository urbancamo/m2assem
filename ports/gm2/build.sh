#!/usr/bin/env bash
#
# Build script for the gm2 port of m2assem.
#
# The original sources (under ../../src) target TopSpeed Modula-2 and use
# DOS-specific modules (Lib, FIO, SYSTEM.Registers, IO). This port adapts
# them to GNU Modula-2 (gm2) on modern Unix. See PORTING.md for details.
#
# gm2 does not auto-compile dependencies when given a single main module,
# and -fm2-whole-program triggers an internal compiler error on ADM.mod at
# gm2 15.2.  So we compile each implementation module to its own .o file
# and then link them into the final executable.

set -euo pipefail

PORT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$PORT_DIR/src"
BUILD_DIR="$PORT_DIR/build"
OBJ_DIR="$BUILD_DIR/obj"
MAIN_MODULE="M2Assem"
OUTPUT="$BUILD_DIR/m2assem"

GM2="${GM2:-gm2}"

GM2_FLAGS=(
  -g
  -fpim
  -flibs=pim,iso
  -Wall
  -I"$SRC_DIR"
)

# Implementation modules to compile.  Test harnesses (TestLex, TestStrings,
# TestTable) are deliberately excluded — they're orphan test programs, not
# part of the main assembler binary.
IMPLEMENTATION_MODULES=(
  MyStrings
  Exceptions
  TableTrees
  TableExt
  Table
  Location
  Expression
  PseudoOps
  ADM
  Lex
  ObjectGenerator
  Listing
  Interface
)

mkdir -p "$OBJ_DIR"
cd "$SRC_DIR"

echo "Building with $("$GM2" --version | head -1)"
echo

echo "Compiling C shims..."
# CTime.c is a libc-backed time/date helper that sidesteps gm2's broken
# wraptime / SysClock on macOS — see GM2-BUGS.md bug 3.  It is a
# definition-only Modula-2 module (CTime.def with no CTime.mod) whose
# procedure bodies and gm2 framework symbols both live in CTime.c.
printf '  %-20s' "CTime.c"
cc -g -O0 -c -o "$OBJ_DIR/CTime.o" CTime.c
printf ' ok\n'

echo
echo "Compiling implementation modules..."
for m in "${IMPLEMENTATION_MODULES[@]}"; do
  printf '  %-20s' "$m"
  "$GM2" "${GM2_FLAGS[@]}" -c -o "$OBJ_DIR/${m}.o" "${m}.mod"
  printf ' ok\n'
done

echo
echo "Compiling program module..."
printf '  %-20s' "$MAIN_MODULE"
"$GM2" "${GM2_FLAGS[@]}" -c -o "$OBJ_DIR/${MAIN_MODULE}.o" "${MAIN_MODULE}.mod"
printf ' ok\n'

echo
echo "Linking..."
# gm2 -c on a program module does not emit main(); instead, pass the .mod
# file to the final link step so gm2 compiles the main and generates the
# bootstrap scaffold, linking in the pre-compiled implementation .o files.
OBJS=("$OBJ_DIR/CTime.o")
for m in "${IMPLEMENTATION_MODULES[@]}"; do
  OBJS+=("$OBJ_DIR/${m}.o")
done
"$GM2" "${GM2_FLAGS[@]}" -o "$OUTPUT" "${MAIN_MODULE}.mod" "${OBJS[@]}"

echo
echo "Built: $OUTPUT"

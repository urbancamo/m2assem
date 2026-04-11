# m2assem — gm2 Porting Notes

Porting the 1990 TopSpeed Modula-2 sources under `../../src` to GNU Modula-2
(gm2) 15.2 on modern Unix (aarch64 Darwin). The original `src/` tree is kept
untouched as a historical artifact; all edits happen here under
`ports/gm2/src/`.

## Status

| Phase | State |
|---|---|
| Build | ✅ all 13 implementation modules + main compile and link cleanly |
| Run   | ✅ binary executes, prints banner, parses command line, opens input file, scans source lines |
| Smoke test against `sample.asm` | ✅ assembles all 12 lines, **0 exceptions**, produces `sample.lst` and `sample.obj` byte-equivalent to the historical TopSpeed reference (modulo line endings) |
| Test harnesses (`TestLex.mod`, `TestStrings.mod`, `TestTable.mod`) | ⏳ deferred — not in main build dependency closure |
| Date/time in listing header | ✅ via `CTime` C shim that calls libc directly (works around the broken gm2 `wraptime` on macOS — see GM2-BUGS.md bug 3) |

## Build

```sh
./build.sh                                # one shot
./build/m2assem                            # banner + usage
cp -r src/demo build/ && cd build/demo
../m2assem sample                          # smoke test
```

## Tests

```sh
./test/test.sh                  # test against current build
BUILD=1 ./test/test.sh          # rebuild first, then test
```

The test runner (`ports/gm2/test/test.sh`) runs the built `m2assem`
against `src/demo/sample.asm` in a fresh scratch directory under
`test/tmp/` and compares the generated output against golden files in
`test/golden/`:

- **`sample.OBJ`** — compared **byte-for-byte**. The object file content
  is fully deterministic, so any difference is a regression.
- **`sample.LST`** — compared after **normalising** the three fields
  that vary legitimately between runs (page-header date/time, assembly
  elapsed time, assembly rate). The golden LST stores these slots as
  `<DATETIME>` / `<ELAPSED>` / `<RATE>` placeholders. Everything else —
  addresses, machine code, symbol table, formatting — must match
  exactly.

The runner exits non-zero and prints a unified diff on any mismatch,
so regressions are immediately visible. An auto-discovery step adds
`/usr/local/gcc-m2/bin` to `PATH` if `gm2` isn't already on it, so
`BUILD=1 ./test/test.sh` works from any fresh shell.

`build.sh` compiles each implementation module to `build/obj/*.o` with
`gm2 -c`, then links by passing `M2Assem.mod` plus all `.o` files to a final
gm2 invocation so gm2 generates the bootstrap scaffold and `main()`.
`-fm2-whole-program` is **not** used because it triggers the same internal
compiler error described below.

Compile flags: `-g -fpim -flibs=pim,iso -Wall -I src`. The ISO library is
linked alongside PIM so we can use `SysClock.GetClock` for time/date.

## What had to change, by category

### 1. TopSpeed-only syntax

| File | Change |
|---|---|
| `ADM.mod:361` | TopSpeed `>>` right-shift operator → `DIV 65536` |
| `Expression.mod` (lines 460–494) | Mutual recursion `DoShl`/`DoShr` via `FORWARD` declaration → rewritten as two standalone procedures with the opposite direction inlined |
| `Expression.mod` (4 sites) | `Bits = SET OF [0..31]` → `SET OF [0..63]`, because gm2 `LONGINT` is 64-bit and the original assumed 32-bit |

### 2. Original-source bugs that gm2 caught (TopSpeed didn't)

| File | Bug | Fix |
|---|---|---|
| `TableTress.def` | Filename typo (double-s, missing 'e') | Renamed to `TableTrees.def` |
| `TableTrees.mod:14` | `FROM Table IMPORT TableType` while the .def imports it from `TableExt` → name clash | Aligned to import from `TableExt` |
| `MyStrings.def:65` vs `.mod:80` | Parameter name `P` vs `Position` for `CharInString` | Renamed in `.mod` to match `.def` |
| `Listing.def:83` vs `.mod:392` | Parameter name `TitleString` vs `NewTitle` for `SetTitle` | Renamed in `.def` to match `.mod` |
| `M2Assem.mod:24` | `FROM Lex IMPORT DecodedLine` — Lex re-exports it from ADM, allowed under TopSpeed but not gm2 | Direct import from `ADM` |
| `ADM.mod:17` | `FROM Table IMPORT TableType` — Table re-exports it from TableExt | Direct import from `TableExt` |

### 3. `T(x)` cast → `VAL(T, x)` conversion

gm2 treats the syntax `TypeName(expression)` as a same-size **type-transfer
cast** (memory-reinterpret). It only allows it when the source and target
types are the same width. The PIM convention of using `T(x)` as a
**conversion** (e.g. `LONGINT(someCardinal)` to widen) requires the explicit
`VAL(T, x)` form in gm2. Sites updated:

| File | Sites |
|---|---|
| `Expression.mod` | `LONGINT(Base)`, `LONGINT(ORD(c) - ORD('0'))` (3×) |
| `Table.mod` | `LONGCARD(CharPos)`, `LONGCARD(TableSize)`, `CARDINAL(...)` |
| `Location.mod` | `LONGCARD(Increment)` (2×) |
| `PseudoOps.mod` | `CARDINAL(Length)` (2×), `CARDINAL(Width)`, `CARDINAL(Base)`, `LONGCARD(RESSize)` |
| `Listing.mod` | `LONGCARD(StartHours/Minutes/Seconds)` (3×), `LONGCARD(EndHours/Minutes/Seconds)` (3×), `CARDINAL(AssemblyTime …)` (3×), `LONGINT(SourceNo)` |

### 4. `Word(x)` cast → `LongIntToWord` helper

`Word = SET OF [0..15]` is 16 bits; gm2's `LONGINT` is 64 bits. Casting
between them via `Word(LongIntExpr)` fails the same-size test. The original
relied on TopSpeed's 32-bit `LONGINT` matching its `Word` more closely.

Solution: added `LongIntToWord(L: LONGINT): Word` to `ADM.def` / `ADM.mod`,
which packs the low 16 bits of `L` (handling negative values via Euclidean
modulo) into a `Word` set bit-by-bit. Then replaced **20 sites** in
`ADM.mod` and **4 sites** in `PseudoOps.mod` with calls to the helper.

### 5. `Interface.mod` complete rewrite

The most concentrated work of the port. The original `Interface.mod` was
the platform-abstraction layer for TopSpeed Modula-2 on MS-DOS:

- `FROM FIO IMPORT StandardInput, StandardOutput, ErrorOutput, AuxDevice, PrinterDevice, File`
- `FROM Lib IMPORT ParamCount, ParamStr, Dos`
- `FROM SYSTEM IMPORT Registers` — for INT 21h calls
- `IMPORT IO` — TopSpeed terminal I/O
- A manual buffer pool (`BufferPtr`/`Buffer`/`BufferList`) with `FIO.AssignBuffer`
- An `IODebug` toggle that switched between `FIO.IOcheck := TRUE/FALSE`
- A dual stdin/stdout dispatch path: `IF F = StdIn THEN IO.X ELSE FIO.X END` for every read/write

The rewrite uses gm2's PIM `FIO`, `NumberIO`, `Args`, `FileSysOp`, and ISO
`SysClock`. The buffer pool is gone (gm2's FIO buffers internally). The
dual dispatch is gone because gm2 `FIO.StdIn`/`StdOut` are themselves
`FIO.File` values, so the `IF F = StdIn` branch collapses into a single
`FIO.X(F, …)`. `IODebug` / `IOcheck` are gone (gm2 reports per-file via
`FIO.IsNoError`). `GetTime` / `GetDate` are now one-liners over
`SysClock.GetClock`.

End result is **about 40% shorter** than the original. `Interface.def`
keeps the same public surface — `StdIn`/`StdOut`/`ErrOut` become VARs
initialised in the module body from `FIO.StdIn`/`StdOut`/`StdErr`,
`File`/`FileHandle` re-exposed as `FIO.File`, `NULLFile = MAX(CARDINAL)`.

A small `LastReadFile` module variable preserves the parameterless
`EndOfFile()` API (gm2's `FIO.EOF` requires a file argument; we cache the
last file read by any `ReadX` call and check that one).

### 6. Build script structure

Before:
```sh
gm2 -fm2-whole-program -o m2assem M2Assem.mod
```
Doesn't work — `-fm2-whole-program` triggers the gm2 ICE described below
on `ADM.mod`.

After:
```sh
for m in ${MODULES[@]}; do gm2 -c -o build/obj/${m}.o ${m}.mod; done
gm2 -o build/m2assem M2Assem.mod build/obj/*.o
```
The link step gives gm2 `M2Assem.mod` (not its compiled `.o`) so gm2
generates the bootstrap scaffold and `main()` while linking against the
pre-compiled implementation objects.

## gm2 15.2 bugs found

### Bug 1 — ICE on dynamic set constructors

```
cc1gm2: internal compiler error: expecting ConstVar symbol
```

**Reproducer**: a set literal `Word{Position + 1, Position}` where `Word`
is a user-defined `SET OF [0..N]` and `Position` is a runtime CARDINAL
parameter. Original site: `ADM.mod` `AddRegister`, lines 117–125 of the
unpatched source.

**Workaround**: replace each set constructor with a sequence of `INCL`
calls on the individual indices:
```modula-2
3:  INCL(AI, Position + 1); INCL(AI, Position)                          |
```

This is a real compiler bug — gm2 should accept non-constant expressions
inside set constructors per PIM. Worth filing upstream with this minimal
reproducer.

### Bug 2 — Literal-to-fixed-array parameter coercion off-by-one

When a string literal is passed directly to a procedure parameter of type
`ARRAY [low..high] OF CHAR` with non-zero `low`, gm2 lays out the literal
starting at offset `low` in the parameter's storage but indexes it as if
`low = 0`, effectively shifting the visible content left by `low` bytes.

**Reproducer**:

```modula-2
TYPE String = ARRAY [1..10] OF CHAR;
CONST Msg = "Hello";

PROCEDURE Show(P: String);
BEGIN
  WriteCard(ORD(P[1]), 4)   (* expected 72 ('H'), actually prints 101 ('e') *)
END Show;

BEGIN
  Show(Msg)                  (* literal passed directly                    *)
END.
```

Compare:
```modula-2
VAR S: String;
BEGIN
  S := Msg;
  Show(S)                    (* prints 72 ('H') correctly                  *)
END.
```

The bug only fires when a literal is passed directly through a `: String`
**value parameter**. VAR-passed strings work, and assigning a literal to
a local then passing it works.

**Workaround**: declare the affected parameters as open `ARRAY OF CHAR`
instead of the project's fixed-bound `String` type. Open arrays use 0-based
indexing internally and aren't affected. Existing String callers still
pass cleanly. Sites updated:

| Procedure | File |
|---|---|
| `WriteAString(F, S)` | `Interface.def` / `.mod` |
| `Raise(Type, Level, Message)` | `Exceptions.def` / `.mod` |
| `AddError(Message)` | `Listing.def` / `.mod` |
| `ConcatStrings(VAR S1, S2)` | `MyStrings.def` / `.mod` (rewrote loop body to use 0-based S2 with HIGH/EndOfLine termination) |

This is also worth filing upstream as a non-conformance — PIM Modula-2
defines value-parameter passing to coerce by element count, preserving the
declared lower bound on the formal parameter side.

### Other minor original-code bug touched along the way

`MyStrings.StringToArray` did not NUL-terminate the output array. This was
benign on TopSpeed (all callers re-initialised the array first), but
gm2's FIO library treats `ARRAY OF CHAR` arguments as C strings, so passing
an unterminated array to `FIO.Exists` reads garbage past the actual filename.
Added one line to terminate: `Array[Counter - 1] := EndOfLine` after the
copy loop.

## Type-width caveats still outstanding

- TopSpeed `LONGCARD` / `LONGINT` were 32 bits. On aarch64 gm2 they are 64
  bits. The `LongIntToWord` helper handles the WORDLENGTH=16 narrowing
  cleanly via modulo arithmetic.
- `NumberIO.HexToStr` / `CardToStr` / `IntToStr` take `CARDINAL`/`INTEGER`,
  not their long variants. `Interface.WriteALongInt` / `WriteALongHex`
  currently truncate via `VAL(INTEGER, L)` / `VAL(CARDINAL, L)`. For a 1990
  assembler with 32-bit address spaces this is safe; revisit if any value
  ever exceeds 2³¹.
- `ReadALongInt` / `ReadALongHex` use `FIO.ReadCardinal` and widen — no
  reads of values > 2³² are expected.

## End-to-end smoke test result

Running `m2assem sample` against `src/demo/sample.asm`:

```
Modula-2 Meta-Assembler Version 1.0 (c)1990 Mark Wickens
Assembling: Pass 1
Assembling: Pass 2
Assembled 12 lines at a rate of 0 lines per minute.
There were 0 exception(s) raised during assembly.
A valid object code file was writted.
```

The generated `sample.lst` and `sample.obj` are functionally identical to
the historical 1990 TopSpeed reference under `src/demo/`. Diffs are
limited to:

1. **Line endings** — the gm2 port writes Unix LF; the historical files
   are DOS CRLF. (1 byte/line difference.)
2. **Listing header date/time** — the gm2 port writes `0/ 0/ 0  0: 0: 0`
   instead of a real timestamp. See "What's still cosmetically off" below.

The opcodes match byte-for-byte:

```
       3E8 4E71      ← LABEL4: NOP
       3E9 D941      ← LABEL3: ADDC .D1,.D4
       3EA EB8C      ← LABEL2: SHL.L #5,.D4
       3EB 4E4A      ← LABEL1: BRK #10
       3EC 4E4A
```

The symbol table matches: `End=15, Start=37, LABEL1..4 = 1003..1000`.

## Additional fixes made during the runtime debugging pass

In addition to the build-level fixes documented above, the following
were needed to get the runtime working end-to-end:

### CRLF handling in `Interface.ReadAString`

The historical `sample.asm` uses DOS CRLF line endings. gm2's
`FIO.ReadString` strips the trailing LF but leaves the CR in place,
which then propagates into `Decoded.Operand[1].Argument` and confuses
`Expression.Evaluate` ("Invalid operator in expression"). Added a
trailing-CR strip after `FIO.ReadString` to make the lex/parse pipeline
see clean lines regardless of source file line endings.

### `Interface.CloseAFile` post-close error probe

The original called `FIO.IOresult()` after `Close` to detect close
errors. gm2's `FIO.IsNoError(F)` raises a runtime panic if `F` has
already been freed by `Close`. Removed the post-close probe — gm2's FIO
doesn't expose a way to check the result of a close cleanly.

### More `: String` value parameters → `ARRAY OF CHAR`

The build-level fix had handled `WriteAString`, `Raise`, `AddError`,
and `ConcatStrings`. Two more procedures turned out to receive literals
during runtime:

- **`TableExt.InsertCommand(Key: String, ...)`** — called once per
  opcode (`InsertCommand("ADD", ...)`, `("SUB", ...)`, ~100 sites in
  `ADM.mod` and `PseudoOps.mod`). Off-by-one corruption made `"ADD"`
  become `"DD"`, `"SUB"` become `"UB"`, etc., producing dozens of
  spurious "Key has already been inserted in table" errors at startup
  as the corrupted opcodes collided with each other. Changed `Key` to
  `ARRAY OF CHAR`, with internal conversion to `String` via
  `ArrayToString` before storing in the hash table.
- **`MyStrings.EqualStrings(S1, S2: String): BOOLEAN`** — called many
  times in `ADM.mod` with literals (`EqualStrings("SP", Register)`,
  `EqualStrings(DecInstr.Command, "LD")`, etc.). Without the fix, the
  command-dispatch in `Assemble` couldn't recognise valid commands.
  Rewrote the implementation to walk both inputs as 0-based open
  arrays, terminating on `EndOfLine` or `HIGH(S)`.

### `MyStrings.StringToArray` NUL-termination

`StringToArray` did not write a NUL terminator. Benign on TopSpeed
(callers re-initialised the destination), but gm2's `FIO.Exists` reads
`ARRAY OF CHAR` arguments as C strings, so passing an unterminated array
caused `FileExists` to read garbage past the actual filename. Added one
line to terminate.

### `WriteALongHex` formatting

gm2's `NumberIO.HexToStr` zero-pads to width (`000003E8`), while
TopSpeed's `WrLngHex` space-padded (`     3E8`). Added a leading-zero
to leading-space replacement in `Interface.WriteALongHex` to preserve
historical listing format.

## CTime — libc-backed time/date shim

Because gm2's `wraptime` and `SysClock` are both broken on macOS
(see GM2-BUGS.md bug 3), the port includes a small definition-only
Modula-2 module `CTime` whose procedure bodies and gm2 framework symbols
all live in `ports/gm2/src/CTime.c`. The C file calls libc `time(3)` /
`localtime_r(3)` directly and exports the symbols gm2 mangling expects:

- `CTime_GetTime` / `CTime_GetDate` — the procedure bodies
- `_M2_CTime_init` / `_fini` / `_dep` / `_ctor` — the gm2 module framework

The constructor calls `m2pim_M2RTS_RegisterModule` to wire the module
into the runtime, mirroring what `libgm2/libm2iso/wraptime.cc` does for
the standard library.

`build.sh` compiles `CTime.c` with `cc -c` before the gm2 modules and
includes the resulting `CTime.o` in the final link. No corresponding
`CTime.mod` file is needed — gm2 is happy with a definition-only module
as long as the symbols resolve at link time.

This is a useful pattern for integrating any C code with gm2 from user
projects, not just for working around the wraptime bug.

## What's still cosmetically off

1. **Output line endings** are LF rather than the historical CRLF. Could
   be fixed by writing `\r\n` explicitly in `WriteALine`, but it's
   arguably correct for a modern Unix port to use Unix line endings.
2. **`TestLex.mod`** still uses TopSpeed `IO.RdStr` / `IO.WrCard` and
   isn't in the build closure. Would need a small port if anyone wants
   to run the test harnesses.
3. **Assembly Time stat** reads `0: 0: 0` because the modern host
   assembles 12 lines in well under a second. This is correct, not a
   bug — just an artifact of the speed differential between an Apple
   M4 and a 1990 DOS PC. Larger inputs would show non-zero durations.

## Suggested next steps

1. **File the three gm2 bugs upstream** (see GM2-BUGS.md for ready-to-use
   reproducers and reports).
2. **Port `TestLex.mod`** if test coverage is desired.
3. **Decide on line-ending policy** for output files — keep Unix, or
   match the original CRLF for byte-identical historical reproduction.
4. **Once gm2 `wraptime` is fixed upstream**, the `CTime` shim could be
   replaced with a pure-Modula-2 implementation if that's preferred —
   though the C shim is small and self-contained, and works as a useful
   illustration of gm2 ↔ C linkage for future maintainers.

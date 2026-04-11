# Testing the gm2 port of m2assem

A shell-based regression test suite under `ports/gm2/test/` that exercises
99% of m2assem's opcode table via 12 small fixture programs. Each fixture
is deliberately written to stay close to the IEEE Proposed Assembly
Language Standard draft (1979) as understood by the 1990 m2assem code,
which makes the test suite a working reference for the assembler's
quirks — including a handful of latent bugs that sat in the original
for 35 years before this port started running real programs through it.

This document explains how the tests are structured, what each fixture
demonstrates, and the more interesting things that writing them
uncovered about the 1990 implementation.

## Running

```sh
cd ports/gm2
./build.sh                # build the assembler
./test/test.sh            # run every fixture
BUILD=1 ./test/test.sh    # rebuild first, then run
```

The runner expects `gm2` on `PATH`; if it isn't, it looks for
`/usr/local/gcc-m2/bin/gm2` (the default install location from the
project's build instructions) and adds that prefix automatically.

Exit status is 0 if every fixture passes, non-zero if any check fails
(with a diff printed to stderr). Scratch files land in `test/tmp/`
(gitignored); goldens live in `test/golden/`.

## What gets tested

For every fixture `X.asm`, the runner:

1. Copies `X.asm` into a fresh scratch directory.
2. Runs the built `m2assem` on it.
3. Fails if m2assem reports any exceptions.
4. Compares `X.OBJ` byte-for-byte against `test/golden/X.OBJ`. The
   object file is deterministic so any difference is a regression.
5. Compares `X.LST` against `test/golden/X.LST` after normalising three
   fields that legitimately vary between runs:
   - the page-header date/time (`Version 1.0  11/ 4/2026  11:00:42`)
   - `Assembly Time: <elapsed>`
   - `Assembly Rate: <rate>`
   The golden LST stores these slots as `<DATETIME>` / `<ELAPSED>` /
   `<RATE>` placeholders. Everything else must match exactly.

Adding a new fixture is: drop an `.asm` file in `test/fixtures/`,
generate its goldens with the helper below, and add one line to the
`CASES` array in `test.sh`.

```sh
# Generating goldens for a new fixture
cp test/fixtures/new.asm build/testwork/
(cd build/testwork && ../m2assem new)
cp build/testwork/new.OBJ test/golden/new.OBJ
sed -e 's|Version 1\.0 .*$|Version 1.0 <DATETIME>|' \
    -e 's|^Assembly Time: .*$|Assembly Time: <ELAPSED>|' \
    -e 's|^Assembly Rate: .*$|Assembly Rate: <RATE>|' \
    build/testwork/new.LST > test/golden/new.LST
```

## Coverage

**92 of 92 opcodes** and **10 of 10 pseudo-ops** are exercised by at
least one fixture. `TEST1` was formerly unreachable due to a 1990
lexer bug (details in the "Historical discoveries" section below);
the lexer has since been extended to accept digits after the first
letter of a mnemonic, and `TEST1` is now covered by `bits.asm`.

The full per-opcode matrix lives in [`test/COVERAGE.md`](test/COVERAGE.md).
Summary:

| Fixture | Opcodes added | Notes |
|---|---|---|
| `sample.asm`   | 4  | Historical reference, preserved from 1990 |
| `bubble.asm`   | 8  | Bubble sort; adds MOV/LD/CMP/ADD/SUB/BLE/BGE/DATA.W |
| `math.asm`     | 6  | Running accumulators; AND/OR/XOR/SHRA/DBR/DATA.L |
| `branches.asm` | 12 | All Bcc variants except BGE/BLE |
| `dbcc.asm`     | 14 | All DBcc variants except DBR |
| `shifts.asm`   | 6  | SHR, SHLA, ROR, ROL, RORC, ROLC |
| `setcc.asm`    | 15 | SET and all 14 SETcc variants |
| `arith.asm`    | 15 | MUL/DIV/BCD/NEG/EXT/CHK/NOT/CLR/TEST |
| `bits.asm`     | 3  | TESTSET/TESTCLR/TESTNOT (TEST1 unreachable) |
| `system.asm`   | 6  | WAIT/BRKV/RESET/RET/RETR/RETE |
| `pseudo.asm`   | 4  | DATA.B/PAGE/TITLE/RES |
| `call.asm`     | 8  | BR/CALL/XCH/ST/STM/LDM/PUSH/POP |

## Historical discoveries

Writing the nine new fixtures surfaced a handful of quirks and real
bugs in the 1990 code. `sample.asm` is only eleven lines long — it
was never going to catch this much. Most of these were working around
how the code happened to be structured rather than crashes, so they'd
have been very hard to spot without a second program to run through
the assembler.

### 1. Blank lines re-emit the previous instruction

**Found while porting**, before the extended tests. `ADM.Assemble`
takes `VAR` parameters `Length` and `AI` but never initialised them at
entry. If the command-dispatch block was skipped — blank line, a
comment-only line, or a label-only line — `Length` and `AI` retained
whatever values were left by the previous call. `M2Assem.Pass2`
faithfully wrote those values into the object file and advanced the
location counter, so every blank line effectively re-emitted the
bytes of the previous instruction.

The 1990 TopSpeed binary had exactly the same bug. You can see it in
`src/demo/sample.lst` on line 12:

```
  12       3EC  4E4A                      ← no source, but BRK bytes appear
```

gm2 had actually been warning us about this during compilation:

```
Listing.mod:42:11: warning: attempting to access 'Length' before
                   it has been initialized
```

Fix: zero `Length` and clear `AI` at the top of `Assemble`.

### 2. DATA.L emitted the wrong number of words, with the high word stubbed out

**Found writing `math.asm`.** `DoDATA` set `Length := 2` for DATA.W
and `Length := 4` for DATA.L, but `Length` in this assembler is
expressed in **words** (16-bit units), not bytes — the rest of the
codebase counts locations and emission sizes in words. So DATA.W
emitted *two* 16-bit words per directive (four bytes of zeros
overwriting the correct value) and DATA.L emitted four.

The DATA.L case had an even more obviously-broken implementation: the
high-word assignment was commented out with `(*MSW ... *)` — presumably
because the original TopSpeed expression `Word(INTEGER(DATA >> 16))`
wouldn't compile after some edit and the fix never landed.

```
'L': Length := 4;
     IF PassNo = 2 THEN
       (*MSW Data[1] := Word(INTEGER(DATA >> 16));*)  <-- commented out!
       Data[2] := LongIntToWord(DATA);
       AddCode(CurrentLocation(), Data, Length)
     END
```

So `DATA.L 0x12345678` would emit `0000 5678` instead of `1234 5678`,
losing the high half entirely.

Both fixed: `Length := 1` for `W` and `Length := 2` for `L`, with the
high word written via `DATA DIV 65536`.

### 3. DATA directives wrote their values twice

**Same session.** While fixing (2), I noticed `DoDATA` was writing to
a **local** `Data` variable and calling `AddCode` directly, while
`M2Assem.Pass2` *also* called `AddCode` with the shared `AI`
(which `DoDATA` never touched — my earlier fix for (1) had added
`FOR ClearIdx := ... AI[ClearIdx] := Word{}` to zero it).

So every `DATA` directive got emitted twice: once from `DoDATA`'s
local buffer with correct values, then immediately overwritten by
`Pass2`'s outer call with zeros from the cleared `AI`. The listing
only showed the second (zero) emission because `AddLine` also used
the outer `AI`, so the double-write was invisible in the listing.

Fixed by threading `AI` through `AssemblePseudoOp`'s signature so
`DoDATA` writes to the shared buffer; `Pass2`'s single `AddCode`
call then handles the emission.

### 4. `TEST1` cannot be lexed (fixed)

**Found writing `bits.asm`.** `Lex.ExtractCommand` reads command
names one character at a time while `CurrentChar IN AlphabetSet`
(just `'A'..'Z'` / `'a'..'z'`). As soon as it sees a non-letter it
stops. So any mnemonic containing a digit is unparseable — and
`TEST1` is the only such mnemonic in the opcode table.

`TEST1` was registered in `InsertOpcodesInTable` (mapping to 68000
`BTST`), but the lexer bailed with "Command contains non-alphabetic
characters" before ever reaching the table lookup. The opcode had
been dead code for 35 years.

**Fixed** by extending `ExtractCommand` to accept trailing digits
after the first alphabetic character — the usual identifier rule.
A letter is still required for the first character (no mnemonics
can start with a digit), but subsequent characters may be letters
or digits:

```modula-2
IF CurrentChar IN AlphabetSet THEN
  INC(CurrentPos);
  CurrentChar := CharInString(Line, CurrentPos);
  WHILE CurrentChar IN AlphabetSet + DigitSet DO
    INC(CurrentPos);
    CurrentChar := CharInString(Line, CurrentPos)
  END
END;
```

`TEST1 .D0,.D1` now encodes to `0300` (68000 `BTST D0,D1`). The
`bits.asm` fixture is the regression test for this fix.

### 5. `PUSH` and `POP` are empty stubs

**Found writing `call.asm`.** `Type26` — the dispatcher for PUSH and
POP — is:

```modula-2
PROCEDURE Type26(): CARDINAL;
BEGIN
  RETURN 0
END Type26;
```

That's the whole body. No encoding logic at all. The mnemonics are
recognised (the outer `Assemble` loop finds them in the table), but
`Type26` returns length 0 so no bytes are emitted and the location
counter doesn't advance.

The original code intended PUSH to map to 68000 `LINK`/`PEA`/`MOVE`
and POP to `UNLK`/`MOVE`, but that dispatch was never written. The
fixture includes `PUSH .D0` / `POP .D0` just to confirm the
mnemonics are recognised — no bytes are emitted.

### 6. `BR` and `CALL` with a bare label don't work

**Found writing `branches.asm`.** Tried to write `BR L00` as the
unconditional branch at the top of a chain of conditional branches.
Got "Argument must be a register" — which seemed utterly unrelated
until I traced the dispatch.

`BR` and `CALL` are both Type 25. Type 25's logic is:

```modula-2
ScanOperand(DecInstr.Operand[1], AddrMode);
IF AddrMode = Imm THEN
  (* Must be a BSR instruction. *)
  RETURN Type11()        -- Bcc encoder
ELSE
  RETURN Type15()        -- JMP encoder
END
```

For `BR L00`, the bare label parses as "Direct" addressing mode (no
prefix character), which isn't Immediate, so we fall into the JMP
path. `Type15()` calls `CalcEA`, which for Direct mode checks that
the argument is a register name (`.Dn`/`.An`). `L00` isn't a register,
so `RegisterError` — hence the "Argument must be a register" message.

Even worse, the `Type11` path isn't reachable with a useful operand
either. `Type11` expects `Rel` or `Dir` mode, but Type 25 only reaches
it for `Imm`, which Type 11 then rejects with `AddrModeError`.

Both paths are broken for the obvious use case of "branch to a label
defined in the source".

The workaround in `call.asm` is to declare subroutine entry points as
absolute `EQU` constants and use the `/addr` effective-address form:

```
SUBLOC  EQU     2048            ; absolute entry of subroutine

Main:   BR      /SUBLOC         ; BRA / JMP absolute
        CALL    /SUBLOC         ; BSR / JSR absolute
        ...
        ORG     SUBLOC          ; place subroutine at the EQU'd address
        RET
```

That forces `AddrMode = Abs`, which routes through Type 15's CalcEA
successfully. The real fix would be in Type 25: route Dir/Rel
operands to `Type11` and only send other modes to `Type15`, then
teach `Type11` to emit relative displacements for label targets.

### 7. `XCH` only accepts the `.B` modifier

**Found writing `call.asm`.** 68000 `EXG` is defined as a long-word
operation — there's no byte or word form. Natural instinct is to
write `XCH.L .D0,.D1`.

That fails with "Wrong modifier". Trace:

- `XCH` is Type 24.
- Type 24 sets up the register-to-register bit pattern and then
  `RETURN Type6()`.
- Type 6 is the encoder for `ABCD`/`SBCD` (packed BCD arithmetic),
  which on 68000 is byte-only.
- Type 6's first check is `IF DecInstr.Modifier = 'B' THEN ... ELSE
  Raise(Code, Error, ModifierError)`.

So `XCH` inherits Type 6's `.B`-only modifier requirement even
though conceptually it has nothing to do with BCD. `call.asm` works
around this by writing `XCH.B .D0,.D1`, which encodes the same
`EXG.L D0,D1` bytes that 68000 actually produces — the underlying
encoding is correct even though the modifier the assembler demands
is semantically wrong.

### 8. `EXT`'s modifier is the source width, not the destination

**Found writing `arith.asm`.** 68000 convention is:

- `EXT.W Dn` — sign-extend the low byte of Dn to fill the low word
- `EXT.L Dn` — sign-extend the low word of Dn to fill the whole long

m2assem inverts this: the modifier is the *source* width, so `EXT.B`
means "extend a byte" (which the 68000 would call `EXT.W`) and
`EXT.W` means "extend a word" (the 68000's `EXT.L`). There is no
`EXT.L` — `Type17` only handles `.B` and `.W`, anything else raises
"Wrong modifier".

Not a bug, just an unusual convention documented here so future test
writers don't trip over it.

### 9. `TITLE`'s operand can't contain spaces or punctuation

**Found writing `pseudo.asm`.** Tried `TITLE "example listing"` and
got "Badly formed comment". The operand parser (`Lex.ExtractOperands`)
reads alphanumeric characters only — there's no string-literal
handling. The quote character isn't a prefix the parser recognises,
so the parser fails at the first `"` and treats everything up to
end-of-line as a malformed comment.

Use a single bare word: `TITLE Demo`. That's it. A listing title in
m2assem is limited to identifier characters.

### 10. gm2-specific quirks encountered along the way

Most of the 1990 code survived the port with only minor touch-ups,
but a few gm2-specific issues showed up:

- **Dynamic set constructors crash gm2.** `Word{Position + 1}` where
  `Word = SET OF [0..15]` and `Position` is a runtime CARDINAL
  triggers an internal compiler error in gm2 15.2: `cc1gm2: internal
  compiler error: expecting ConstVar symbol`. Worked around with
  explicit `INCL` calls in `ADM.AddRegister`.
- **String literal parameters get shifted by one byte.** Passing a
  string literal directly to a procedure value parameter declared as
  `ARRAY [1..N] OF CHAR` produces content shifted left by one. The
  first character is lost. Affected `Interface.WriteAString`,
  `Exceptions.Raise`, `Listing.AddError`, `MyStrings.ConcatStrings`,
  `TableExt.InsertCommand` and `MyStrings.EqualStrings`. All fixed
  by declaring the affected parameters as open `ARRAY OF CHAR`.
- **macOS `wraptime` and `SysClock` return zero/NULL.** gm2 15.2's
  bundled time libraries are broken on macOS — `wraptime` checks
  `HAVE_MALLOC_H` for its allocators, which is undefined on macOS
  (malloc lives in `<stdlib.h>` there), so every `InitTimeval`/
  `InitTM`/`InitTimezone` call returns NULL. The port sidesteps
  this with a small C shim under `src/CTime.c` that calls libc
  `time`/`localtime_r` directly.

All three are documented in [`GM2-BUGS.md`](GM2-BUGS.md) with
reproducer cases ready to file at https://gcc.gnu.org/bugzilla/.

## Perspective

What's striking about the 1990 bugs — (1) through (8) above — is
how benign each individual bug was in isolation. Bubble sort of five
words runs on a single short file with no blank lines and no DATA
directives; it would never have tripped any of these. The historical
`sample.asm` deliberately used only NOP / ADDC / SHL / BRK and stopped
there. The code compiled, produced output, and shipped.

Adding a proper test suite 35 years later turns all of them up in an
afternoon. That's worth remembering the next time someone suggests
that writing tests is overhead: the bugs were always there, dormant,
waiting for an input that would actually exercise them. The act of
codifying "what should this do, in enough variety" is what finds
them — and is also what lets you fix them with confidence that you
haven't broken the common case along the way.

This is also, arguably, what the *original* author would have done
next if they'd had more time on their final-year project. The Pattern
Language-style docs under `doc/pdf/` treat testing as step 4 of 4 and
explicitly note that "limited testing was performed due to time
constraints". The test fixtures here are, in some sense, the test
suite that should have shipped in 1990.

## Future work

Reaching literal 100% opcode coverage would require fixing three
things in the 1990 code itself rather than adding more tests:

1. **`Lex.ExtractCommand`** — allow digits after the first letter, so
   `TEST1` becomes parseable and joins the bit-manipulation fixture.
2. **`Type26`** — actually implement PUSH/POP encoding (the 68000
   primitives are LINK/UNLK/PEA/MOVE SP).
3. **`Type25` / `Type15` routing** — accept Relative-typed labels in
   `BR`/`CALL` targets and emit PC-relative displacements so
   `BR MyLabel` becomes an idiomatic way to jump to a label without
   the `EQU`/`/addr` dance.

All three are feasible but feel out of scope for "get the 1990 code
running again". The test suite in its current shape is a solid
regression harness: if any of the above land, the existing fixtures
will verify they haven't broken anything else.

See also:

- [`PORTING.md`](PORTING.md) — overall port notes and status
- [`GM2-BUGS.md`](GM2-BUGS.md) — the three gm2 compiler/library bugs
- [`test/COVERAGE.md`](test/COVERAGE.md) — per-opcode test matrix

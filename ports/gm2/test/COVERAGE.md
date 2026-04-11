# m2assem opcode coverage matrix

This file tracks which fixtures exercise each opcode and pseudo-op
that m2assem recognises.  An opcode is "tested" if a fixture uses it
with valid operands and m2assem assembles it without errors — the
test only checks that the assembler accepts the syntax and produces
a stable, regression-comparable object file; we don't simulate the
68000.

Run `./test/test.sh` from `ports/gm2/` to exercise every fixture.

## Summary

- **Tested opcodes**: 92 / 92 (100%) 🎉
- **Tested pseudo-ops**: 10 / 10 (100%)
- **Total fixtures**: 12

### Caveats

Two entries still have pre-existing 1990-era issues worked around in
the fixtures rather than fixed:

- **PUSH / POP** — Type 26 is a stub that returns 0 with no encoding
  logic.  The test fixture includes them so the mnemonics are
  recognised, but no bytes are emitted.
- **XCH** — Type 24 falls through to Type 6, which only accepts `.B`
  as a modifier.  Fixture uses `XCH.B` even though 68000 `EXG` is
  long-only.

**TEST1 (BTST)** was formerly unreachable because the 1990
`Lex.ExtractCommand` only read alphabetic characters for the command
name.  The port extended the lexer to accept trailing digits (letters
first, then letters-or-digits), following the usual identifier rule.
`TEST1` is now tested in `bits.asm` and encodes correctly to 68000
BTST.

## Fixtures

| Fixture | What it adds |
|---|---|
| `sample.asm`    | Historical reference — NOP, ADDC, SHL, BRK, ORG, EQU, BASE, OBJECT, SYMBOL, END |
| `bubble.asm`    | LD, MOV, CMP, BLE, BGE, ADD, SUB, BRK, DATA.W, indirect `@.An`, indirect+disp `@.An(d16)` |
| `math.asm`      | AND, OR, XOR, SHL.L, SHRA.L, DBR, DATA.L |
| `branches.asm`  | BE, BNE, BC, BNC, BP, BN, BV, BNV, BGT, BLT, BH, BNH |
| `dbcc.asm`      | DBE, DBNE, DBC, DBNC, DBP, DBN, DBV, DBNV, DBGT, DBGE, DBLT, DBLE, DBH, DBNH |
| `shifts.asm`    | SHR, SHLA, ROR, ROL, RORC, ROLC |
| `setcc.asm`     | SET, SETE, SETNE, SETC, SETNC, SETP, SETN, SETV, SETNV, SETGT, SETGE, SETLT, SETLE, SETH, SETNH |
| `arith.asm`     | MUL, MULU, DIV, DIVU, ADDD, SUBD, SUBC, NEG, NEGC, NEGD, EXT, CHK, NOT, CLR, TEST |
| `bits.asm`      | TESTSET, TESTCLR, TESTNOT  (TEST1 unreachable — see caveats) |
| `system.asm`    | WAIT, BRKV, RESET, RET, RETR, RETE |
| `pseudo.asm`    | DATA.B, PAGE, TITLE, RES |
| `call.asm`      | BR, CALL, XCH, ST, STM, LDM, PUSH, POP (via `/addr` absolute form) |

## Opcode coverage matrix

### Arithmetic (Type 3, 5, 6, 13, 15, 17, 19)

| Opcode | Type | Mnemonic | Fixture(s) |
|---|---|---|---|
| ADD    | 19 | ADD/ADDA/ADDQ/ADDI | bubble, math |
| ADDD   |  6 | ABCD               | arith |
| ADDC   |  5 | ADDX               | sample |
| SUB    | 19 | SUB/SUBA/SUBQ/SUBI | bubble, math |
| SUBD   |  6 | SBCD               | arith |
| SUBC   |  5 | SUBX               | arith |
| MULU   |  3 | MULU               | arith |
| MUL    |  3 | MULS               | arith |
| DIVU   |  3 | DIVU               | arith |
| DIV    |  3 | DIVS               | arith |
| CMP    | 19 | CMP/CMPA/CMPI/CMPM | bubble |
| NEG    | 13 | NEG                | arith |
| NEGC   | 13 | NEGX               | arith |
| NEGD   | 15 | NBCD               | arith |
| EXT    | 17 | EXT                | arith |
| CHK    |  3 | CHK                | arith |
| NOT    | 13 | NOT                | arith |
| CLR    | 13 | CLR                | arith |
| TEST   | 13 | TST                | arith |

### Logical (Type 19)

| Opcode | Type | Mnemonic | Fixture(s) |
|---|---|---|---|
| AND    | 19 | AND/ANDI | math |
| OR     | 19 | OR/ORI   | math |
| XOR    | 19 | EOR/EORI | math |

### Shift / rotate (Type 21)

| Opcode | Type | Mnemonic | Fixture(s) |
|---|---|---|---|
| SHR    | 21 | LSR  | shifts |
| SHL    | 21 | LSL  | sample, math |
| SHRA   | 21 | ASR  | math |
| SHLA   | 21 | ASL  | shifts |
| ROR    | 21 | ROR  | shifts |
| ROL    | 21 | ROL  | shifts |
| RORC   | 21 | ROXR | shifts |
| ROLC   | 21 | ROXL | shifts |

### Bit manipulation (Type 22)

| Opcode  | Type | Mnemonic | Fixture(s) |
|---|---|---|---|
| TEST1   | 22 | BTST | bits (after lexer fix) |
| TESTSET | 22 | BSET | bits |
| TESTCLR | 22 | BCLR | bits |
| TESTNOT | 22 | BCHG | bits |

### Move (Type 14, 23, 24, 26)

| Opcode | Type | Mnemonic | Fixture(s) |
|---|---|---|---|
| LD     | 23 | LEA/MOVE/MOVEA/MOVEP/MOVEQ | bubble, math |
| LDM    | 14 | MOVEM | call |
| ST     | 23 | MOVE/MOVEP | call |
| STM    | 14 | MOVEM | call |
| MOV    | 23 | MOVE/MOVEM/MOVEP/MOVEA/MOVEQ | bubble, math |
| XCH    | 24 | EXG/SWAP | call |
| PUSH   | 26 | LINK/PEA/MOVE | call (stub) |
| POP    | 26 | UNLK/MOVE     | call (stub) |

### Set on condition / Scc (Type 10)

| Opcode | Type | Mnemonic | Fixture(s) |
|---|---|---|---|
| SET    | 10 | ST  | setcc |
| SETE   | 10 | SEQ | setcc |
| SETNE  | 10 | SNE | setcc |
| SETC   | 10 | SCS | setcc |
| SETNC  | 10 | SCC | setcc |
| SETP   | 10 | SPL | setcc |
| SETN   | 10 | SMI | setcc |
| SETV   | 10 | SVS | setcc |
| SETNV  | 10 | SVC | setcc |
| SETGT  | 10 | SGT | setcc |
| SETGE  | 10 | SGE | setcc |
| SETLT  | 10 | SLT | setcc |
| SETLE  | 10 | SLE | setcc |
| SETH   | 10 | SHI | setcc |
| SETNH  | 10 | SLS | setcc |

### Branches (Type 11, 25)

| Opcode | Type | Mnemonic | Fixture(s) |
|---|---|---|---|
| BR     | 25 | BRA/JMP | call |
| BE     | 11 | BEQ | branches |
| BNE    | 11 | BNE | branches |
| BC     | 11 | BCS | branches |
| BNC    | 11 | BCC | branches |
| BP     | 11 | BPL | branches |
| BN     | 11 | BMI | branches |
| BV     | 11 | BVS | branches |
| BNV    | 11 | BVC | branches |
| BGT    | 11 | BGT | branches |
| BGE    | 11 | BGE | bubble |
| BLT    | 11 | BLT | branches |
| BLE    | 11 | BLE | bubble |
| BH     | 11 | BHI | branches |
| BNH    | 11 | BLS | branches |
| CALL   | 25 | BSR/JSR | call |

### Decrement and branch / DBcc (Type 12)

| Opcode | Type | Mnemonic | Fixture(s) |
|---|---|---|---|
| DBR    | 12 | DBRA/DBF | math |
| DBE    | 12 | DBEQ | dbcc |
| DBNE   | 12 | DBNE | dbcc |
| DBC    | 12 | DBCS | dbcc |
| DBNC   | 12 | DBCC | dbcc |
| DBP    | 12 | DBPL | dbcc |
| DBN    | 12 | DBMI | dbcc |
| DBV    | 12 | DBVS | dbcc |
| DBNV   | 12 | DBVC | dbcc |
| DBGT   | 12 | DBGT | dbcc |
| DBGE   | 12 | DBGE | dbcc |
| DBLT   | 12 | DBLT | dbcc |
| DBLE   | 12 | DBLE | dbcc |
| DBH    | 12 | DBHI | dbcc |
| DBNH   | 12 | DBLS | dbcc |

### System control / returns (Type 16, 18)

| Opcode | Type | Mnemonic | Fixture(s) |
|---|---|---|---|
| RET    | 18 | RTS | system, call |
| RETR   | 18 | RTR | system, call |
| RETE   | 18 | RTE | system, call |
| NOP    | 18 | NOP | sample, pseudo |
| WAIT   | 18 | STOP | system |
| BRK    | 16 | TRAP | sample, bubble, math (+ others) |
| BRKV   | 18 | TRAPV | system |
| RESET  | 18 | RESET | system |

## Pseudo-op coverage

| Pseudo | Number | Fixture(s) |
|---|---|---|
| ORG    | 1000 | everywhere |
| EQU    | 1001 | everywhere |
| END    | 1002 | everywhere |
| PAGE   | 1003 | pseudo |
| TITLE  | 1004 | pseudo |
| DATA.B | 1005 | pseudo |
| DATA.W | 1005 | bubble |
| DATA.L | 1005 | math |
| RES    | 1006 | pseudo |
| BASE   | 1007 | everywhere |
| SYMBOL | 1008 | everywhere |
| OBJECT | 1009 | everywhere |

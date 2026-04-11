[← Chapter 7. Bibliography](07-bibliography.md) | [↑ Contents](README.md) | —

# Chapter 8. Appendix

The original report shipped with a printed appendix containing every
Modula-2 definition module, implementation module and test module
used by the sample meta-assembler.  Rather than inline 120+ pages of
1990-era source listings in Markdown, this tree links directly to the
files under `src/` — which, thanks to the gm2 port under `ports/gm2/`,
is still the canonical source today.

## A.1. Definition Modules

The interface surface of each module.

| Module | Source |
|---|---|
| `ADM` — Assembler Definition Module, 68000 instruction encoder | [`src/ADM.def`](../../src/ADM.def) |
| `Exceptions` — Error reporting / fatal exit | [`src/Exceptions.def`](../../src/Exceptions.def) |
| `Expression` — Expression evaluator (arithmetic / logical) | [`src/Expression.def`](../../src/Expression.def) |
| `Interface` — Platform abstraction (I/O, args, time) | [`src/Interface.def`](../../src/Interface.def) |
| `Lex` — Lexical scanner | [`src/Lex.def`](../../src/Lex.def) |
| `Listing` — Listing file generator + stats | [`src/Listing.def`](../../src/Listing.def) |
| `Location` — Location counter | [`src/Location.def`](../../src/Location.def) |
| `ObjectGenerator` — Object file writer | [`src/ObjectGenerator.def`](../../src/ObjectGenerator.def) |
| `PseudoOps` — Pseudo-op (EQU, ORG, DATA, …) handlers | [`src/PseudoOps.def`](../../src/PseudoOps.def) |
| `MyStrings` — String utilities (the report calls this `Strings`) | [`src/MyStrings.def`](../../src/MyStrings.def) |
| `Table` — Hash-table symbol / opcode table | [`src/Table.def`](../../src/Table.def) |
| `TableExt` — Table record type extensions | [`src/TableExt.def`](../../src/TableExt.def) |
| `TableTrees` — Binary-search-tree bucket for the hash table | [`src/TableTrees.def`](../../src/TableTress.def) |

## A.2. Implementation Modules

The bodies of the modules above.  Each `.mod` file contains the
procedure implementations referenced by the corresponding `.def`.

| Module | Source |
|---|---|
| `ADM` | [`src/ADM.mod`](../../src/ADM.mod) |
| `Exceptions` | [`src/Exceptions.mod`](../../src/Exceptions.mod) |
| `Expression` | [`src/Expression.mod`](../../src/Expression.mod) |
| `Interface` | [`src/Interface.mod`](../../src/Interface.mod) |
| `Lex` | [`src/Lex.mod`](../../src/Lex.mod) |
| `Listing` | [`src/Listing.mod`](../../src/Listing.mod) |
| `Location` | [`src/Location.mod`](../../src/Location.mod) |
| `ObjectGenerator` | [`src/ObjectGenerator.mod`](../../src/ObjectGenerator.mod) |
| `PseudoOps` | [`src/PseudoOps.mod`](../../src/PseudoOps.mod) |
| `MyStrings` | [`src/MyStrings.mod`](../../src/MyStrings.mod) |
| `Table` | [`src/Table.mod`](../../src/Table.mod) |
| `TableExt` | [`src/TableExt.mod`](../../src/TableExt.mod) |
| `TableTrees` | [`src/TableTrees.mod`](../../src/TableTrees.mod) |
| `M2Assem` (main program) | [`src/M2Assem.mod`](../../src/M2Assem.mod) |

## A.3. Test Modules

Standalone test drivers that came bundled with the original source.
They import the same modules as `M2Assem` and exercise them in
isolation.

| Module | Source |
|---|---|
| `TestLex` — lexer round-trip | [`src/TestLex.mod`](../../src/TestLex.mod) |
| `TestStrings` — string utilities | [`src/TestStrings.mod`](../../src/TestStrings.mod) |
| `TestTable` — hash table + binary tree | [`src/TestTable.mod`](../../src/TestTable.mod) |

A broader regression-test suite (12 fixtures covering all 92 opcodes
and every reachable addressing mode) was added during the gm2 port.
It lives under [`ports/gm2/test/`](../../ports/gm2/test/) and
is documented in [`ports/gm2/TEST.md`](../../ports/gm2/TEST.md) and
[`ports/gm2/test/COVERAGE.md`](../../ports/gm2/test/COVERAGE.md).

## A.4. A Sample Run

The original appendix also included a hand-written sample input
program (`sample.asm`) together with the listing and object files the
assembler produced from it.  The same three files ship with the
source tree:

- [`src/demo/sample.asm`](../../src/demo/sample.asm) — input
- [`src/demo/sample.lst`](../../src/demo/sample.lst) — listing
- [`src/demo/sample.obj`](../../src/demo/sample.obj) — object code

The gm2 port exercises this file as the primary regression test;
see [`ports/gm2/test/fixtures/bubble.asm`](../../ports/gm2/test/fixtures/bubble.asm)
and friends for further programs that were written specifically to
probe the assembler's instruction set coverage.

---

[← Chapter 7. Bibliography](07-bibliography.md) | [↑ Contents](README.md) | —

# GNU Modula-2 (gm2) bugs found while porting m2assem

Two bugs encountered during the port of m2assem from TopSpeed Modula-2 to
gm2 15.2 on Apple Silicon. Each is reproducible from a small self-contained
program; both deserve upstream bug reports.

## Environment

- **Compiler**: gm2 (GCC) 15.2.0
- **Source**: Iain Sandoe's `gcc-15-2-darwin-pre-0` branch
  (https://github.com/iains/gcc-15-branch)
- **Built with**: `--enable-languages=c,c++,m2 --disable-multilib --disable-werror --with-system-zlib --with-sysroot=$(xcrun --show-sdk-path)`
- **Host**: aarch64-apple-darwin25.4.0 (macOS 26 / Tahoe, Apple M4)
- **Dialect flag**: `-fpim` (also tried `-fpim2`, `-fpim3`, `-fpim4` — same results)

---

## Bug 1 — Internal compiler error on dynamic set constructors

### Summary

Constructing a set literal whose elements are non-constant expressions
(such as `Word{Position + 1, Position}` where `Position` is a runtime
parameter) inside a `CASE` arm causes cc1gm2 to abort with an internal
compiler error:

```
cc1gm2: internal compiler error: expecting ConstVar symbol
Please submit a full bug report, with preprocessed source.
```

PIM Modula-2 explicitly permits non-constant element expressions in set
constructors, so this should compile.

### Minimal reproducer

`bug1.mod`:

```modula-2
MODULE bug1;

TYPE
  Word = SET OF [0..15];

VAR
  AI: Word;

PROCEDURE AddRegister(VAR AI: Word; Value, Position: CARDINAL);
BEGIN
  CASE Value OF
    1: AI := AI + Word{Position}                                   |
    2: AI := AI + Word{Position + 1}                               |
    3: AI := AI + Word{Position + 1, Position}                     |
    7: AI := AI + Word{Position + 2, Position + 1, Position}
  END
END AddRegister;

BEGIN
  AI := Word{};
  AddRegister(AI, 3, 0)
END bug1.
```

### Reproduce

```sh
gm2 -fpim -c bug1.mod
```

### Expected

Successful compilation. Per PIM, set constructors may contain expressions
of the base type (not just constants).

### Actual

```
cc1gm2: internal compiler error: expecting ConstVar symbol
Please submit a full bug report, with preprocessed source.
See <https://gcc.gnu.org/bugs/> for instructions.
```

No source location is given. The error is the same with `-O0`, with
`-fpim2`/`-fpim3`/`-fpim4`, and with `-freport-bug` (which writes only the
gm2 invocation, not a reduced source).

### Workaround

Replace each set constructor with an equivalent sequence of `INCL` calls:

```modula-2
CASE Value OF
  1: INCL(AI, Position)                                                  |
  2: INCL(AI, Position + 1)                                              |
  3: INCL(AI, Position + 1); INCL(AI, Position)                          |
  7: INCL(AI, Position + 2); INCL(AI, Position + 1); INCL(AI, Position)
END
```

This produces equivalent code and compiles cleanly.

### Notes

- The crash happens during pass 3 (code generation / quad emission). The
  compiler successfully parses, type-checks, and accepts the constructors;
  the failure is in lowering them to GIMPLE.
- It is the **non-constant element expressions** that trigger it, not the
  CASE statement structure: replacing `Position + 1` with the literal `1`
  inside the same CASE makes the ICE go away.
- Constructors with a single non-constant element (`Word{Position}`) also
  trigger it, so it's not specific to the multi-element form.
- Found while porting `ADM.mod` `AddRegister` procedure of the m2assem
  meta-assembler.

---

## Bug 2 — Literal-to-fixed-array parameter coercion off-by-one

### Summary

When a string literal (or `CONST` of `ARRAY OF CHAR` type) is passed
directly to a procedure value parameter declared as `ARRAY [low..high] OF
CHAR` with `low > 0`, gm2 lays out the literal in the parameter's storage
without applying the lower-bound offset, so the visible content is shifted
left by `low` bytes. The first character of the literal is lost.

### Minimal reproducer

`bug2.mod`:

```modula-2
MODULE bug2;

FROM FIO IMPORT StdOut, WriteString, WriteLine;
FROM NumberIO IMPORT WriteCard;

TYPE
  String = ARRAY [1..10] OF CHAR;

CONST
  Msg = "Hello";

VAR
  S: String;

PROCEDURE Show(P: String);
BEGIN
  WriteString(StdOut, "P[1..6] = ");
  WriteCard(ORD(P[1]), 4);  (* expecting 72  ('H') *)
  WriteCard(ORD(P[2]), 4);  (* expecting 101 ('e') *)
  WriteCard(ORD(P[3]), 4);  (* expecting 108 ('l') *)
  WriteCard(ORD(P[4]), 4);  (* expecting 108 ('l') *)
  WriteCard(ORD(P[5]), 4);  (* expecting 111 ('o') *)
  WriteCard(ORD(P[6]), 4);  (* expecting   0       *)
  WriteLine(StdOut)
END Show;

BEGIN
  S := Msg;
  WriteString(StdOut, "via VAR:     "); Show(S);
  WriteString(StdOut, "via literal: "); Show(Msg)
END bug2.
```

### Reproduce

```sh
gm2 -fpim -flibs=pim -o bug2 bug2.mod
./bug2
```

### Expected output

```
via VAR:     P[1..6] =   72 101 108 108 111   0
via literal: P[1..6] =   72 101 108 108 111   0
```

Both calls should print identical sequences — `'H'` at index 1, then
`'e','l','l','o'`, then a zero terminator at index 6.

### Actual output

```
via VAR:     P[1..6] =   72 101 108 108 111   0
via literal: P[1..6] =  101 108 108 111   0   0
```

The literal-passed call is shifted by one — `P[1]` returns `'e'` (101),
not `'H'` (72). The character `'H'` is unrecoverable from inside the
procedure: indexing `P[0]` is illegal (out of declared bounds), and the
storage that *should* contain `'H'` is either inaccessible or contains 0.

### Workaround

Declare the parameter as an open `ARRAY OF CHAR` (no explicit bounds):

```modula-2
PROCEDURE Show(P: ARRAY OF CHAR);
BEGIN
  WriteCard(ORD(P[0]), 4);   (* 'H' = 72 *)
  WriteCard(ORD(P[1]), 4);   (* 'e' *)
  ...
END Show;
```

Open arrays use 0-based indexing internally and are not affected. Both
literal arguments and `String` (`ARRAY [1..N] OF CHAR`) variables can be
passed to the same open-array parameter.

### Notes

- The bug only fires when:
  1. The formal parameter has a fixed bound `[low..high]` with `low > 0`,
     and
  2. The actual argument is a string literal (or a CONST whose type is
     `ARRAY OF CHAR`), passed by value.
- VAR-passed arguments work correctly: `S := Msg; Show(S)` prints the
  expected output. The error is in literal-to-formal-parameter binding,
  not in the way `String` variables are stored.
- The bug fires for both `S: String` and `S: ARRAY [1..10] OF CHAR` formals.
- Independent of dialect flag (`-fpim`, `-fpim2`, `-fpim3`, `-fpim4`,
  `-fiso` all show the same behaviour for the relevant case).
- This violates PIM section "Procedure declarations" — value parameter
  binding for arrays should preserve the formal parameter's index space,
  with element-by-element copy aligning element 1 of the actual to element
  1 of the formal when both are `[1..N]` arrays.
- Found while porting m2assem (1990 TopSpeed Modula-2 source) to gm2 — the
  visible symptom was `WriteAString(StdOut, "Modula-2 Meta-Assembler ...")`
  printing `"odula-2 Meta-Assembler ..."` (first character chopped) for
  every literal passed to a `: String` value parameter.

---

## How to file these upstream

The gm2 maintainer is Gaius Mulley. Issues are accepted at:

- GCC Bugzilla: https://gcc.gnu.org/bugzilla/ — file under component
  `modula-2`
- gm2 mailing list: gm2@gcc.gnu.org

For each bug, include:

1. The minimal reproducer above (self-contained, copy-pasteable).
2. The exact gm2 version (`gm2 --version`).
3. The host triple (`gcc -dumpmachine`).
4. The configure flags used to build gm2 (relevant for the Iain Sandoe
   darwin branch — see Environment section above).
5. The actual output (or the ICE message in full).
6. The expected output, with a one-line PIM citation if you can find one.
7. The workaround (helpful for the maintainer to confirm a fix
   restores the workaround-free form).

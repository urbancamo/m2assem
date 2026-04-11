# m2assem — Final Year Project Report

Markdown conversion of the 1990 final-year-project report that originally accompanied this source code.  The PDFs under [`doc/pdf/`](../pdf/) were produced from the PageMaker 3 sources and are the canonical form; this tree is a machine-assisted rendering of the same content for easier online reading.

The conversion pipeline lives in [`tools/pdf_to_md.py`](tools/pdf_to_md.py).  Run it from the project root to regenerate every file under `doc/md/`:

```sh
python3 doc/md/tools/pdf_to_md.py
```

## Contents

- [Chapter 2 — Abstract](02-abstract.md)
- [Chapter 3 — Introduction](03-introduction.md)
- [Chapter 4 — Meta-Assemblers](04-meta-assemblers.md)
- [Chapter 5 — A Sample Implementation](05-a-sample-implementation.md)
- [Chapter 6 — Conclusion](06-conclusion.md)
- [Chapter 7 — Bibliography](07-bibliography.md)
- [Chapter 8 — Appendix](08-appendix.md)

The two real figures — the 68000 instruction-format diagram (Figure 6) and the hash-table performance graph (Figure 30) — live under [`figures/`](figures/).  Every other "figure" in the original is an ASCII-art table or layout that comes through verbatim in the Markdown.

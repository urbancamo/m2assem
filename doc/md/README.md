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

All 35 figures from the original report live under [`figures/`](figures/).  Each one is rendered as a 300 dpi PNG of the PDF page (or a pixel-cropped region for Figure 6, which sits alone on its page).  Pages that carry two adjacent figures — 1+2, 3+4, 8+9, 16+17, 20+21, 30+31 — share a single PNG; both figure numbers appear in the combined caption.

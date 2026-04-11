#!/usr/bin/env python3
"""
pdf_to_md.py -- convert the m2assem final-year-project PDFs into Markdown.

Pipeline:

  1. Run `pdftotext -layout` against each source PDF and concatenate the
     output in the right order (Part1, Part2, Appendix).  The combined
     file is cached under doc/md/raw/ so subsequent runs don't have to
     re-invoke pdftotext.
  2. Walk the raw text line by line, stripping the repeating page
     header/footer, detecting section headings, joining wrapped
     paragraph lines, and emitting Markdown.
  3. Split the output into per-chapter Markdown files under doc/md/.

This is a conservative first pass.  It aims to produce Markdown that is
structurally correct (chapters, sections, paragraphs, code blocks,
figure references) but won't try to reformat tables into pipe-table
syntax or unify superscript citations — those are follow-up passes.

Usage:
  python3 pdf_to_md.py                -- full pipeline
  python3 pdf_to_md.py --extract-only -- stop after raw text extraction
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]        # m2assem project root
PDF_DIR = ROOT / "doc" / "pdf"
MD_DIR = ROOT / "doc" / "md"
RAW_DIR = MD_DIR / "raw"

# Extraction sources.  Part1 and Part2 are processed separately because
# they overlap: Part1 ends with a brief "chapter 6 teaser" after Part1's
# tail of chapter 5, then Part2 resumes chapter 5 from an earlier point
# and continues through chapter 6 and chapter 7.  Feeding both to the
# walker produces duplicate chapter-6 matches and interleaved 5.x / 6.x
# headings, so the extract_raw step stitches them together smarter:
# keep chapters 2-4 from Part1, drop Part1's chapter-5 body and
# chapter-6 teaser, and take chapter 5 onwards from Part2.
SOURCES = [
    ("part1", PDF_DIR / "FinalYearProject-Part1.pdf"),
    ("part2", PDF_DIR / "FinalYearProject-Part2.pdf"),
    ("appendix", PDF_DIR / "FinalYearProject-Appendix.pdf"),
]

# Lines that exactly match any of these are repeating page decorations
# and should be dropped.  Regex because the page number varies.
HEADER_FOOTER_RES = [
    re.compile(r"^\s*Project\s+Report\s*-\s*Meta\s+Assemblers\s*$"),
    re.compile(r"^\s*-\s*\d+\s*-\s*$"),            # "- 21 -" style page number
    re.compile(r"^\s*Appendix\s*-\s*\d+\s*-\s*$"), # appendix page decoration
]

# Chapter-level headings: "1. CONTENTS.", "4. META-ASSEMBLERS."
# Title must be all-caps (plus spaces / digits / slashes / hyphens) and at
# least four characters — that keeps list items like "1. C." from
# matching.  Chapter sequencing is also enforced in the walker.
CHAPTER_RE = re.compile(r"^([1-9])\.\s+([A-Z][A-Z0-9 /\-]{3,})\.\s*$")

# Section headings: "4.1. Section name.", "5.4.2. Detailed Design ..."
SECTION_RE = re.compile(r"^([1-9](?:\.\d+)+)\.?\s+([A-Z][^.]*?)\.?\s*$")

# Appendix section headings: "A.1. Definition Modules.", "A.2. Source."
APPENDIX_SECTION_RE = re.compile(
    r"^(A\.\d+(?:\.\d+)*)\.?\s+([A-Z][^.]*?)\.?\s*$"
)

# Line looks like a figure caption: "Figure 6. ..."
FIGURE_RE = re.compile(r"^\s*Figure\s+(\d+)\.\s+(.*)$")

# Figures we've rendered as PNG under doc/md/figures/, keyed by the
# "Figure N" number in the source PDF.
FIGURE_IMAGES = {
    "6":  ("figures/fig-06-instruction-formats.png",
           "68000 instruction format bit fields"),
    "30": ("figures/fig-30-hash-table-performance.png",
           "Hash table collisions vs load"),
}


@dataclass
class Chapter:
    number: int
    title: str
    slug: str
    body: list[str] = field(default_factory=list)


def run_pdftotext(pdf: Path) -> str:
    """Extract text from a PDF preserving layout."""
    result = subprocess.run(
        ["pdftotext", "-layout", str(pdf), "-"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def extract_raw() -> Path:
    """
    Run pdftotext over each source PDF, splice the outputs and cache
    under doc/md/raw/.  Part1 contributes chapters 2-4 only; Part2
    contributes chapter 5 onwards.  This sidesteps the Part1/Part2
    overlap — Part1 ends with a short chapter-6 teaser after its tail
    of chapter 5, and Part2 rewinds to re-do the last few pages of
    chapter 5 before continuing — which would otherwise produce
    duplicate chapter-6 matches.
    """
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    texts: dict[str, str] = {}
    for name, pdf in SOURCES:
        assert pdf.exists(), f"missing source PDF: {pdf}"
        text = run_pdftotext(pdf)
        (RAW_DIR / f"{name}.txt").write_text(text)
        texts[name] = text

    # Splice strategy.  Part1 and Part2 have an awkward overlap:
    #
    #  - Part1 runs through chapter 5 and ends with a brief chapter-6
    #    teaser typeset onto its last page.
    #  - Part2 starts mid-way through section 5.4.10 (Table Handler)
    #    — the typesetter rewound a few pages to re-establish context
    #    after Part1's page break — then carries 5.4.11 onwards, the
    #    real chapter 6, and chapter 7.
    #
    # To avoid duplication we cut Part1 at its 5.4.10 heading and let
    # Part2 provide everything from 5.4.10's body onwards.  Part2 thus
    # owns the Figure 30 caption (which sits inside 5.4.10) as well as
    # all of chapter 6 / 7.
    p1 = texts["part1"]
    p2 = texts["part2"]
    p1_lines = p1.splitlines()

    # Find the 5.4.10 heading in Part1's body (skip the TOC which also
    # references the section near the top).
    heading_re = re.compile(r"^5\.4\.10\.\s+Table Handler")
    p1_cut = len(p1_lines)
    for i, line in enumerate(p1_lines):
        if i < 200:
            continue
        if heading_re.match(line):
            p1_cut = i
            break

    part1_body = "\n".join(p1_lines[:p1_cut]) + "\n"
    # Inject the 5.4.10 heading explicitly so Part2's body attaches to
    # the right section.
    splice = "\n5.4.10. Table Handler Module (Table, TableTrees, TableExt).\n\n"

    combined_text = (
        "%%% BEGIN PART1 %%%\n" + part1_body + "%%% END PART1 %%%\n"
        + splice
        + "%%% BEGIN PART2 %%%\n" + p2 + "\n%%% END PART2 %%%\n"
        + "%%% BEGIN APPENDIX %%%\n" + texts["appendix"] + "\n%%% END APPENDIX %%%\n"
    )

    combined = RAW_DIR / "combined.txt"
    combined.write_text(combined_text)
    return combined


def is_boilerplate(line: str) -> bool:
    return any(r.match(line) for r in HEADER_FOOTER_RES)


def clean_raw(text: str) -> list[str]:
    """
    Drop page decorations and return cleaned lines.  We keep a single
    sentinel line '@@APPENDIX_START@@' at the boundary where the
    appendix PDF starts, so the walker can switch numbering schemes.

    Also heals paragraphs broken by a page boundary: if we're about to
    emit a blank-line run where the previous content line doesn't end
    with sentence-ending punctuation, we collapse the blank run so the
    paragraph flows through.
    """
    raw_lines = text.splitlines()
    out: list[str] = []

    def last_content_endings_ok(n: int = 1) -> bool:
        """True if the last non-blank line in `out` ends with a
        sentence terminator or some other natural break marker."""
        for l in reversed(out):
            if not l.strip():
                continue
            stripped = l.rstrip()
            if not stripped:
                continue
            last = stripped[-1]
            return last in ".!?:;)\"'"
        return True   # nothing behind us — treat as clean break

    for raw in raw_lines:
        if raw.startswith("%%% BEGIN APPENDIX"):
            out.append("@@APPENDIX_START@@")
            continue
        if raw.startswith("%%% BEGIN") or raw.startswith("%%% END"):
            continue
        if raw.startswith("\f"):                  # form-feed between pages
            continue
        if is_boilerplate(raw):
            # Paragraph continuation across a page break: drop blank
            # lines immediately before the stripped header/footer so the
            # next content line joins cleanly.
            if not last_content_endings_ok():
                while out and not out[-1].strip():
                    out.pop()
            continue
        if not raw.strip():
            # Drop any blank line that would split a paragraph
            # mid-sentence (its preceding line ended without sentence
            # terminator).  Correct paragraph separators — full stops,
            # section headings ending in period, list-item punctuation
            # — still survive because they end with one of '.!?:;)\'"'.
            if out and not last_content_endings_ok():
                continue
            out.append("")
            continue
        out.append(raw.rstrip())
    return out


def strip_false_chapter_headings(lines: list[str]) -> list[str]:
    """
    Scan for chapter-level headings that are followed by lower-numbered
    section headings before the next chapter.  Those are premature
    matches — the combined PDF contains a brief chapter-6 trailer at
    the end of Part 1's pages which then reverts to chapter-5 content
    before the real chapter-6 starts in Part 2's pages.  Demote the
    false headings to plain body text by prefixing them with a marker
    the walker will re-interpret as text.
    """
    out = list(lines)
    chapter_positions: list[tuple[int, int]] = []
    for i, line in enumerate(out):
        m = CHAPTER_RE.match(line)
        if m:
            chapter_positions.append((i, int(m.group(1))))

    false: set[int] = set()
    for idx, (pos, chapter) in enumerate(chapter_positions):
        # Scan up to the next chapter heading.
        end = chapter_positions[idx + 1][0] if idx + 1 < len(chapter_positions) else len(out)
        for j in range(pos + 1, end):
            m = SECTION_RE.match(out[j])
            if not m:
                continue
            section_top = int(m.group(1).split(".")[0])
            if section_top < chapter:
                false.add(pos)
                break

    if not false:
        return out

    for pos in false:
        out[pos] = f"(demoted-heading) {out[pos]}"
    return out


def normalise_title(title: str) -> str:
    """Collapse runs of whitespace inside a heading title."""
    return re.sub(r"\s+", " ", title).strip()


def detect_heading(line: str, in_appendix: bool = False) -> tuple[int, str, str] | None:
    """
    Return (level, number, title) if the line is a heading, else None.
    Level 1 is a top-level chapter, 2+ are nested sections.
    """
    if in_appendix:
        m = APPENDIX_SECTION_RE.match(line)
        if m:
            number = m.group(1)
            # "A.1" -> level 2 (under the appendix chapter heading)
            depth = 1 + number.count(".")
            return depth, number, normalise_title(m.group(2))
        return None

    m = CHAPTER_RE.match(line)
    if m:
        return 1, m.group(1), normalise_title(m.group(2))
    m = SECTION_RE.match(line)
    if m:
        number = m.group(1)
        depth = number.count(".") + 1        # "4.1" -> 2, "5.4.2" -> 3
        return depth, number, normalise_title(m.group(2))
    return None


def looks_like_code_block(lines: list[str]) -> bool:
    """Heuristic: a block of indented, non-paragraphy text is code."""
    if not lines:
        return False
    # All lines must be indented.
    if any(l and not l.startswith((" ", "\t")) for l in lines):
        return False
    # Consider it code if at least one line has code-like punctuation.
    joined = "\n".join(lines)
    return any(tok in joined for tok in ("PROCEDURE", "BEGIN", "END ", ":=", "MODULE", "CASE", "IF ", "VAR", "CONST"))


def collapse_whitespace(text: str) -> str:
    """Collapse runs of 2+ whitespace characters into a single space.
    PageMaker 3 typeset the report with variable inter-word spacing
    that survives `pdftotext -layout`, so paragraph prose often has
    wide gaps between words.  This is safe for prose; code blocks
    don't go through this step."""
    return re.sub(r"[ \t]{2,}", " ", text)


def split_numbered_list(text: str) -> list[str] | None:
    """
    If `text` is a run-together numbered list like
    "1. Lexical Analysis. 2. Syntax Analysis. 3. Semantic Analysis."
    return a list of Markdown list-item lines.  Otherwise return None.

    Accepts any starting integer (not just 1) so numbered-list
    continuations from an earlier paragraph also split correctly.
    The numbers must be strictly ascending by one for the match to
    succeed — any other numeric pattern (a section reference like
    "section 4.5.2", a citation like "use15") stays intact.
    """
    if not re.match(r"^\d+\.\s+[A-Z]", text):
        return None
    # The split lookahead doesn't require an uppercase letter after
    # "N. " because some list items start with lowercase keywords
    # ("5. if, while and case statements ...").  The "must start
    # with uppercase" constraint only applies to the whole paragraph.
    parts = re.split(r"(?<=[.!?])\s+(?=\d+\.\s+\S)", text)
    if len(parts) < 2:
        return None
    numbers: list[int] = []
    for part in parts:
        m = re.match(r"^(\d+)\.\s", part)
        if not m:
            return None
        numbers.append(int(m.group(1)))
    start = numbers[0]
    if numbers != list(range(start, start + len(numbers))):
        return None
    items = []
    for part in parts:
        m = re.match(r"^(\d+)\.\s+(.*)$", part, re.DOTALL)
        assert m is not None
        items.append(f"{m.group(1)}. {collapse_whitespace(m.group(2)).strip()}")
    return items


def split_bullet_list(text: str) -> list[str] | None:
    """
    Split a run-together bullet list like "* Foo. * Bar. * Baz." into
    one Markdown bullet per line.  Returns None if the text doesn't
    look like one.
    """
    if not text.startswith("*"):
        return None
    parts = re.split(r"(?<=[.!?])\s+(?=\*\s+[A-Z])", text)
    if len(parts) < 2:
        return None
    items = []
    for part in parts:
        m = re.match(r"^\*\s+(.*)$", part, re.DOTALL)
        if m is None:
            return None
        items.append(f"- {collapse_whitespace(m.group(1)).strip()}")
    return items


def paragraphify(body: list[str]) -> list[str]:
    """
    Walk body lines and emit a list of Markdown fragments:

      - Runs of blank lines collapse to a single blank line.
      - Consecutive non-empty lines become a single Markdown paragraph.
        Indented continuation lines (e.g. the wrapped body of a numbered
        list item) fold into the current paragraph as long as there's
        no blank line between them.
      - A block of indented lines that sits on its own — separated from
        surrounding paragraphs by blank lines — is treated as a code
        block or table and wrapped in a triple-backtick fence.  We pick
        the fence language based on a tiny Modula-2 keyword heuristic.
      - "Figure N. Caption" lines are replaced with a Markdown image
        reference when we have a PNG for that figure in FIGURE_IMAGES.
    """
    out: list[str] = []
    buf: list[str] = []
    indented_block: list[str] = []
    have_paragraph_context = False    # last non-blank we saw was part of buf

    def flush_para() -> None:
        nonlocal buf, have_paragraph_context
        if buf:
            paragraph = " ".join(s.strip() for s in buf)
            paragraph = collapse_whitespace(paragraph)
            items = split_numbered_list(paragraph) or split_bullet_list(paragraph)
            if items:
                out.extend(items)
            else:
                # Single-bullet lines (common after wrapped bullet
                # continuation) should start with `- ` not `*`.
                if paragraph.startswith("* ") and re.match(r"^\*\s+[A-Z]", paragraph):
                    paragraph = "- " + paragraph[2:].lstrip()
                out.append(paragraph)
            out.append("")
            buf = []
        have_paragraph_context = False

    def flush_indented_as_code() -> None:
        nonlocal indented_block
        if indented_block:
            # Strip trailing blanks.
            while indented_block and not indented_block[-1].strip():
                indented_block.pop()
            if indented_block:
                lang = "modula-2" if looks_like_code_block(indented_block) else ""
                out.append(f"```{lang}")
                out.extend(indented_block)
                out.append("```")
                out.append("")
            indented_block = []

    for line in body:
        stripped = line.strip()

        fig = FIGURE_RE.match(line)
        if fig and fig.group(1) in FIGURE_IMAGES:
            # Insert a Markdown image reference where the caption was.
            flush_para()
            flush_indented_as_code()
            num = fig.group(1)
            caption = fig.group(2).rstrip(".")
            path, alt = FIGURE_IMAGES[num]
            out.append(f"![{alt}]({path})")
            out.append("")
            out.append(f"*Figure {num}. {caption}*")
            out.append("")
            continue

        if not stripped:
            # Blank line -- close any open paragraph or code block.
            if indented_block:
                flush_indented_as_code()
            flush_para()
            continue

        if line.startswith(("    ", "\t")):
            # Indented content.  If there's an open paragraph with no
            # intervening blank, this is a wrapped continuation line of
            # that paragraph — fold it in.  Otherwise it's a real code
            # block/table.
            if have_paragraph_context and not indented_block:
                buf.append(line.strip())
            else:
                indented_block.append(line)
            continue

        # Unindented line -- a new paragraph, which also means any
        # pending indented block is a standalone code section.
        if indented_block:
            flush_indented_as_code()
        buf.append(line)
        have_paragraph_context = True

    if indented_block:
        flush_indented_as_code()
    flush_para()
    while out and not out[-1].strip():
        out.pop()
    return out


def slugify(number: str, title: str) -> str:
    n = number.zfill(2) if number.isdigit() else number
    t = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return f"{n}-{t}"


def convert(lines: list[str]) -> list[Chapter]:
    """Walk cleaned raw lines, emit a list of Chapter records."""
    chapters: list[Chapter] = []
    current: Chapter | None = None
    in_appendix = False
    # Expect chapters to appear in strict ascending order 1,2,...7.  Any
    # "N. SOMETHING" line whose number isn't next-in-sequence is body
    # text (a list item, a table row, etc.) and shouldn't promote to a
    # chapter heading.  Chapter 1 is the front-matter TOC which we drop.
    expected_chapter = 1

    buf: list[str] = []

    def flush_to_current() -> None:
        if current is None or not buf:
            return
        current.body.extend(paragraphify(buf))
        current.body.append("")

    i = 0
    while i < len(lines):
        line = lines[i]

        if line == "@@APPENDIX_START@@":
            # Flush whatever chapter 7 was collecting and start an 8th
            # pseudo-chapter for the appendix.  From now on headings
            # are detected under APPENDIX_SECTION_RE instead of
            # SECTION_RE.
            flush_to_current()
            in_appendix = True
            chapters.append(
                Chapter(
                    number=8,
                    title="Appendix",
                    slug="08-appendix",
                )
            )
            current = chapters[-1]
            buf = []
            i += 1
            continue

        heading = detect_heading(line, in_appendix=in_appendix)
        if heading:
            level, number, title = heading

            if in_appendix:
                # All appendix headings are nested under the Appendix
                # chapter — they're never chapter-level.
                if current is None:
                    i += 1
                    continue
                flush_to_current()
                buf = []
                marker = "#" * min(level + 1, 6)
                current.body.append(f"{marker} {number}. {title}")
                current.body.append("")
                i += 1
                continue

            if level == 1:
                n = int(number)
                # Strict ascending sequence — any out-of-order "N. X"
                # match is body content (e.g. a numbered list item).
                if n != expected_chapter:
                    buf.append(line)
                    i += 1
                    continue

                # Drop the "1. CONTENTS." chapter — we rebuild the TOC
                # elsewhere, and its body is just a list of dotted links.
                if n == 1 and title.upper().startswith("CONTENTS"):
                    flush_to_current()
                    current = None
                    expected_chapter = 2
                    i += 1
                    # Skip ahead until we see the next chapter heading.
                    while i < len(lines):
                        h2 = detect_heading(lines[i])
                        if h2 and h2[0] == 1 and int(h2[1]) == expected_chapter:
                            break
                        i += 1
                    continue

                flush_to_current()
                chapters.append(
                    Chapter(
                        number=n,
                        title=title.title(),
                        slug=slugify(number, title),
                    )
                )
                current = chapters[-1]
                expected_chapter = n + 1
                buf = []
                i += 1
                continue

            # Section heading: emit as Markdown inside the current chapter.
            if current is None:
                i += 1
                continue
            flush_to_current()
            buf = []
            # Chapter is level 1 -> `#`, section 4.1 is level 2 -> `##`,
            # subsection 5.4.2 is level 3 -> `###`.
            marker = "#" * min(level, 6)
            current.body.append(f"{marker} {number}. {title}")
            current.body.append("")
            i += 1
            continue

        buf.append(line)
        i += 1

    flush_to_current()
    return chapters


APPENDIX_BODY = """\
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
"""


def build_readme(chapters: list[Chapter]) -> str:
    lines = [
        "# m2assem — Final Year Project Report",
        "",
        "Markdown conversion of the 1990 final-year-project report that"
        " originally accompanied this source code.  The PDFs under"
        " [`doc/pdf/`](../pdf/) were produced from the PageMaker 3 sources"
        " and are the canonical form; this tree is a machine-assisted"
        " rendering of the same content for easier online reading.",
        "",
        "The conversion pipeline lives in"
        " [`tools/pdf_to_md.py`](tools/pdf_to_md.py).  Run it from the"
        " project root to regenerate every file under `doc/md/`:",
        "",
        "```sh",
        "python3 doc/md/tools/pdf_to_md.py",
        "```",
        "",
        "## Contents",
        "",
    ]
    for ch in chapters:
        lines.append(f"- [Chapter {ch.number} — {ch.title}]({ch.slug}.md)")
    lines.append("")
    lines.append(
        "The two real figures — the 68000 instruction-format diagram"
        " (Figure 6) and the hash-table performance graph (Figure 30) —"
        " live under [`figures/`](figures/).  Every other \"figure\" in"
        " the original is an ASCII-art table or layout that comes through"
        " verbatim in the Markdown."
    )
    lines.append("")
    return "\n".join(lines)


def write_chapter(ch: Chapter) -> Path:
    path = MD_DIR / f"{ch.slug}.md"
    lines = [f"# Chapter {ch.number}. {ch.title}", ""]
    lines.extend(ch.body)
    path.write_text("\n".join(lines).rstrip() + "\n")
    return path


def extract_figure(
    pdf: Path,
    page: int,
    out: Path,
    crop: tuple[int, int, int, int] | None = None,
) -> None:
    """Render a single PDF page at 300 dpi and crop it.

    `crop` is an optional (x, y, w, h) in pixels applied before the
    ImageMagick trim so we can isolate the figure from the rest of
    the page.  Values are computed against the 300-dpi render
    (roughly 2480×3508 for A4).
    """
    tmp = out.parent / f".tmp-{out.stem}"
    subprocess.run(
        ["pdftoppm", "-r", "300", "-f", str(page), "-l", str(page),
         "-png", str(pdf), str(tmp)],
        check=True,
    )
    cands = sorted(tmp.parent.glob(f"{tmp.name}-*.png"))
    assert cands, "pdftoppm produced no output"
    src = cands[0]

    if not _magick_available():
        src.rename(out)
        return

    cmd = ["magick", str(src)]
    if crop is not None:
        x, y, w, h = crop
        cmd += ["-crop", f"{w}x{h}+{x}+{y}", "+repage"]
    cmd += ["-trim", "+repage",
            "-bordercolor", "white", "-border", "32x32",
            str(out)]
    subprocess.run(cmd, check=True)
    src.unlink()


def _magick_available() -> bool:
    try:
        subprocess.run(["magick", "-version"], check=True, capture_output=True)
        return True
    except (FileNotFoundError, subprocess.CalledProcessError):
        return False


def extract_figures() -> None:
    fig_dir = MD_DIR / "figures"
    fig_dir.mkdir(parents=True, exist_ok=True)

    # Figure 6 — 68000 instruction format diagram — Part 1 page 21.
    # The figure itself sits in the lower 2/3 of the page after the
    # preamble paragraphs; crop to roughly that region before trimming.
    extract_figure(
        PDF_DIR / "FinalYearProject-Part1.pdf",
        21,
        fig_dir / "fig-06-instruction-formats.png",
        crop=(200, 850, 2100, 2300),
    )

    # Figure 30 — Hash-table performance — Part 2 page 2.  The figure
    # is small and near the top of the page; crop to the top half and
    # let -trim tighten from there.
    extract_figure(
        PDF_DIR / "FinalYearProject-Part2.pdf",
        2,
        fig_dir / "fig-30-hash-table-performance.png",
        crop=(200, 400, 2100, 1100),
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--extract-only", action="store_true",
                    help="Run pdftotext and stop before Markdown conversion.")
    ap.add_argument("--skip-figures", action="store_true",
                    help="Skip re-extracting the PNG figures.")
    args = ap.parse_args()

    combined = extract_raw()
    if args.extract_only:
        print(f"wrote raw text under {RAW_DIR}")
        return 0

    if not args.skip_figures:
        extract_figures()

    raw = combined.read_text()
    lines = clean_raw(raw)
    lines = strip_false_chapter_headings(lines)
    chapters = convert(lines)

    if not chapters:
        print("no chapters found — something went wrong", file=sys.stderr)
        return 1

    # The appendix's body is a 120-page source code listing.  Replace
    # it with a curated set of links into src/ instead.
    for ch in chapters:
        if ch.number == 8 and ch.title.lower() == "appendix":
            ch.body = APPENDIX_BODY.splitlines()
            break

    (MD_DIR / "README.md").write_text(build_readme(chapters))
    for ch in chapters:
        path = write_chapter(ch)
        print(f"wrote {path.relative_to(ROOT)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

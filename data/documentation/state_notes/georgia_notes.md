# Georgia Notes

## Source

**File:** `data/raw/georgia/PRC_List_2025.pdf`
**Issuing body:** Georgia Department of Corrections, Publication Review Committee (PRC)
**List name:** PRC Master Denied List (2015-2025)
**List Updated:** 2025-08-06

## Overview

- **Total records:** 339
- **Ban years in data:** 2015-2025 (note, no entries for 2023)
- **Publication types:** 89 books, 250 periodicals
- **Rejection reasons:** Not provided — `rejection_reason` column is empty for all records

## PDF Structure

The source PDF uses a bullet-list format:
- Top-level bullets (`•`) are individual entries or series headers
- Sub-bullets (`o`) are individual books within a named series
- Year headers (e.g., `2024`) delineate ban-year sections
- Series headers (e.g., `The King Series by TM Frazier`) are detected and the series name is prepended to sub-bullet titles

## ETL Logic

`etl/clean_georgia.R` processes the PDF in four passes:

1. **Line classification** — each raw line is tagged as `bullet` (starts with `•`), `sub_bullet` (starts with `o` + space), or `other` before whitespace is trimmed.

2. **Continuation joining** — non-empty `other` lines immediately following a `bullet` or `sub_bullet` are appended to that parent line. Exception: a bare year line (e.g. `2024`) is only absorbed if the parent line ends with a comma (indicating a wrapped sentence), otherwise it starts a new year section.

3. **Year / series context tracking** — a bare 4-digit year line sets `ban_year` for all subsequent records. A `bullet` line containing the word "series" but no publication date is treated as a series header: its author and title prefix are stored and inherited by following `sub_bullet` lines (sub-bullet titles are prefixed as `"Series Name: sub-title"`).

4. **Author extraction** — attempted in priority order:
   - Possessive opener: `"Author's Title"`
   - Explicit `, by Author` (comma before "by")
   - Bare `by Name` with a date immediately following
   - Co-authors: `by Name1, Name2, Month Year`
   - `, author Name` keyword
   - `: Author Published …` colon pattern
   - `Title, Author, Month Day, Year` (last two segments form a date)
   - `Title, Author Month Day, Year` (date embedded in penultimate segment)
   - Single capitalized word at end of string
   - Last resort: `by Name` at end of string (no date required)

5. **Publication type** — classified as `periodical` if the text matches a hardcoded magazine-name list, contains keywords (`issue`, `vol.`, `newsletter`, `magazine`, `quarterly`), ends with `Month Year` (without a "published" qualifier), or contains `#N`. Everything else is `book`.

6. **Title cleaning** — strips leading possessive (`Author's`), balanced wrapping quotes, `: Author Published …` suffixes, `, by Author` or `– by Author` trailers, multi-token `by Author` phrases, and trailing date suffixes (books only; periodicals retain the issue date in the title).

## Schema Notes

- `parent_bullet` is Georgia-specific: for sub-bullet entries (books within a named series), it contains the raw text of the series header bullet. NA for all top-level entries. Present in both `cleaned_georgia.csv` and `data/raw/georgia/source_text_georgia.csv`.
- Raw source text for QA is in `data/raw/georgia/source_text_georgia.csv` (columns: `row`, `pdf_page`, `source_text`, `parent_bullet`), joinable to the processed CSV on `row`.

## Character Encoding

Unicode characters are preserved as they appear in the source PDF — including curly apostrophes (`'` U+2019) and en/em dashes (`–` U+2013, `—` U+2014). No normalization to ASCII equivalents is applied. Pending confirmation from project leaders on whether downstream tools prefer ASCII normalization.

## Known Parsing Limitations

- **"Health, June 2019"** — The magazine is *Men's Health*; because "Men's" was on a prior line in the PDF, "Men" was extracted as the author. The title and date are correct.
- **Jack Olsen entries (2021)** — Two entries appear to be formatted as publisher blurbs rather than standard title/author lines. They were classified as `periodical` due to date-suffix detection but are likely books. Titles include publisher marketing copy.
- **"Worth Rises" entry (2021)** — The full mailing address (`166 Canal Street 6th Floor, New NY 10013`) appears embedded in the title as it was in the source PDF.
- **Periodical dates** — Per the schema, `date` stores the ban year from the section header, not the issue date. Issue dates for periodicals are retained inside the `title` field.
- **Missing authors** — Many periodical entries have no author; this reflects the source data, not a parsing failure.

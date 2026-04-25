# California Notes

- **Source:** [data/raw/california/Disapproved Publications - Family & Friends Services.pdf](<data/raw/california/Disapproved Publications - Family & Friends Services.pdf>)
- **Processed:** [data/processed/cleaned_california.csv](data/processed/cleaned_california.csv)
- **Script:** [etl/clean_california.R](etl/clean_california.R)

## Overview

- **4,320 entries** across 221 PDF pages: 3,120 books, 1,200 periodicals
- No date/year information in the source document (so in `cleaned_california.csv`, `date` column is blank for all rows)

## Source Format

The PDF is a 4-column fixed-width table:

| Column | PDF position (approx.) |
|--------|------------------------|
| Publication (title) | chars 1–22 |
| Author | chars 23–43 |
| Publisher | chars 44–69 |
| Reason for Decision | chars 70–72 to end (varies by page) |

Column positions shift slightly between pages (reason column at ~70–72). The script detects the reason column start per page from "Title 15, Section" anchor strings and derives the publisher start as `reason_start − 28`.

## Schema Notes

- `publisher` is California-specific (not in the standard schema); populated for 4,070 of 4,320 entries.
- Raw source text for QA is in `data/raw/california/source_text_california.csv` (columns: `row`, `pdf_page`, `source_text`), joinable to the processed CSV on `row`.

## Notable Findings

- **Largest list** of any state in the dataset at 4,320 entries.
- **Top rejection reasons** (California Title 15, Section 3006):
  - `3006(c)(17)` — frontal nudity (1,379 entries)
  - `3006(c)(15)(A)` — lacks serious literary, artistic, political or scientific value (1,301 entries)
  - `3006(d)` — presents serious threat to facility security or safety (546 entries)
  - `3006(c)(1)` — violence or physical harm (254 entries)
  - `3006(c)(15)(C)(5)` — STG (Security Threat Group) related (226 entries)
  - `3006(c)(16)` — sexually explicit images (181 entries)
  - `3006(c)(19)` — STG members or associates (146 entries)
- **No author listed** for 1,804 entries (42%); these often have only a publisher.
- One entry uses a non-standard citation format: "CCR, Title 15, 3006(c)(13)" rather than the usual "Title 15, Section 3006(...)".

## Character Encoding

Unicode characters are preserved as they appear in the source PDF — including curly apostrophes (`'` U+2019) and en/em dashes (`–` U+2013, `—` U+2014). No normalization to ASCII equivalents is applied. Pending confirmation from project leaders on whether downstream tools prefer ASCII normalization.

## Parsing Challenges

- **Rows span page breaks**: a table row can be cut mid-cell across a page boundary with no blank line separator. The script detects new entry boundaries by the "Title 15, Section" anchor in the reason column rather than relying solely on blank lines.
- **Author/Publisher column swap**: entry "100 DEADLY SKILLS, SURVIVAL EDITION" lists "Clint Emerson" in the Publisher column instead of the Author column — apparent data entry error in the source. The CSV reflects the source as-is.
- **Single-letter author**: entry "300: THE ART OF THE FILM" (row 29) has author `"F"` — a single letter that appears in the author column of the source PDF. Likely an abbreviation or OCR artifact, but preserved as-is to match the source document.
- **Periodical detection**: relies on keywords (ISSUE, VOL., VOLUME, MAGAZINE, QUARTERLY, ANNUAL, #N) in the title since the source does not distinguish content type.

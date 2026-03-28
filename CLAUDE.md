# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a data collection and standardization project cataloging books banned in US state prison systems, in collaboration with MuckRock's Data Liberation Project and The Marshall Project.

## Repository Structure

- `data/raw/<state_name>/` — Raw source files per state (PDF, Excel, XML, CSV formats)
- `data/processed/` — Cleaned, standardized CSV files (one per state)
- `data/documentation/` — Notes on notable findings per state
- `etl/` — R scripts to extract and clean raw data into the standard format

## Data Pipeline

For each state, the workflow is:
1. Raw source file lives in `data/raw/<state_name>/`
2. An R script in `etl/clean_<state_name>.R` processes it
3. Output goes to `data/processed/cleaned_<state_name>.csv`
4. Notes go in `data/documentation/<state_name>_notes.md`

## Standardized CSV Schema

All processed files must conform to this schema:

| Column | Type | Required | Notes |
|--------|------|----------|-------|
| row | integer | Yes | Sequential row ID (1-based); links to `source_text_{state_name}.csv` where present |
| title | character | Yes | |
| author | character | No | |
| date | character (year only) | No | 4-digit ban year from section header; not the publication date |
| publication_type | character | No | `"book"` or `"periodical"` |
| rejection_reason | character | No | |
| pdf_page | integer | No | Page number in source PDF where the entry begins |

Some states include additional columns beyond the standard schema (e.g. California adds `publisher`). These are documented in the state's notes file.

Where a source document's raw text is preserved for QA, it lives in `data/raw/<state_name>/source_text_{state_name}.csv` with columns `row`, `pdf_page`, and `source_text`. The `row` column joins directly to the processed CSV. Some states add extra columns (e.g. Georgia adds `parent_bullet`).

## States with Data

**Obtained:** California, Connecticut, Florida, Georgia, Illinois, Iowa, Kansas, Michigan, Montana, New Jersey, Texas, Virginia

**Requested, not yet received:** Arizona, Missouri, North Carolina, Oregon, Rhode Island, South Carolina, Wisconsin

## R Setup

Required packages: `pdftools`, `dplyr`, `stringr`, `readr`, `duckdb`

```r
install.packages(c("pdftools", "dplyr", "stringr", "readr", "duckdb"))
```

Run an ETL script from the repo root:
```bash
Rscript etl/clean_georgia.R
```

## PDF Parsing Notes (Georgia)

`etl/clean_georgia.R` uses `pdftools::pdf_text()` to extract lines, then:
- Classifies lines as `bullet` (•), `sub_bullet` (o), or `other`
- Joins wrapped continuation lines to their parent bullet
- Detects year-section headers (e.g. "2024") to set `ban_year`
- Detects series headers (e.g. "The King Series by TM Frazier") and prepends series name to sub-bullet titles
- Classifies `publication_type` as `periodical` vs `book` based on magazine name list and issue/volume keywords

## DuckDB Database

`data/banned_books.duckdb` is built by `etl/build_db.R` — unions all `data/processed/cleaned_*.csv` and `data/raw/*/source_text_*.csv` into two tables (`cleaned_data`, `source_text`), each with a leading `state_name` column. Re-run after any ETL change:
```bash
Rscript etl/clean_<state>.R && Rscript etl/build_db.R
```
QA queries live in `etl/qa_queries.R` (R script using DuckDB SQL).

## Data Fidelity Policy

Preserve source data artifacts as-is in CSVs. Do not silently fix OCR errors, column misalignments, or unusual values. Document anomalies in `data/documentation/<state>_notes.md` under "Known Parsing Limitations".

## ETL Script Conventions

- Use two-phase design: Phase 1 collects blocks/entries, Phase 2 is a pure `parse_block()` function via `lapply`. Avoid `<<-` superassignment.
- `source_text_{state_name}.csv` must include `row` and `pdf_page` columns; `row` joins to the processed CSV.
- State-specific extra columns (e.g. `publisher`, `parent_bullet`) go in both the processed CSV and `source_text_{state_name}.csv`, and must be documented in the state's notes file.

## Placeholder Files

The files `etl/clean_state_name.R`, `data/processed/cleaned_state_name.csv`, and `data/documentation/state_name_notes.md` are templates. When adding a new state, copy and rename these with the actual state name (lowercase, underscores).
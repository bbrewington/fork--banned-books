# State Name Notes

## Source

**File:** `data/raw/state_name/filename.ext`
**Processed:** `data/processed/cleaned_state_name.csv`
**Script:** `etl/clean_state_name.R`
**Issuing body:** [State] Department of Corrections (or relevant agency)
**List name:** [Official name of the list/document]

## Overview

- **Total records:** [N]
- **Ban years in data:** [YYYY–YYYY]
- **Publication types:** [N books, N periodicals]
- **Rejection reasons:** [Provided / Not provided — description]

## Source File Structure

[Describe the format of the raw source file and any structural conventions that informed the ETL script — e.g., bullet hierarchy, section headers, column layout for fixed-width PDFs, XML node structure, spreadsheet layout, etc.]

## Schema Notes

- [List any columns beyond the standard schema, or standard columns that are blank/absent for this state and why.]
- Raw source text for QA is in `data/raw/state_name/source_text_{state_name}.csv` (columns: `row`, `pdf_page`, `source_text`), joinable to the processed CSV on `row`. [Add or remove this line as applicable.]

## Character Encoding

Unicode characters are preserved as they appear in the source document. No normalization to ASCII equivalents is applied. Pending confirmation from project leaders on whether downstream tools prefer ASCII normalization.

## Known Parsing Limitations

- [Describe any entries that were parsed incorrectly or ambiguously, fields that couldn't be extracted, or edge cases where the ETL output may not match the source exactly. Preserve these as-is rather than silently fixing in the script.]

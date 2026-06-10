library(pdftools)
library(dplyr)
library(tidyr)
library(stringr)
library(readr)

pdf_path <- "data/raw/california/Disapproved Publications - Family & Friends Services.pdf"
out_path <- "data/processed/cleaned_california.csv"

# Column x-boundaries (PDF points; consistent across all 221 pages).
# Layout: | title (<108) | author (<188) | publisher (<267) | reason (>=267) |
COL_AUTHOR    <- 108
COL_PUBLISHER <- 188
COL_REASON    <- 267
Y_TOL         <- 3     # words within 3 pts share a visual line

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# A reason is complete when it has both a code reference and a substantial
# description after "–". Short trailing words (< 12 chars) indicate the
# sentence is still mid-stream; trailing comma means a list is still open.
reason_is_complete <- function(reason) {
  if (!str_detect(reason, fixed("–"))) return(FALSE)
  desc <- str_trim(str_split_fixed(reason, "–", 2)[, 2])
  nchar(desc) > 12 &&
    !str_detect(desc, ",\\s*$") &&             # open list
    !str_detect(desc, "\\b(or|and)\\s*$")      # dangling conjunction
}

infer_pub_type <- function(title) {
  if_else(
    str_detect(title, regex(
      "\\b(magazine|quarterly|newsletter|journal|vol\\.|volume\\s+\\d|issue\\b|periodical)\\b",
      ignore_case = TRUE
    )),
    "periodical", ""
  )
}

# Ensure all named columns exist in df, filling absent ones with "".
ensure_cols <- function(df, cols) {
  for (col_name in cols) {
    if (!col_name %in% names(df)) df[[col_name]] <- ""
  }
  df
}

normalize_ligatures <- function(text) {
  text |>
    str_replace_all("ﬀ", "ff") |>
    str_replace_all("ﬁ", "fi") |>
    str_replace_all("ﬂ", "fl") |>
    str_replace_all("ﬃ", "ffi") |>
    str_replace_all("ﬄ", "ffl") |>
    str_replace_all("ﬅ", "st") |>
    str_replace_all("ﬆ", "st")
}

# Convert one page's word-level data frame into a tibble of visual lines.
# Returns: line_y | title | author | publisher | reason
page_to_lines <- function(words_df) {
  if (nrow(words_df) == 0) {
    return(tibble(line_y = numeric(), title = character(),
                  author = character(), publisher = character(), reason = character()))
  }
  words_df |>
    mutate(
      line_y = round(y / Y_TOL) * Y_TOL,
      col    = case_when(
        x <  COL_AUTHOR    ~ "title",
        x <  COL_PUBLISHER ~ "author",
        x <  COL_REASON    ~ "publisher",
        TRUE               ~ "reason"
      )
    ) |>
    mutate(text = normalize_ligatures(text)) |>
    arrange(line_y, x) |>
    group_by(line_y, col) |>
    summarise(cell = paste(text, collapse = " "), .groups = "drop") |>
    pivot_wider(names_from = col, values_from = cell, values_fill = "") |>
    ensure_cols(c("title", "author", "publisher", "reason")) |>
    arrange(line_y) |>
    select(line_y, title, author, publisher, reason)
}

# ---------------------------------------------------------------------------
# Extraction with cross-page merge
# ---------------------------------------------------------------------------

all_pages <- pdf_data(pdf_path)

records  <- list()
pending  <- NULL    # current record awaiting possible continuation
is_new_page <- FALSE

for (page_idx in seq_along(all_pages)) {
  lines       <- page_to_lines(all_pages[[page_idx]])
  is_new_page <- TRUE   # reset at every page boundary

  for (i in seq_len(nrow(lines))) {
    title_raw  <- str_squish(lines$title[i])
    author_raw <- str_squish(lines$author[i])
    pub_raw    <- str_squish(lines$publisher[i])
    reason_raw <- str_squish(lines$reason[i])

    # Skip fully blank lines and the column-header row
    if (nchar(title_raw) == 0 && nchar(author_raw) == 0 && nchar(reason_raw) == 0) next
    if (title_raw == "Publication") next

    starts_title15 <- str_starts(reason_raw, regex("title 15", ignore_case = TRUE))

    if (starts_title15) {
      is_new_page <- FALSE
      norm_title  <- str_trim(title_raw)

      if (!is.null(pending) &&
          !reason_is_complete(pending$rejection_reason) &&
          norm_title == pending$title) {
        # Cross-page duplicate header for the same incomplete record:
        # update reason without emitting the stale truncated pending.
        pending$rejection_reason <- reason_raw
        if (nchar(author_raw) > 0 && nchar(pending$author) == 0)
          pending$author <- author_raw

      } else {
        # Normal new entry: emit whatever was pending, then start fresh.
        if (!is.null(pending)) records <- c(records, list(pending))

        pending <- list(
          title            = norm_title,
          author           = author_raw,
          date             = "",
          publication_type = "",
          rejection_reason = reason_raw
        )
      }

    } else if (!is.null(pending)) {
      # Continuation row.
      # Within a page (is_new_page=FALSE): always extend — this is wrapped cell text.
      # At a page start (is_new_page=TRUE): only extend if the pending reason is
      # still incomplete; otherwise it is a cross-page duplicate fragment → discard.
      if (!is_new_page || !reason_is_complete(pending$rejection_reason)) {
        if (nchar(title_raw) > 0)
          pending$title <- str_squish(paste(pending$title, title_raw))
        if (nchar(author_raw) > 0)
          pending$author <- str_squish(paste(pending$author, author_raw))
        if (nchar(reason_raw) > 0)
          pending$rejection_reason <- str_trim(paste(
            pending$rejection_reason, reason_raw
          ))
      }
      is_new_page <- FALSE
    }
  }
}

if (!is.null(pending)) records <- c(records, list(pending))

# ---------------------------------------------------------------------------
# Assemble and write
# ---------------------------------------------------------------------------

result <- bind_rows(records) |>
  mutate(publication_type = infer_pub_type(title)) |>
  select(title, author, date, publication_type, rejection_reason)

write_csv(result, out_path, na = "")
message("Wrote ", nrow(result), " rows to ", out_path)

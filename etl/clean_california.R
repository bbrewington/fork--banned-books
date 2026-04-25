library(pdftools)
library(dplyr)
library(stringr)
library(readr)

pdf_path      <- "data/raw/california/Disapproved Publications - Family & Friends Services.pdf"
out_path      <- "data/processed/cleaned_california.csv"
out_path_raw  <- "data/raw/california/source_text_california.csv"

# ---------------------------------------------------------------------------
# Column layout (fixed-width text extracted by pdftools)
#   Title:     chars  1 – AUTHOR_START-1        (~22 chars)
#   Author:    chars  AUTHOR_START – publication_start-1 (~19-21 chars, varies with page)
#   Publisher: chars  publication_start  – reason_start-1
#   Reason:    chars  reason_start – end
#
# reason_start is detected per page from "Title 15, Section" line positions.
# publication_start is derived as reason_start - 28 (verified across pages).
# AUTHOR_START is fixed (consistent across all pages).
# ---------------------------------------------------------------------------
AUTHOR_START <- 23L

# Page-1-only header lines to skip
SKIP_PAT <- regex("^(Disapproved|Publications|\\s*Publication\\s+Author)", ignore_case = FALSE)

# ---------------------------------------------------------------------------
# Periodical detection: California source includes many adult/tattoo magazines
# ---------------------------------------------------------------------------
is_periodical <- function(text) {
  str_detect(text, regex(
    "\\b(ISSUE|VOL\\.|VOLUME|MAGAZINE|QUARTERLY|NEWSLETTER|ANNUAL)\\b",
    ignore_case = TRUE
  )) | str_detect(text, "#\\d+")
}

# ---------------------------------------------------------------------------
# Phase 2: pure function — converts one accumulated block into a tibble row
# ---------------------------------------------------------------------------
parse_block <- function(b) {
  title  <- str_squish(paste(b$title,  collapse = " "))
  author <- str_squish(paste(b$author, collapse = " "))
  pub    <- str_squish(paste(b$pub,    collapse = " "))
  reason <- str_squish(paste(b$reason, collapse = " "))

  # Strip the boilerplate "Title 15, Section" prefix from reason text
  reason <- str_remove(reason, regex("^Title 15,\\s*Section\\s*", ignore_case = TRUE))

  if (nchar(title) <= 1L) return(NULL)

  tibble(
    title            = title,
    author           = if (nchar(author) > 0) author else NA_character_,
    publisher        = if (nchar(pub)    > 0) pub    else NA_character_,
    date             = NA_character_,
    publication_type = if (is_periodical(title)) "periodical" else "book",
    rejection_reason = if (nchar(reason) > 0) reason else NA_character_,
    pdf_page         = b$page
  )
}

# ---------------------------------------------------------------------------
# Phase 1: walk all pages, collecting column-extracted content into blocks.
# A block is a named list of four character vectors (one per column).
# Blocks are separated by blank lines or by a new "Title 15, Section" signal.
# ---------------------------------------------------------------------------
raw_pages    <- pdf_text(pdf_path)
new_block    <- function() list(title = character(), author = character(),
                                pub   = character(), reason = character(),
                                raw   = character(), page  = NA_integer_)
blocks       <- list()
cur          <- new_block()
has_content  <- FALSE
reason_start <- 72L   # default; updated per-page from "Title 15, Section" positions
publication_start    <- reason_start - 28L

for (page_num in seq_along(raw_pages)) {
  lines <- strsplit(raw_pages[[page_num]], "\n")[[1]]

  # Calibrate reason_start (and derived publication_start) from "Title 15, Section" lines on this page
  title15_lines <- lines[str_detect(lines, fixed("Title 15, Section"))]
  title15_pos   <- regexpr("Title 15", title15_lines, fixed = TRUE)
  title15_pos   <- title15_pos[title15_pos > 1L]
  if (length(title15_pos) > 0L) {
    reason_start <- as.integer(median(title15_pos))
    publication_start    <- reason_start - 28L
  }

  for (line in lines) {
    # Skip page-1 header rows
    if (str_detect(line, SKIP_PAT)) next

    # Blank line = entry boundary
    if (str_trim(line) == "") {
      if (has_content) {
        blocks      <- c(blocks, list(cur))
        cur         <- new_block()
        has_content <- FALSE
      }
      next
    }

    n <- nchar(line)

    title_part  <- str_trim(substr(line, 1L,           min(n, AUTHOR_START - 1L)))
    author_part <- str_trim(substr(line, AUTHOR_START,   min(n, publication_start - 1L)))
    pub_part    <- str_trim(substr(line, publication_start,    min(n, reason_start - 1L)))
    reason_part <- str_trim(substr(line, reason_start, n))

    # "Title 15, Section" in the reason column signals the start of a new entry.
    # This handles page breaks where two entries are adjacent with no blank line.
    has_new_reason <- str_starts(reason_part, fixed("Title 15, Section"))
    if (has_new_reason && has_content) {
      blocks      <- c(blocks, list(cur))
      cur         <- new_block()
      has_content <- FALSE
    }

    if (nchar(title_part) > 0L || nchar(author_part) > 0L ||
        nchar(pub_part)   > 0L || nchar(reason_part) > 0L) {
      if (is.na(cur$page))           cur$page   <- page_num
      if (nchar(title_part)  > 0L)  cur$title  <- c(cur$title,  title_part)
      if (nchar(author_part) > 0L)  cur$author <- c(cur$author, author_part)
      if (nchar(pub_part)    > 0L)  cur$pub    <- c(cur$pub,    pub_part)
      if (nchar(reason_part) > 0L)  cur$reason <- c(cur$reason, reason_part)
      cur$raw     <- c(cur$raw, line)
      has_content <- TRUE
    }
  }
}

# Flush any trailing entry not terminated by a blank line
if (has_content) blocks <- c(blocks, list(cur))

# ---------------------------------------------------------------------------
# Phase 2: parse all blocks into rows, then assemble and write
# ---------------------------------------------------------------------------
parsed <- Filter(Negate(is.null), lapply(blocks, function(b) {
  row <- parse_block(b)
  if (is.null(row)) return(NULL)
  row$source_text <- paste(b$raw, collapse = "\n")
  row
}))

full <- bind_rows(parsed) |>
  mutate(
    title     = str_squish(title),
    author    = str_squish(author),
    publisher = str_squish(publisher)
  ) |>
  filter(nchar(title) > 1)

write_csv(select(full, -source_text) |> mutate(row = seq_len(nrow(full)), .before = 1), out_path, na = "")
message("Wrote ", nrow(full), " rows to ", out_path)

write_csv(tibble(row = seq_len(nrow(full)), pdf_page = full$pdf_page, source_text = full$source_text), out_path_raw, na = "")
message("Wrote ", nrow(full), " rows to ", out_path_raw)

library(duckdb)
library(dplyr)
library(readr)
library(stringr)

db_path <- "data/banned_books.duckdb"

# Remove existing DB so we always build fresh
if (file.exists(db_path)) file.remove(db_path)
con <- dbConnect(duckdb(), db_path)

# ---------------------------------------------------------------------------
# cleaned_data: union all data/processed/cleaned_<state>.csv
# Skip the empty template file (cleaned_state_name.csv)
# ---------------------------------------------------------------------------
cleaned_files <- setdiff(
  Sys.glob("data/processed/cleaned_*.csv"),
  "data/processed/cleaned_state_name.csv"
)

cleaned <- bind_rows(lapply(cleaned_files, function(f) {
  state <- basename(f) |> str_remove("^cleaned_") |> str_remove("\\.csv$")
  read_csv(f, show_col_types = FALSE) |> mutate(state_name = state, .before = 1)
}))

dbWriteTable(con, "cleaned_data", cleaned, overwrite = TRUE)
message("cleaned_data: ", nrow(cleaned), " rows from ", length(cleaned_files), " states")

# ---------------------------------------------------------------------------
# source_text: union all data/raw/<state>/source_text_{state_name}.csv
# ---------------------------------------------------------------------------
raw_files <- Sys.glob("data/raw/*/source_text_*.csv")

source <- bind_rows(lapply(raw_files, function(f) {
  state <- basename(dirname(f))
  read_csv(f, show_col_types = FALSE) |> mutate(state_name = state, .before = 1)
}))

dbWriteTable(con, "source_text", source, overwrite = TRUE)
message("source_text:  ", nrow(source), " rows from ", length(raw_files), " states")

dbDisconnect(con)
message("Written to ", db_path)

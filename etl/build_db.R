library(RSQLite)
library(duckdb)

# ---------------------------------------------------------------------------
# Build DuckDB via native glob queries
# cleaned_data: union all data/processed/cleaned_<state>.csv
#   (skip the empty template file cleaned_state_name.csv)
# source_text: union all data/raw/<state>/source_text_{state_name}.csv
# union_by_name = true handles states with extra columns (e.g. CA: publisher)
# ---------------------------------------------------------------------------

duckdb_db_path <- "data/banned_books.duckdb"
if (file.exists(duckdb_db_path)) file.remove(duckdb_db_path)
con_duckdb <- dbConnect(duckdb(), dbdir = duckdb_db_path)

dbExecute(con_duckdb, "
  CREATE TABLE cleaned_data AS
  SELECT
    regexp_extract(filename, 'cleaned_([^/]+)\\.csv$', 1) AS state_name,
    * EXCLUDE (filename)
  FROM read_csv('data/processed/cleaned_*.csv', filename = true, union_by_name = true)
  WHERE filename NOT LIKE '%cleaned_state_name.csv'
")

dbExecute(con_duckdb, "
  CREATE TABLE source_text AS
  SELECT
    regexp_extract(filename, '/([^/]+)/source_text_', 1) AS state_name,
    * EXCLUDE (filename)
  FROM read_csv('data/raw/*/source_text_*.csv', filename = true, union_by_name = true)
")

# ---------------------------------------------------------------------------
# Build SQLite by reading back from DuckDB
# ---------------------------------------------------------------------------

sqlite_db_path <- "data/banned_books.sqlite"
if (file.exists(sqlite_db_path)) file.remove(sqlite_db_path)
con_sqlite <- dbConnect(drv = SQLite(), dbname = sqlite_db_path)

dbWriteTable(con_sqlite, "cleaned_data", dbReadTable(con_duckdb, "cleaned_data"))
dbWriteTable(con_sqlite, "source_text",  dbReadTable(con_duckdb, "source_text"))

dbDisconnect(con_sqlite)
dbDisconnect(con_duckdb)

# ---------------------------------------------------------------------------
# Print out helper message for data usage
# ---------------------------------------------------------------------------

message("\nTo explore with datasette:\n\n$ datasette ", sqlite_db_path)

message(
  "\n-----------------------------------------\n\n",
  "To explore with DuckDB:\n\n",
  "option 1 (preferred): duckdb UI\n-------------------------------\n",
  "$ duckdb ", duckdb_db_path, " -ui\n",
  "(query data in browser in the DuckDB UI)\n",
  "D .quit\n\n",
  "option 2: query via DuckDB CLI\n------------------------------\n",
  "$ duckdb ", duckdb_db_path,
  "\nD select * from cleaned_data;\nD .quit"
)
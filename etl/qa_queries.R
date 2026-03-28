library(duckdb)

con <- dbConnect(duckdb(), "data/banned_books.duckdb", read_only = TRUE)
run <- function(label, sql) {
  cat("\n###", label, "###\n")
  print(dbGetQuery(con, sql))
}

# ---------------------------------------------------------------------------
# Overview
# ---------------------------------------------------------------------------
run("Row counts by state",
  "SELECT state_name, COUNT(*) AS n
   FROM cleaned_data
   GROUP BY state_name ORDER BY n DESC")

run("publication_type by state",
  "SELECT state_name, publication_type, COUNT(*) AS n
   FROM cleaned_data
   GROUP BY state_name, publication_type ORDER BY state_name, publication_type")

run("Ban year distribution by state",
  "SELECT state_name, date, COUNT(*) AS n
   FROM cleaned_data
   WHERE date IS NOT NULL
   GROUP BY state_name, date ORDER BY state_name, date")

# ---------------------------------------------------------------------------
# Completeness checks
# ---------------------------------------------------------------------------
run("Missing author rate by state",
  "SELECT state_name,
          COUNT(*) AS total,
          SUM(CASE WHEN author IS NULL THEN 1 ELSE 0 END) AS missing_author,
          ROUND(100.0 * SUM(CASE WHEN author IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_missing
   FROM cleaned_data GROUP BY state_name")

run("Entries without a source_text row",
  "SELECT c.state_name, c.row, c.title
   FROM cleaned_data c
   LEFT JOIN source_text s USING (state_name, row)
   WHERE s.row IS NULL
   ORDER BY c.state_name, c.row")

# ---------------------------------------------------------------------------
# Parse quality checks
# ---------------------------------------------------------------------------
run("Suspiciously short author values (possible column bleed)",
  "SELECT state_name, row, title, author
   FROM cleaned_data
   WHERE LENGTH(author) <= 2
   ORDER BY state_name, row")

run("CA: rejection_reason still contains 'Title 15' (parse error check)",
  "SELECT row, title, rejection_reason
   FROM cleaned_data
   WHERE state_name = 'california'
     AND rejection_reason LIKE '%Title 15%'
     AND rejection_reason NOT LIKE 'CCR%'")

# ---------------------------------------------------------------------------
# Duplicate detection
# ---------------------------------------------------------------------------
run("Duplicate titles within a state",
  "SELECT state_name, title, COUNT(*) AS n
   FROM cleaned_data
   GROUP BY state_name, title HAVING n > 1
   ORDER BY state_name, n DESC, title")

run("Cross-state duplicate titles",
  "SELECT title,
          COUNT(DISTINCT state_name) AS n_states,
          STRING_AGG(state_name, ', ' ORDER BY state_name) AS in_states
   FROM cleaned_data
   GROUP BY title HAVING n_states > 1
   ORDER BY n_states DESC, title")

# ---------------------------------------------------------------------------
# Spot-check: join cleaned_data to source_text
# ---------------------------------------------------------------------------
run("Spot-check: source text for entries matching '%DEADLY SKILLS%'",
  "SELECT c.state_name, c.row, c.title, c.author, s.source_text
   FROM cleaned_data c
   JOIN source_text s USING (state_name, row)
   WHERE c.title LIKE '%DEADLY SKILLS%'")

dbDisconnect(con)

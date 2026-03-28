# Entity Relationship Diagram

Shows the per-state source CSV columns, the unified DuckDB tables they feed into, and how the tables relate.

```mermaid
erDiagram
    CALIFORNIA_CLEANED {
        int    row              PK
        string title
        string author
        string publisher
        string date
        string publication_type
        string rejection_reason
        int    pdf_page
    }
    GEORGIA_CLEANED {
        int    row              PK
        string title
        string author
        string date
        string publication_type
        string rejection_reason
        int    pdf_page
        string parent_bullet
    }
    CALIFORNIA_SOURCE_TEXT {
        int    row         FK
        int    pdf_page
        string source_text
    }
    GEORGIA_SOURCE_TEXT {
        int    row          FK
        int    pdf_page
        string source_text
        string parent_bullet
    }
    `DuckDB: cleaned_data` {
        string state_name       PK
        int    row              PK
        string title
        string author
        string publisher
        string date
        string publication_type
        string rejection_reason
        int    pdf_page
        string parent_bullet
    }
    `DuckDB: source_text` {
        string state_name   PK
        int    row          PK
        int    pdf_page
        string source_text
        string parent_bullet
    }
    CALIFORNIA_CLEANED     ||--o{ `DuckDB: cleaned_data` : "unioned into"
    GEORGIA_CLEANED        ||--o{ `DuckDB: cleaned_data` : "unioned into"
    CALIFORNIA_SOURCE_TEXT ||--o{ `DuckDB: source_text`  : "unioned into"
    GEORGIA_SOURCE_TEXT    ||--o{ `DuckDB: source_text`  : "unioned into"
    `DuckDB: cleaned_data` ||--o| `DuckDB: source_text`  : "state_name + row"
```

## Column notes

| Column | Standard? | States |
|--------|-----------|--------|
| `row` | Yes | All |
| `title` | Yes | All |
| `author` | Yes | All |
| `date` | Yes | All (blank for CA — no year info in source) |
| `publication_type` | Yes | All |
| `rejection_reason` | Yes | All (blank for GA — not provided in source) |
| `pdf_page` | Yes | All |
| `publisher` | CA only | California |
| `parent_bullet` | GA only | Georgia (series header text for sub-bullet entries) |
| `source_text` | source_text table only | CA, GA |

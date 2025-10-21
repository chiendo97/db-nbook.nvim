# Database Notebook

> Interactive database query interface in markdown format
> Save this buffer to preserve your queries and results

## Connection Settings

```bash
# Database connection URI
# Formats:
#   SQLite: sqlite://:memory: or sqlite:///path/to/database.db
#   PostgreSQL: postgresql://user:password@host:port/database
#   ClickHouse: clickhouse://user:password@host:port/database
#   Redis: redis://password@host:port/db
sqlite:///tmp/foo.db
```

Detected Database Type: sqlite

## Queries
> Edit the SQL in the code blocks below
> Press <CR> on [Execute Query N] to run that query

### Query 1

```sql
CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT);
INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com');
INSERT INTO users (name, email) VALUES ('Bob', 'bob@example.com');
INSERT INTO users (name, email) VALUES ('Charlie', 'charlie@example.com');
```

Status: Idle


### Query 2

```sql
SELECT * FROM users;
```

Status: Idle


### Query 3

```sql
SELECT sqlite_version();
```

Status: Idle


[+ Add New Query - Press <CR>]

## Tips
- Edit connection URI in the bash code block
- Edit queries in the sql code blocks
- Press <CR> on [Execute Query N] to run a specific query
- Press <CR> on [+ Add New Query] to add more queries
- Save this buffer with :w to preserve your work
- Results appear in json code blocks below each query
- Supported: SQLite (default), PostgreSQL, ClickHouse, Redis


# Database Query TUI

An interactive terminal user interface for querying databases directly from Neovim, built with morph.nvim.

## Features

- **Dual Buffer Layout**: Separate buffers for query input and results
- **Multi-Database Support**: ClickHouse, PostgreSQL, and Redis
- **Live Editing**: Edit database URI and queries with instant feedback
- **Async Execution**: Non-blocking query execution with status updates
- **TSV Output**: Results displayed in tab-separated format

## Usage

### Launch the TUI

```vim
:luafile examples/database-query.lua
```

Or from the command line:

```bash
nvim -c "luafile examples/database-query.lua"
```

### Interface Layout

```
┌─────────────────────────────┬─────────────────────────────┐
│ Database Query Interface    │ Query Results               │
│                             │                             │
│ ## Database URI             │ ## Status: Waiting          │
│ postgresql://...            │                             │
│                             │ ## Output (TSV Format)      │
│ Detected DB Type: postgres  │ Query results will appear   │
│                             │ here...                     │
│ ## SQL Query                │                             │
│ SELECT * FROM users         │                             │
│ LIMIT 10;                   │                             │
│                             │                             │
│ [Execute Query - Press <CR>]│                             │
│                             │                             │
│ ## Status                   │                             │
│ Ready                       │                             │
└─────────────────────────────┴─────────────────────────────┘
```

### Workflow

1. **Edit Database URI**: Position cursor on the URI line and edit the connection string
1. **Edit Query**: Position cursor on the query text and modify your SQL
1. **Execute**: Navigate to `[Execute Query - Press <CR>]` and press Enter
1. **View Results**: Results appear in the right buffer in TSV format

## Database Connection Formats

### PostgreSQL

```
postgresql://username:password@hostname:5432/database
```

Example:

```
postgresql://postgres:secret@localhost:5432/myapp
```

Commands used: `psql`

### ClickHouse

```
clickhouse://username:password@hostname:9000/database
```

Example:

```
clickhouse://default:password@localhost:9000/analytics
```

Commands used: `clickhouse-client`

### Redis

```
redis://password@hostname:6379/0
```

Or without password:

```
redis://hostname:6379/0
```

Example:

```
redis://localhost:6379/0
```

Commands used: `redis-cli`

## Required Dependencies

Install the appropriate database CLI tools:

### macOS (Homebrew)

```bash
brew install postgresql       # For PostgreSQL
brew install clickhouse       # For ClickHouse
brew install redis            # For Redis
```

### Ubuntu/Debian

```bash
apt-get install postgresql-client    # For PostgreSQL
apt-get install clickhouse-client    # For ClickHouse
apt-get install redis-tools          # For Redis
```

### Arch Linux

```bash
pacman -S postgresql-libs    # For PostgreSQL
pacman -S clickhouse         # For ClickHouse
pacman -S redis              # For Redis
```

## Example Queries

### PostgreSQL

```sql
-- List all tables
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';

-- Count rows
SELECT COUNT(*) FROM users;

-- Complex query
SELECT u.name, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.name
ORDER BY order_count DESC
LIMIT 10;
```

### ClickHouse

```sql
-- Show databases
SHOW DATABASES;

-- Describe table
DESCRIBE TABLE events;

-- Aggregation query
SELECT
    toDate(timestamp) as date,
    COUNT(*) as events
FROM events
WHERE date >= today() - 7
GROUP BY date
ORDER BY date;
```

### Redis

```
-- Get key
GET mykey

-- List all keys
KEYS *

-- Get hash
HGETALL user:1001

-- Set with expiry
SET session:abc123 "user_data" EX 3600
```

## Keybindings

- `<CR>` on `[Execute Query]` - Execute the current query
- `q` in either buffer - Close the buffer
- Standard Vim editing keys work in the URI and query fields

## Implementation Details

### Cross-Buffer Communication

The TUI uses a shared state mechanism to communicate between the query and result buffers:

```lua
local shared_state = {
  result_ctx = nil,  -- Stores the ResultBuffer's context
}
```

When QueryBuffer executes a query, it updates the ResultBuffer through this shared context.

### Async Query Execution

Queries are executed using `vim.fn.jobstart()` to avoid blocking the UI:

```lua
execute_query(db_type, uri, query, function(success, result)
  vim.schedule(function()
    -- Update UI with results
  end)
end)
```

### Component Architecture

- **QueryBuffer**: Manages URI, query input, and execution
- **ResultBuffer**: Displays query results and status
- **Shared State**: Enables cross-buffer component communication

## Limitations

- Raw command-line tool invocation (passwords visible in process list)
- No query history
- No connection pooling
- JSON format only
- No transaction support
- Limited error handling for malformed queries

## Future Enhancements

- [ ] Connection history and favorites
- [ ] Query history with up/down navigation
- [ ] Result formatting options (table, JSON, CSV)
- [ ] Query templates and snippets
- [ ] SSL/TLS connection support
- [ ] Connection testing before query execution
- [ ] Result pagination for large datasets
- [ ] Export results to file
- [ ] Syntax highlighting for SQL queries
- [ ] Auto-completion for table/column names

## Security Considerations

⚠️ **Warning**: This is a development tool. Connection strings with passwords are:

- Visible in process lists
- Stored in memory as plain text
- Not encrypted

For production databases:

- Use environment variables or credential files
- Implement proper authentication methods
- Consider using connection profiles instead of raw URIs

## License

MIT - See parent repository license

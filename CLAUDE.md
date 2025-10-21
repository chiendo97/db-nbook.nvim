# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**db-nbook.nvim** is a Neovim plugin that provides an interactive database query interface built on top of morph.nvim. It presents as a saveable markdown notebook where users can edit connection URIs and SQL queries, execute them asynchronously, and view results inline.

## Architecture

### Component System

The plugin uses the morph.nvim framework's component-based architecture with reactive state management:

- **DatabaseNotebook Component** (`lua/db-nbook.lua:226-387`): Root component that manages global state including connection URI, database type detection, and all query blocks
- **QueryBlock Component** (`lua/db-nbook.lua:154-219`): Reusable component for individual query blocks with their own execution state (idle/running/success/error) and results

### State Management

State flows top-down through the component tree:
- Root state stored in `DatabaseNotebook.state` contains `connection_uri`, `db_type`, `queries` table, and `query_states`
- State updates trigger re-renders via `ctx:update()` calls
- Child components (QueryBlock) receive props from parent and manage local execution state

### Database Execution Layer

The `on_execute()` function (`lua/db-nbook.lua:55-146`) handles multi-database support:
- Parses connection URIs to extract credentials and connection parameters
- Constructs CLI commands for each database type (sqlite3, psql, clickhouse-client, redis-cli)
- Uses `vim.fn.jobstart()` for non-blocking async execution
- Results are returned via callbacks and wrapped in `vim.schedule()` for UI updates

Supported databases:
- **SQLite**: Uses `sqlite3 -json` command
- **PostgreSQL**: Uses `psql` with `--tuples-only --json` flags
- **ClickHouse**: Uses `clickhouse-client` with `--format=JSONEachRow`
- **Redis**: Uses `redis-cli` (handles both authenticated and non-authenticated connections)

### Rendering System

The plugin uses morph.nvim's virtual DOM-like system:
- Components return Lua tables describing buffer content
- `h()` function creates virtual elements with highlight groups (e.g., `h.Title`, `h.Comment`, `h.ErrorMsg`)
- Special `h("text", {on_change, nmap}, content)` elements enable editable regions with change handlers and keybindings
- Buffer content is rendered as markdown with syntax highlighting via `filetype = "markdown"`

## Key Implementation Details

### Cross-Component Communication

Queries are stored in a flat table structure indexed by query ID:
```lua
state.queries = {
  [1] = "SELECT * FROM users;",
  [2] = "SELECT COUNT(*) FROM orders;",
}
```

The `update_query()` handler (`lua/db-nbook.lua:256-274`) serves dual purpose:
- Without callback: Updates query text in state
- With callback: Executes query via `on_execute()` and invokes callback with results

### Buffer Configuration

The notebook buffer is configured as a normal, saveable buffer:
- `buftype = ""` (normal buffer, not special)
- `filetype = "markdown"` (enables syntax highlighting)
- `buflisted = true` (appears in buffer list)
- `bufhidden = "hide"` (preserves content when hidden)

### Dynamic Query Addition

The `add_query()` function (`lua/db-nbook.lua:278-297`) generates context-aware default queries based on detected database type (e.g., `SELECT sqlite_version()` for SQLite, `KEYS *` for Redis).

## Development Commands

### Running the Plugin

```bash
# Open the notebook interface
nvim -c "luafile lua/db-nbook.lua"

# Or from within Neovim
:luafile lua/db-nbook.lua
```

### Testing Database Connections

The plugin requires CLI tools to be installed:

```bash
# macOS
brew install postgresql clickhouse redis sqlite

# Ubuntu/Debian
apt-get install postgresql-client clickhouse-client redis-tools sqlite3

# Arch Linux
pacman -S postgresql-libs clickhouse redis sqlite
```

## Extension Points

### Adding New Database Types

To add support for a new database:
1. Add URI pattern matching in `detect_db_type()` (`lua/db-nbook.lua:37-48`)
2. Add command construction logic in `on_execute()` (`lua/db-nbook.lua:55-146`)
3. Ensure the CLI tool outputs JSON format or add parsing logic
4. Add default query template in `add_query()` (`lua/db-nbook.lua:278-297`)

### Customizing UI Elements

Highlight groups used for rendering (defined by morph.nvim):
- `h.Title` - Section headers
- `h.Comment` - Help text and code block delimiters
- `h.String` - Success status
- `h.ErrorMsg` - Error status and invalid states
- `h.WarningMsg` - Running/in-progress status
- `h.Keyword` - Interactive buttons

## Important Constraints

### Security Considerations

Connection strings are passed directly to shell commands:
- Passwords visible in process lists
- No encryption or credential management
- Suitable for development/local databases only

### Async Execution Model

All database queries use `vim.fn.jobstart()`:
- Callbacks must use `vim.schedule()` for UI updates
- State updates during async operations require careful handling to avoid race conditions
- Exit codes may not always indicate failure (see line 143 comment)

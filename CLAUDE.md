# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**db-nbook.nvim** is a Neovim plugin that provides an interactive database query interface built on top of morph.nvim. It presents as a saveable markdown notebook where users can edit connection URIs and SQL queries, execute them asynchronously, and view results inline.

## Project Structure

```
db-nbook.nvim/
├── lua/
│   └── db-nbook/
│       └── init.lua          # Main plugin implementation
├── plugin/
│   └── db-nbook.lua          # Plugin registration and :DBNBook command
├── database-notebook.md      # Example/template notebook file
└── README.md
```

## Running the Plugin

### From Neovim

```vim
" Create a new notebook with default state
:DBNBook

" Load state from a JSON file
:DBNBook path/to/state.json
```

This is the primary way to launch the plugin. It creates a new temporary markdown buffer with the database notebook interface.

### Saving State

The buffer is configured as a temporary buffer (`buftype=nofile`), so it's not directly tied to a file. To save your work:

```vim
" Save state to JSON (will prompt for filename if not loading from a file)
:w

" Or use the keymap
<leader>s
```

The state is saved as JSON with the following structure:
```json
{
  "connection_uri": "sqlite:///tmp/foo.db",
  "db_type": "sqlite",
  "queries": {
    "1": "SELECT * FROM users;",
    "2": "SELECT COUNT(*) FROM orders;"
  }
}
```

### For Development/Testing

```bash
# Test the main module directly
nvim -c "lua require('db-nbook').db_nbook()"

# Test with a state file
nvim -c "lua require('db-nbook').db_nbook('test-state.json')"

# Or load and test interactively
nvim -c "luafile lua/db-nbook/init.lua"
```

## Architecture

### Component System

The plugin uses the morph.nvim framework's component-based architecture with reactive state management:

- **DatabaseNotebook Component** (`lua/db-nbook/init.lua:271-286`): Root component that manages global state including connection URI, database type detection, and all query blocks. Accepts `default_state`, `filepath`, and `bufnr` as props.
- **QueryBlock Component** (`lua/db-nbook/init.lua:155-264`): Reusable component for individual query blocks with their own execution state (idle/running/success/error) and results

### State Management

State initialization and flow:
- **Initialization**: State is initialized in `db_nbook()` function (`lua/db-nbook/init.lua:438-522`)
  - If `filepath` provided: loads state from JSON file via `load_state_from_file()`
  - If no `filepath` or load fails: passes `nil` as `default_state`, triggering default state creation in DatabaseNotebook component
- **Component Props**: DatabaseNotebook receives `default_state`, `filepath`, and `bufnr` as props
- **Mount Phase**: During mount, component uses `default_state` if provided, otherwise creates default state with sample SQLite queries
- **State Updates**: State updates trigger re-renders via `ctx:update()` calls
- Child components (QueryBlock) receive props from parent and manage local execution state

### Database Execution Layer

The `on_execute()` function (`lua/db-nbook/init.lua:56-147`) handles multi-database support:
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

The `update_query()` handler (`lua/db-nbook/init.lua:257-276`) serves dual purpose:
- Without callback: Updates query text in state
- With callback: Executes query via `on_execute()` and invokes callback with results

### Buffer Configuration

The notebook buffer is configured as a temporary buffer with state persistence:
- `buftype = "nofile"` (temporary buffer, not tied to a file)
- `filetype = "markdown"` (enables syntax highlighting)
- `buflisted = true` (appears in buffer list)
- `bufhidden = "hide"` (preserves content when hidden)

### State Persistence

State is persisted to JSON files via a `BufWriteCmd` autocmd set up in `db_nbook()` function (`lua/db-nbook/init.lua:472-512`):
- Autocmd is registered after mounting the component with access to `morph_instance.root_state`
- `:w` triggers JSON serialization of the current state from `morph_instance.root_state`
- State includes: `connection_uri`, `db_type`, and `queries` table (serialized via `serialize_state()` at line 38-44)
- Prompts for filename on first save if not loaded from a file
- Subsequent saves overwrite the same file automatically
- The autocmd callback has closure access to both `morph_instance` and `bufnr`

### Dynamic Query Addition

The `add_query()` function (`lua/db-nbook/init.lua:279-298`) generates context-aware default queries based on detected database type (e.g., `SELECT sqlite_version()` for SQLite, `KEYS *` for Redis).

## Required Dependencies

The plugin requires CLI tools to be installed for database connectivity:

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
1. Add URI pattern matching in `detect_db_type()` (`lua/db-nbook/init.lua:38-49`)
2. Add command construction logic in `on_execute()` (`lua/db-nbook/init.lua:56-147`)
3. Ensure the CLI tool outputs JSON format or add parsing logic
4. Add default query template in `add_query()` (`lua/db-nbook/init.lua:279-298`)

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
- Exit codes may not always indicate failure (see line 144 comment)

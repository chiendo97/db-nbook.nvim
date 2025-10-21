--[[
Database Notebook - Interactive Database Query Interface in Markdown Format

This example demonstrates:
- Single-buffer markdown-based interface
- Editable code blocks for connection settings and queries
- Multiple query support with individual execution
- Saveable to local filesystem
- Text change detection and parsing

To run this example:
1. Open this file in Neovim
2. Execute: :luafile %
3. A markdown buffer will open with three sections
4. Edit the bash block for connection settings
5. Edit the sql block for your query
6. Press <CR> on [Execute] to run a query
7. Save the file with :w to preserve your queries

Database URI formats:
- SQLite: sqlite://path/to/database.db or sqlite://:memory:
- ClickHouse: clickhouse://user:password@host:port/database
- PostgreSQL: postgresql://user:password@host:port/database
- Redis: redis://password@host:port/db
--]]
local Morph = require("morph")
local Sources = require("db-nbook.sources")
local h = Morph.h
local M = {}

--------------------------------------------------------------------------------
-- State Serialization
--------------------------------------------------------------------------------

-- Utility function to parse database type from URI
--- @param uri string
--- @return 'sqlite'|'clickhouse'|'postgresql'|'redis'|nil
local function detect_db_type(uri)
	return Sources.detect(uri)
end

-- Serialize state to JSON
--- @param state table
--- @return string
local function serialize_state(state)
	return vim.fn.json_encode({
		connection_uri = state.connection_uri,
		db_type = state.db_type,
		queries = state.queries,
	})
end

-- Deserialize state from JSON
--- @param json_str string
--- @return table|nil
local function deserialize_state(json_str)
	local ok, data = pcall(vim.fn.json_decode, json_str)
	if not ok then
		return nil
	end
	local connection_uri = data.connection_uri or "sqlite://:memory:"
	local db_type = data.db_type or detect_db_type(connection_uri)
	return {
		connection_uri = connection_uri,
		db_type = db_type,
		queries = data.queries or { [1] = Sources.default_query(db_type) },
		query_states = {},
	}
end

-- Load state from file
--- @param filepath string
--- @return table|nil
local function load_state_from_file(filepath)
	local file = io.open(filepath, "r")
	if not file then
		return nil
	end
	local content = file:read("*all")
	file:close()
	return deserialize_state(content)
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

-- Execute database query based on DB type
--- @param db_type 'sqlite'|'clickhouse'|'postgresql'|'redis'
--- @param uri string
--- @param query string
--- @param callback fun(success: boolean, result: string)
local function on_execute(db_type, uri, query, callback)
	local source = Sources.get(db_type)
	if not source then
		callback(false, "Unsupported database type")
		return
	end

	local cmd, err = source.build_command(uri, query)
	if not cmd then
		callback(false, err or "Failed to build execution command")
		return
	end

	vim.notify("Executing command: " .. cmd, vim.log.levels.INFO, { title = "Database Notebook" })

	-- Execute command asynchronously
	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				local result = table.concat(data, "\n")
				callback(true, result)
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 then
				local error = table.concat(data, "\n")
				if error ~= "" then
					callback(false, "Error: " .. error)
				end
			end
		end,
	})
end

--------------------------------------------------------------------------------
-- Query Block Component
--------------------------------------------------------------------------------

-- Represents a single executable query block
local function QueryBlock(ctx)
	if ctx.phase == "mount" then
		ctx.state = {
			status = "idle",
			result = "",
		}
	end

	local state = assert(ctx.state)
	local props = ctx.props

	return {
		"\n",
		h.Title({}, "### Query " .. props.query_id),
		"\n\n",

		-- SQL Code Block
		h.Comment({}, "```sql"),
		"\n",
		h("text", {
			id = "query-" .. props.query_id,
			on_change = function(e)
				props.on_execute(props.query_id, e.text)
			end,
			nmap = {
				["<CR>"] = function()
					ctx:update({ status = "running", result = "Executing query..." })
					props.on_execute(props.query_id, props.query_text, function(success, result)
						vim.schedule(function()
							ctx:update({
								status = success and "success" or "error",
								result = result,
							})
						end)
					end)
					return ""
				end,
			},
		}, props.query_text),
		"\n",
		h.Comment({}, "```"),
		"\n\n",

		-- Status
		h.Title({}, "Status: "),
		state.status == "running" and h.WarningMsg({}, "Running...") or state.status == "success" and h.String(
			{},
			"Success"
		) or state.status == "error" and h.ErrorMsg({}, "Error") or h.Comment({}, "Idle"),
		"\n\n",

		-- Results Code Block
		state.result ~= ""
				and {
					h.Title({}, "Results:"),
					"\n\n",
					h("text", {}, "```json"),
					"\n",
					h("text", {}, state.result),
					"\n",
					h("text", {}, "```"),
					"\n",
				}
			or "",
	}
end

--------------------------------------------------------------------------------
-- Main App Component
--------------------------------------------------------------------------------

local function DatabaseNotebook(ctx)
	if ctx.phase == "mount" then
		-- Use provided default_state or create default
		if ctx.props.default_state then
			ctx.state = ctx.props.default_state
		else
			local connection_uri = "sqlite:///tmp/foo.db"
			local db_type = detect_db_type(connection_uri)
			ctx.state = {
				connection_uri = connection_uri,
				db_type = db_type,
				queries = {
					[1] = Sources.default_query(db_type),
				},
				query_states = {},
			}
		end

		-- Set up autocmd to save state to JSON on :w
		vim.api.nvim_create_autocmd("BufWritePost", {
			buffer = ctx.props.bufnr,
			callback = function()
				-- Get the current state
				local current_state = ctx.state
				if not current_state then
					vim.notify("No state to save", vim.log.levels.WARN, { title = "Database Notebook" })
					return
				end

				-- Determine save path
				local save_path = vim.b[ctx.props.bufnr].db_nbook_filepath
				if not save_path then
					-- Prompt for filename
					save_path = vim.fn.input("Save state to: ", "database-notebook-state.json", "file")
					if save_path == "" then
						vim.notify("Save cancelled", vim.log.levels.INFO, { title = "Database Notebook" })
						return
					end
				end

				-- Serialize and save
				local json_content = serialize_state(current_state)
				local file = io.open(save_path, "w")
				if not file then
					vim.notify("Failed to open file for writing: " .. save_path, vim.log.levels.ERROR, {
						title = "Database Notebook",
					})
					return
				end

				file:write(json_content)
				file:close()

				-- Store the filepath for future saves
				vim.b[ctx.props.bufnr].db_nbook_filepath = save_path

				vim.notify("State saved to: " .. save_path, vim.log.levels.INFO, { title = "Database Notebook" })
			end,
			desc = "Save database notebook state to JSON",
		})
	end

	local state = assert(ctx.state)

	-- Handler for updating connection settings
	local function update_connection(new_uri)
		ctx:update({
			connection_uri = new_uri,
			db_type = detect_db_type(new_uri),
			queries = state.queries,
			query_states = state.query_states,
		})
	end

	-- Handler for updating query text
	local function update_query(query_id, new_text, callback)
		if callback then
			-- Execute query
			if not state.db_type then
				callback(false, "Error: Invalid database URI")
				return
			end
			on_execute(state.db_type, state.connection_uri, new_text, callback)
		else
			-- Just update the query text
			local new_queries = vim.deepcopy(state.queries)
			new_queries[query_id] = new_text
			ctx:update({
				connection_uri = state.connection_uri,
				db_type = state.db_type,
				queries = new_queries,
				query_states = state.query_states,
			})
		end
	end

	-- Handler for adding a new query
	local function add_query()
		local new_queries = vim.deepcopy(state.queries)
		local next_id = #vim.tbl_keys(state.queries) + 1
		-- Default query based on database type
		local default_query = Sources.default_query(state.db_type)
		new_queries[next_id] = default_query
		ctx:update({
			connection_uri = state.connection_uri,
			db_type = state.db_type,
			queries = new_queries,
			query_states = state.query_states,
		})
	end

	return {
		-- Main Title
		h["@markup.heading"]({}, "# Database Notebook"),
		"\n\n",
		h.Comment({}, "> Interactive database query interface in markdown format"),
		"\n",
		h.Comment({}, "> Save this buffer to preserve your queries and results"),
		"\n\n",

		-- Section 1: Connection Settings
		h.Title({}, "## Connection Settings"),
		"\n\n",
		h.Comment({}, "```bash"),
		"\n",
		h.Comment({}, "# Database connection URI"),
		"\n",
		h.Comment({}, "# Formats:"),
		"\n",
		h.Comment({}, "#   SQLite: sqlite://:memory: or sqlite:///path/to/database.db"),
		"\n",
		h.Comment({}, "#   PostgreSQL: postgresql://user:password@host:port/database"),
		"\n",
		h.Comment({}, "#   ClickHouse: clickhouse://user:password@host:port/database"),
		"\n",
		h.Comment({}, "#   Redis: redis://password@host:port/db"),
		"\n",
		h("text", {
			id = "connection-uri",
			on_change = function(e)
				update_connection(e.text)
			end,
		}, state.connection_uri),
		"\n",
		h.Comment({}, "```"),
		"\n\n",

		-- Detected DB Type
		h.Title({}, "Detected Database Type: "),
		state.db_type and h.String({}, state.db_type) or h.ErrorMsg({}, "Unknown"),
		"\n\n",

		-- Section 2: Queries
		h.Title({}, "## Queries"),
		"\n",
		h.Comment({}, "> Edit the SQL in the code blocks below"),
		"\n",
		h.Comment({}, "> Press <CR> on [Execute Query N] to run that query"),
		"\n",

		-- Render all query blocks
		vim.tbl_map(function(query_id)
			return h(QueryBlock, {
				query_id = query_id,
				query_text = state.queries[query_id],
				on_execute = update_query,
			})
		end, vim.tbl_keys(state.queries)),

		-- Add Query Button
		"\n",
		h.Keyword({
			nmap = {
				["<CR>"] = function()
					add_query()
					return ""
				end,
			},
		}, "[+ Add New Query - Press <CR>]"),
		"\n\n",

		-- Section 3: Help
		h.Title({}, "## Tips"),
		"\n",
		h.Comment({}, "- Edit connection URI in the bash code block"),
		"\n",
		h.Comment({}, "- Edit queries in the sql code blocks"),
		"\n",
		h.Comment({}, "- Press <CR> on [Execute Query N] to run a specific query"),
		"\n",
		h.Comment({}, "- Press <CR> on [+ Add New Query] to add more queries"),
		"\n",
		h.Comment({}, "- Save this buffer with :w to preserve your work"),
		"\n",
		h.Comment({}, "- Results appear in json code blocks below each query"),
		"\n",
		h.Comment({}, "- Supported: SQLite (default), PostgreSQL, ClickHouse, Redis"),
		"\n",
	}
end
--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

-- Setup function: Creates a single markdown buffer
M.db_nbook = function(filepath)
	-- Create new buffer
	local tmpfile = vim.fn.tempname()

	vim.cmd.edit(tmpfile)
	local bufnr = vim.api.nvim_get_current_buf()
	vim.bo[bufnr].filetype = "markdown" -- Markdown syntax highlighting

	-- Initialize state from file or use nil for default
	local initial_state = nil
	if filepath then
		initial_state = load_state_from_file(filepath)
		if initial_state then
			vim.notify("Loaded state from: " .. filepath, vim.log.levels.INFO, { title = "Database Notebook" })
		else
			vim.notify("Failed to load state from: " .. filepath, vim.log.levels.WARN, { title = "Database Notebook" })
			initial_state = nil -- Reset to nil so default state is used
		end
	end

	-- Store filepath in buffer variable
	vim.b[bufnr].db_nbook_filepath = filepath

	-- Mount the app with props
	Morph.new(bufnr):mount(h(DatabaseNotebook, {
		default_state = initial_state,
		filepath = filepath,
		bufnr = bufnr,
	}))

	vim.notify(
		"Database Notebook loaded! Edit the connection URI and queries, then press <CR> on [Execute].",
		vim.log.levels.INFO
	)
end

return M

local Morph = require("morph")
local h = Morph.h
local M = {}

local function detect_db_type(uri)
	if not uri or uri == "" then
		return nil
	end

	local scheme = uri:match("^([a-z]+)://")
	return scheme
end

local function serialize_state(state)
	return vim.fn.json_encode({
		connection_uri = state.connection_uri,
		db_type = state.db_type,
		queries = state.queries,
	})
end

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
		queries = data.queries or { [1] = "SELECT 1;" },
		query_states = {},
	}
end

local function load_state_from_file(filepath)
	local file = io.open(filepath, "r")
	if not file then
		return nil
	end
	local content = file:read("*all")
	file:close()
	return deserialize_state(content)
end

local function on_execute(uri, query, callback)
	local normalized_uri = uri:match("^%s*(.-)%s*$")
	local normalized_query = query:match("^%s*(.-)%s*$")
	local cmd = string.format("usql %s -c %s --json | jq .", vim.fn.shellescape(normalized_uri), vim.fn.shellescape(normalized_query))
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
		h.Title({}, "Status: "),
		state.status == "running" and h.WarningMsg({}, "Running...") or state.status == "success" and h.String(
			{},
			"Success"
		) or state.status == "error" and h.ErrorMsg({}, "Error") or h.Comment({}, "Idle"),
		"\n\n",
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

local function DatabaseNotebook(ctx)
	if ctx.phase == "mount" then
		if ctx.props.default_state then
			ctx.state = ctx.props.default_state
		else
			local connection_uri = "sqlite:///tmp/foo.db"
			local db_type = detect_db_type(connection_uri)
			ctx.state = {
				connection_uri = connection_uri,
				db_type = db_type,
				queries = { [1] = "SELECT 1;" },
				query_states = {},
			}
		end

		vim.api.nvim_create_autocmd("BufWriteCmd", {
			buffer = ctx.props.bufnr,
			callback = function()
				local current_state = ctx.state
				if not current_state then
					return
				end

				local save_path = vim.b[ctx.props.bufnr].db_nbook_filepath
				if not save_path then
					save_path = vim.fn.input("Save state to: ", "database-notebook-state.json", "file")
					if save_path == "" then
						return
					end
				end

				local json_content = serialize_state(current_state)
				local file = io.open(save_path, "w")
				if not file then
					return
				end

				file:write(json_content)
				file:close()

				vim.b[ctx.props.bufnr].db_nbook_filepath = save_path
				vim.bo[ctx.props.bufnr].modified = false
			end,
			desc = "Save database notebook state to JSON",
		})
	end

	local state = assert(ctx.state)

	local function update_connection(new_uri)
		ctx:update({
			connection_uri = new_uri,
			db_type = detect_db_type(new_uri),
			queries = state.queries,
			query_states = state.query_states,
		})
	end

	local function update_query(query_id, new_text, callback)
		if callback then
			if not state.connection_uri or state.connection_uri == "" then
				callback(false, "Error: Invalid database URI")
				return
			end
			on_execute(state.connection_uri, new_text, callback)
		else
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

	local function add_query()
		local new_queries = vim.deepcopy(state.queries)
		local next_id = #vim.tbl_keys(state.queries) + 1
		new_queries[next_id] = "SELECT 1;"
		ctx:update({
			connection_uri = state.connection_uri,
			db_type = state.db_type,
			queries = new_queries,
			query_states = state.query_states,
		})
	end

	return {
		h["@markup.heading"]({}, "# Database Notebook"),
		"\n\n",
		h.Title({}, "## Connection"),
		"\n\n",
		h("text", {
			id = "connection-uri",
			on_change = function(e)
				update_connection(e.text)
			end,
		}, state.connection_uri),
		"\n\n",
		h.Title({}, "## Queries"),
		"\n",
		vim.tbl_map(function(query_id)
			return h(QueryBlock, {
				query_id = query_id,
				query_text = state.queries[query_id],
				on_execute = update_query,
			})
		end, vim.tbl_keys(state.queries)),
		"\n",
		h.Keyword({
			nmap = {
				["<CR>"] = function()
					add_query()
					return ""
				end,
			},
		}, "[+ Add Query]"),
		"\n",
	}
end

M.db_nbook = function(filepath)
	local bufnr = vim.api.nvim_get_current_buf()
	vim.bo[bufnr].filetype = "markdown"
	vim.bo[bufnr].buftype = "acwrite"
	vim.bo[bufnr].bufhidden = "delete"
	vim.bo[bufnr].buflisted = false
	vim.api.nvim_buf_set_name(bufnr, "Database Query")

	local initial_state = nil
	if filepath then
		initial_state = load_state_from_file(filepath)
	end

	vim.b[bufnr].db_nbook_filepath = filepath

	Morph.new(bufnr):mount(h(DatabaseNotebook, {
		default_state = initial_state,
		filepath = filepath,
		bufnr = bufnr,
	}))
end

return M

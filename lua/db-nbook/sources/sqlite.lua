local M = {
	name = "sqlite",
	default_query = "SELECT * FROM sqlite_master WHERE type=\"table\";",
}

function M.matches(uri)
	return uri:match("^sqlite://") ~= nil
end

function M.build_command(uri, query)
	local db_path = uri:match("sqlite://(.+)")
	if not db_path then
		return nil, "Invalid SQLite URI format"
	end

	local cmd = string.format("sqlite3 -json %s %s", vim.fn.shellescape(db_path), vim.fn.shellescape(query))
	return cmd
end

return M

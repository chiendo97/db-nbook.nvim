local M = {
	name = "sqlite",
	default_query = "SELECT * FROM sqlite_master WHERE type=\"table\";",
}

function M.matches(uri)
	return uri:match("^sqlite://") ~= nil
end

function M.build_command(uri, query)
	local cmd = string.format("usql %s -c %s", vim.fn.shellescape(uri), vim.fn.shellescape(query))
	return cmd
end

return M

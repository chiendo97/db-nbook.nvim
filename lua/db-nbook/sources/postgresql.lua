local M = {
	name = "postgresql",
	default_query = "SELECT * FROM information_schema.tables LIMIT 10;",
}

function M.matches(uri)
	return uri:match("^postgres") ~= nil
end

function M.build_command(uri, query)
	local cmd = string.format("usql %s -c %s", vim.fn.shellescape(uri), vim.fn.shellescape(query))
	return cmd
end

return M

local M = {
	name = "mysql",
	default_query = "SELECT * FROM information_schema.tables WHERE table_schema != 'information_schema' LIMIT 10;",
}

function M.matches(uri)
	return uri:match("^mysql://") ~= nil
end

function M.build_command(uri, query)
	local cmd = string.format("usql %s -c %s -G", vim.fn.shellescape(uri), vim.fn.shellescape(query))
	return cmd
end

return M

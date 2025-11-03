local M = {
	name = "clickhouse",
	default_query = "SHOW TABLES;",
}

function M.matches(uri)
	return uri:match("^clickhouse://") ~= nil
end

function M.build_command(uri, query)
	local cmd = string.format("usql %s -c %s", vim.fn.shellescape(uri), vim.fn.shellescape(query))
	return cmd
end

return M

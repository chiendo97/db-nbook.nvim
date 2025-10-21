local M = {
	name = "clickhouse",
	default_query = "SHOW TABLES;",
}

function M.matches(uri)
	return uri:match("^clickhouse://") ~= nil
end

function M.build_command(uri, query)
	local user, password, host, port, database = uri:match("clickhouse://([^:]+):([^@]+)@([^:]+):(%d+)/(.+)")
	if not user then
		return nil, "Invalid ClickHouse URI format"
	end

	local cmd = string.format(
		"TZ=UTC clickhouse client -s --host=%s --port=%s --user=%s --password=%s --database=%s --query=%s --format=JSONEachRow",
		vim.fn.shellescape(host),
		vim.fn.shellescape(port),
		vim.fn.shellescape(user),
		vim.fn.shellescape(password),
		vim.fn.shellescape(database),
		vim.fn.shellescape(query)
	)

	return cmd
end

return M

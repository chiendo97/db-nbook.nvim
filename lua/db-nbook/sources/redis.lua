local M = {
	name = "redis",
	default_query = "KEYS *",
}

function M.matches(uri)
	return uri:match("^redis://") ~= nil
end

function M.build_command(uri, query)
	local password, host, port, db = uri:match("redis://([^@]+)@([^:]+):(%d+)/(%d+)")
	if password then
		local cmd = string.format(
			"redis-cli -h %s -p %s -a %s -n %s %s",
			vim.fn.shellescape(host),
			vim.fn.shellescape(port),
			vim.fn.shellescape(password),
			vim.fn.shellescape(db),
			vim.fn.shellescape(query)
		)
		return cmd
	end

	host, port, db = uri:match("redis://([^:]+):(%d+)/(%d+)")
	if not host then
		return nil, "Invalid Redis URI format"
	end

	local cmd = string.format(
		"redis-cli -h %s -p %s -n %s %s",
		vim.fn.shellescape(host),
		vim.fn.shellescape(port),
		vim.fn.shellescape(db),
		vim.fn.shellescape(query)
	)

	return cmd
end

return M

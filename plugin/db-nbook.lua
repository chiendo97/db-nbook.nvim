-- Create user command
vim.api.nvim_create_user_command("DBNBook", function(opts)
	local filepath = opts.args ~= "" and opts.args or nil
	require("db-nbook").db_nbook(filepath)
end, {
	desc = "Open Database Notebook interface",
	nargs = "?",
	complete = "file",
})

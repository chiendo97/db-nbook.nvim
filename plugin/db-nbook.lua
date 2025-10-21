-- Create user command
vim.api.nvim_create_user_command("DBNBook", function()
	require("db-nbook").db_nbook()
end, {
	desc = "Open Database Notebook interface",
})

vim.api.nvim_create_autocmd({ "FocusGained" }, {
	pattern = { "*" },
	command = "checktime",
})

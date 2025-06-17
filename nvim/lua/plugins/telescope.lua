return {
	{
		"nvim-telescope/telescope.nvim",
		branch = "0.1.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			-- FZF native removed due to build issues
		},
		config = function()
			require("telescope").setup({
				defaults = {
					sorting_strategy = "ascending",
					layout_config = {
						prompt_position = "top",
					},
				},
			})
			
			-- Safely try to load extensions
			local function safe_load_extension(name)
				pcall(function() require("telescope").load_extension(name) end)
			end
			
			-- Try to load project extension if available
			safe_load_extension("projects")
		end,
	},
	{
		"ahmedkhalf/project.nvim",
		config = function()
			require("project_nvim").setup({})
		end,
	},
}

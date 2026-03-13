return {
	"pwntester/octo.nvim",
	cmd = "Octo",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-telescope/telescope.nvim",
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		picker = "telescope",
		enable_builtin = true,
		default_merge_method = "squash",
		default_to_projects_v2 = true,
	},
	keys = {
		{ "<leader>prl", "<CMD>Octo pr list<CR>", desc = "PR: list" },
		{ "<leader>prs", "<CMD>Octo pr search<CR>", desc = "PR: search" },
		{ "<leader>prc", "<CMD>Octo pr checks<CR>", desc = "PR: checks" },
		{ "<leader>prd", "<CMD>Octo pr diff<CR>", desc = "PR: diff" },
		{ "<leader>prr", "<CMD>Octo review start<CR>", desc = "PR: start review" },
		{ "<leader>pra", "<CMD>Octo review submit<CR>", desc = "PR: submit review" },
		{ "<leader>prx", "<CMD>Octo review discard<CR>", desc = "PR: discard review" },
		{ "<leader>prm", "<CMD>Octo pr merge squash<CR>", desc = "PR: merge (squash)" },
		{ "<leader>pro", "<CMD>Octo pr browser<CR>", desc = "PR: open in browser" },
	},
}

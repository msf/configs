return {
	{
		"David-Kunz/jester",
		config = function()
			require("jester").setup({
				cmd = "yarn test -t '$result' $file",
				terminal_cmd = ":15split | terminal",
			})
		end,
	},
}

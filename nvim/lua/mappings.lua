local opts = { noremap = true, silent = true }

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", opts)
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", opts)

-- General mappings
vim.keymap.set("", "<BS>", "gg", opts)
vim.keymap.set("", "<CR>", "G", opts)
vim.keymap.set("", "<Space>", "<NOP>", opts)

vim.keymap.set("n", "<tab>", vim.cmd.bn, opts)
vim.keymap.set("n", "<s-tab>", vim.cmd.bp, opts)
vim.keymap.set("n", "U", vim.cmd.redo, opts)

-- File operation maps
vim.keymap.set("n", "<leader>fd", function()
	if vim.inspect(vim.lsp.get_active_clients()) then
		vim.lsp.buf.format()
	else
		vim.cmd.normal("jzgg=G`z")
	end
end)
vim.keymap.set("n", "<leader>fs", vim.cmd.w, opts)
vim.keymap.set("n", "<leader>fS", vim.cmd.SudaWrite, opts)
vim.keymap.set("n", "<leader>W", vim.cmd.SudaWrite, opts)
vim.keymap.set("n", "<leader>q", vim.cmd.q, opts)
vim.keymap.set("n", "<leader>Q", ":q!<cr>", opts)
vim.keymap.set("n", "<leader>wq", vim.cmd.wq, opts)
vim.keymap.set("n", "<leader>bd", ":bp | bd #<cr>", opts)
vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, opts)

vim.keymap.set("", "\\", ':let @/ = ""<CR>', opts)

-- Git
vim.keymap.set("n", "<leader>gd", vim.cmd.Gvdiff, opts)
-- vim.keymap.set("n", "<leader>gb", vim.cmd('Gitsigns toggle_current_line_blame'))

-- window movement
vim.keymap.set("n", "<leader>wj", "<C-W>j", opts)
vim.keymap.set("n", "<leader>wk", "<C-W>k", opts)
vim.keymap.set("n", "<leader>wh", "<C-W>h", opts)
vim.keymap.set("n", "<leader>wl", "<C-W>l", opts)
vim.keymap.set("n", "<leader>wH", "<C-W>5<", opts)
vim.keymap.set("n", "<leader>wI", "<C-W>5>", opts)
vim.keymap.set("n", "<leader>wN", ":resize +5<CR>", opts)
vim.keymap.set("n", "<leader>wE", ":resize -5<CR>", opts)

-- nerdtree
vim.keymap.set("n", "<leader>n", vim.cmd.NERDTreeToggle, opts)


-- Telescope
require("telescope").setup({
	defaults = {
		mappings = {
			i = {
				["<esc>"] = require("telescope.actions").close,
			},
		},
	},
})

local telescope = require("telescope.builtin")

local files = function()
	xpcall(function()
		telescope.git_files({
			show_untracked = true,
			use_git_root = false,
		})
	end, function()
		telescope.find_files({
			hidden = true,
		})
	end)
end

vim.keymap.set("n", "<leader>ff", files, opts)
vim.keymap.set("n", "<c-p>", files, opts)
vim.keymap.set("n", "<leader>rg", function()
	telescope.grep_string({ shorten_path = true, word_match = "-w", only_sort_text = true, search = "" })
end, opts)
vim.keymap.set("n", "<leader>fb", telescope.buffers, opts)
vim.keymap.set("n", "<leader>fh", telescope.help_tags, opts)


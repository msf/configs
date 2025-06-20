vim.g.mapleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require("sets")

require("lazy").setup("plugins", {
    change_detection = {
        enabled = true,
        notify = false,
    },
})

vim.cmd([[colorscheme gruvbox]])

require("autocmd")
require("sets")
require("mappings")
require("git")
require("lsp")
require("line")

-- Telescope extensions are now initialized in lua/plugins/telescope.lua

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
vim.keymap.set('n', '<leader>fh', builtin.help_tags, {})

-- Automatically format on save with error handling
vim.cmd [[autocmd BufWritePre <buffer> lua pcall(function() vim.lsp.buf.format() end)]]

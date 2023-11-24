
let mapleader=","

" we also want to get rid of accidental trailing whitespace on save
autocmd BufWritePre * :%s/\s\+$//e

" plugins expect bash - not fish, zsh, etc
set shell=bash
set background=dark

set ts=4
set shiftwidth=4
set softtabstop=4
set scrolloff=3
set expandtab
set number

call plug#begin(stdpath('data') . '/plugged')
Plug 'preservim/nerdtree', { 'on': 'NERDTreeToggle' }
Plug 'nvim-treesitter/nvim-treesitter', {'do':'TSUpdate'}
Plug 'nvim-treesitter/nvim-treesitter-refactor' " this provides "go to def" etc
Plug 'neovim/nvim-lspconfig'

Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
"Plug 'ray-x/go.nvim'
Plug 'ray-x/aurora' "/ theme for treesitter
call plug#end()

colorscheme desert


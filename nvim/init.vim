call plug#begin('~/.vim/bundle')
Plug 'tpope/vim-sensible'
Plug 'fatih/vim-go', { 'do': ':GoInstallBinaries' }
Plug 'altercation/vim-colors-solarized'
Plug 'scrooloose/syntastic'

" On-demand loading
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }
call plug#end()

set hidden
set number
set autowrite
set shell=bash
set background=dark
" (\ is the default, but ',' is more common, and easier to reach)
let mapleader=","

" we also want to get rid of accidental trailing whitespace on save
autocmd BufWritePre * :%s/\s\+$//e

" tell vim to allow you to copy between files, remember your cursor
if has('nvim')
 set shada='20,<50,:200,%,n~/.nvim/_nviminfo
else
 set viminfo='20,\"50,:200,%,n~/.viminfo
endif
source ~/.vim/syntax.vim

colorscheme solarized

" use goimports for formatting
let g:go_fmt_command = "goimports"

" turn highlighting on
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_fields = 1
let g:go_highlight_structs = 1
let g:go_highlight_interfaces = 1
let g:go_highlight_operators = 1
let g:go_highlight_build_constraints = 1

" from vim-go README.md on slowness with Syntastic
let g:syntastic_go_checkers = ['go', 'golint', 'govet', 'errcheck']
let g:syntastic_mode_map = { 'mode': 'active', 'passive_filetypes': ['go'] }
" fix syntastic + vim-go weirdness
let g:go_list_type = "quickfix"


filetype plugin indent on
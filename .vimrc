" .vimrc, ficheiro de configuracao do vim
"
set incsearch
set nocp
set title
set ttyfast
set ruler
set ai
set sm
set cin
set ts=4
set shiftwidth=4
set softtabstop=4
set scrolloff=3
"set expandtab
set hlsearch
set autowrite
set hidden
set number
syntax enable

map <F5> :make<CR>

let c_space_errors=1
let python_space_errors=1
" Display tabs at the beginning of a line in Python mode as bad.
match ErrorMsg /^\t\+/
" Make trailing whitespace be flagged as bad.
match ErrorMsg /\s\+$/

set shell=bash
set background=dark

" pathogen will load the other modules
execute pathogen#infect()

colorscheme slate

source ~/.vim/syntax.vim
source ~/.vim/minibufexpl.vim
"source ~/.vim/pysmell.vim
source ~/.vim/python.vim
source ~/.vim/badwhitespace.vim

let g:DirDiffExcludes = ".git,*.class,*.exe,.svn"

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" this stuff came from https://coolaj86.com/articles/getting-started-with-golang-and-vim/
"
" plugins expect bash - not fish, zsh, etc
set shell=bash

" which key should be the <leader>
" (\ is the default, but ',' is more common, and easier to reach)
let mapleader=","


" use the python from usr/local/bin
let g:ycm_path_to_python_interpreter = "/usr/local/bin/python"

" we want to tell the syntastic module when to run
" we want to see code highlighting and checks when  we open a file
" but we don't care so much that it reruns when we close the file
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0

" we also want to get rid of accidental trailing whitespace on save
autocmd BufWritePre * :%s/\s\+$//e

" tell vim to allow you to copy between files, remember your cursor
" position and other little nice things like that
set viminfo='100,\"2500,:200,%,n~/.viminfo

" use goimports for formatting
let g:go_fmt_command = "goimports"

" turn highlighting on
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_structs = 1
let g:go_highlight_operators = 1
let g:go_highlight_build_constraints = 1

let g:syntastic_go_checkers = ['go', 'golint', 'errcheck']

" Open go doc in vertical window, horizontal, or tab
au Filetype go nnoremap <leader>v :vsp <CR>:exe "GoDef" <CR>
au Filetype go nnoremap <leader>s :sp <CR>:exe "GoDef"<CR>
au Filetype go nnoremap <leader>t :tab split <CR>:exe "GoDef"<CR>



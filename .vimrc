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
set scrolloff=3
set expandtab
set hlsearch
set autowrite
set hidden
syntax enable

map <F5> :make<CR>

let c_space_errors=1

colorscheme koehler

source ~/.vim/syntax.vim
source ~/.vim/minibufexpl.vim
"source ~/.vim/pysmell.vim
source ~/.vim/python.vim


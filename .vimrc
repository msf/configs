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
set expandtab
set hlsearch
set autowrite
set hidden
syntax enable

map <F5> :make<CR>

let c_space_errors=1
let python_space_errors=1
" Display tabs at the beginning of a line in Python mode as bad.
match ErrorMsg /^\t\+/
" Make trailing whitespace be flagged as bad.
match ErrorMsg /\s\+$/


colorscheme koehler

source ~/.vim/syntax.vim
source ~/.vim/minibufexpl.vim
"source ~/.vim/pysmell.vim
source ~/.vim/python.vim
source ~/.vim/badwhitespace.vim

let g:DirDiffExcludes = ".git,*.class,*.exe,.svn"





























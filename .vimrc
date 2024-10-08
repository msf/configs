" .vimrc, ficheiro de configuracao do vim
"
set ai
set autowrite
set background=dark
set cin
set expandtab
set hidden
set hlsearch
set incsearch
set mouse=a
set nocompatible
set number
set ruler
set scrolloff=3
set shell=bash " plugins expect bash - not fish, zsh, etc
set shiftwidth=4
set sm
set softtabstop=4
set title
set ts=4
set ttyfast
syntax enable

map <F5> :make<CR>

let c_space_errors=1
let python_space_errors=1
" Display tabs at the beginning of a line in Python mode as bad.
match ErrorMsg /^\t\+/
" Make trailing whitespace be flagged as bad.
match ErrorMsg /\s\+$/



set nocompatible    " required by Vundle
filetype off        " required by Vundle

" INSTALL PLUGINS WITH ":PluginInstall!"
" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

Plugin 'lifepillar/vim-solarized8'
Plugin 'vim-syntastic/syntastic'
Plugin 'scrooloose/nerdtree'
Plugin 'hashivim/vim-terraform'
Plugin 'fatih/vim-go'
Plugin 'davidhalter/jedi-vim'
Plugin 'will133/vim-dirdiff'
Plugin 'vim-airline/vim-airline'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required

colorscheme desert

source ~/.vim/syntax.vim
source ~/.vim/minibufexpl.vim
source ~/.vim/badwhitespace.vim

let g:DirDiffExcludes = ".git,*.class,*.exe,.svn"
map <C-k> :NERDTreeToggle<CR>

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" this stuff came from https://coolaj86.com/articles/getting-started-with-golang-and-vim/
"

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
if has('nvim')
 set shada='20,<50,:200,%,n~/.nvim/_nviminfo
else
 set viminfo='20,\"50,:200,%,n~/.viminfo
endif

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

let g:go_def_mode='gopls'
let g:go_info_mode='gopls'
" from vim-go README.md on slowness with Syntastic
let g:syntastic_go_checkers = ['go', 'golint', 'govet', 'errcheck']
let g:syntastic_mode_map = { 'mode': 'active', 'passive_filetypes': ['go'] }
" fix syntastic + vim-go weirdness
let g:go_list_type = "quickfix"

" Open go doc in vertical window, horizontal, or tab
au Filetype go nnoremap <leader>v :vsp <CR>:exe "GoDef" <CR>
au Filetype go nnoremap <leader>s :sp <CR>:exe "GoDef"<CR>
au Filetype go nnoremap <leader>t :tab split <CR>:exe "GoDef"<CR>



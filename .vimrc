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
set number
set mouse=
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

" which key should be the <leader>
" (\ is the default, but ',' is more common, and easier to reach)
let mapleader=","

" pathogen will load the other modules
execute pathogen#infect()

let g:solarized_termcolors = 256
colorscheme solarized

map <leader>. :NERDTreeToggle<CR>

source ~/.vim/syntax.vim
"source ~/.vim/minibufexpl.vim

" this isn't working yet.
"let g:deoplete#enable_at_startup = 1

let g:DirDiffExcludes = ".git,*.class,*.exe,.svn"

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" this stuff came from https://coolaj86.com/articles/getting-started-with-golang-and-vim/
"
" plugins expect bash - not fish, zsh, etc
set shell=bash



" use the python from usr/local/bin
let g:ycm_path_to_python_interpreter = "/usr/local/bin/python"
let g:python_host_prog = '/usr/local/bin/python'

" recommeded settings from Syntastic's README
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
"let g:syntastic_auto_loc_list = 1
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

" from vim-go README.md on slowness with Syntastic
let g:syntastic_go_checkers = ['go', 'golint', 'govet', 'errcheck']
let g:syntastic_mode_map = { 'mode': 'active', 'passive_filetypes': ['go'] }
" fix syntastic + vim-go weirdness
let g:go_list_type = "quickfix"

" Open go doc in vertical window, horizontal, or tab
au Filetype go nnoremap <leader>v :vsp <CR>:exe "GoDef" <CR>
au Filetype go nnoremap <leader>s :sp <CR>:exe "GoDef"<CR>
au Filetype go nnoremap <leader>t :tab split <CR>:exe "GoDef"<CR>



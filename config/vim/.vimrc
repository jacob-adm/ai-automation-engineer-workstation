" ~/.vimrc: Sensible Vim configuration

" -----------------------------------------------------------------------------
" General Settings
" -----------------------------------------------------------------------------
set nocompatible
filetype plugin indent on
syntax on

set encoding=utf-8
set fileencoding=utf-8
set history=1000
set autoread

" -----------------------------------------------------------------------------
" UI & Appearance
" -----------------------------------------------------------------------------
set number
set relativenumber
set cursorline
set showmatch
set ruler
set showcmd
set laststatus=2
set wildmenu
set wildmode=longest:full,full

" Colors & Terminal
set t_Co=256
if has("termguicolors")
    set termguicolors
endif

" -----------------------------------------------------------------------------
" Tabs & Indentation
" -----------------------------------------------------------------------------
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set autoindent
set smartindent

" -----------------------------------------------------------------------------
" Search Settings
" -----------------------------------------------------------------------------
set hlsearch
set incsearch
set ignorecase
set smartcase

" -----------------------------------------------------------------------------
" Backspace & Editing
" -----------------------------------------------------------------------------
set backspace=indent,eol,start
set scrolloff=5
set sidescrolloff=5

" Disable swap and backup noise
set nobackup
set nowritebackup
set noswapfile

" -----------------------------------------------------------------------------
" Key Mappings
" -----------------------------------------------------------------------------
let mapleader = " "

" Clear search highlight with <leader>h
nnoremap <leader>h :nohlsearch<CR>

" Quick save and quit
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>

" Split navigation with Ctrl+hjkl
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Keep selection after indenting in visual mode
vnoremap < <gv
vnoremap > >gv

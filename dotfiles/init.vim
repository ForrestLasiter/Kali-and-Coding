" ~/.config/nvim/init.vim — minimal, no plugin manager required
set number relativenumber
set expandtab shiftwidth=2 tabstop=2 softtabstop=2
set smartindent autoindent
set ignorecase smartcase incsearch hlsearch
set clipboard=unnamedplus
set mouse=a
set undofile
set termguicolors
set scrolloff=5
syntax on
filetype plugin indent on
" quick escape + save
inoremap jk <Esc>
nnoremap <silent> <C-l> :nohlsearch<CR>

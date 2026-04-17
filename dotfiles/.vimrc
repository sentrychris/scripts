" =====================================================================
"  VSCode-flavored vimrc
"  First run: vim will bootstrap vim-plug, then :PlugInstall
"  External tools you may want: node (for coc.nvim), ripgrep, fzf, git
" =====================================================================

" --- Bootstrap vim-plug -----------------------------------------------
let s:plug_path = expand('~/.vim/autoload/plug.vim')
if empty(glob(s:plug_path))
    silent execute '!curl -fLo ' . s:plug_path . ' --create-dirs '
        \ . 'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" --- Plugins ----------------------------------------------------------
call plug#begin('~/.vim/plugged')

" UI
Plug 'joshdick/onedark.vim'              " VSCode-ish dark theme
Plug 'dracula/vim', { 'as': 'dracula' }  " Dracula theme
Plug 'itchyny/lightline.vim'             " status bar
Plug 'preservim/nerdtree'                " file explorer (sidebar)
Plug 'Yggdroot/indentLine'               " indent guides

" Search / navigation
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'                  " :Files, :Rg, :Buffers

" LSP / IntelliSense
Plug 'neoclide/coc.nvim', { 'branch': 'release' }

" Editing
Plug 'tpope/vim-commentary'              " gcc / Ctrl+/ to comment
Plug 'tpope/vim-surround'                " cs"' etc.
Plug 'jiangmiao/auto-pairs'              " auto-close brackets/quotes
Plug 'mg979/vim-visual-multi'            " multi-cursor (Ctrl+N)

" Git
Plug 'airblade/vim-gitgutter'            " diff signs in gutter
Plug 'tpope/vim-fugitive'                " :Git commands

" Languages
Plug 'sheerun/vim-polyglot'              " syntax for ~all languages

call plug#end()

" --- Core settings ----------------------------------------------------
set nocompatible
syntax on
filetype plugin indent on

set number relativenumber
set cursorline
set mouse=a
set clipboard^=unnamed,unnamedplus
set encoding=utf-8
set hidden                               " allow switching modified buffers
set updatetime=300                       " snappier gitgutter / coc
set signcolumn=yes
set scrolloff=8
set sidescrolloff=8
set splitright splitbelow
set wildmenu wildmode=longest:full,full
set termguicolors
set background=dark
set noswapfile nobackup
set undofile undodir=~/.vim/undo
silent! call mkdir(expand('~/.vim/undo'), 'p')

" Indentation
set expandtab
set tabstop=4 shiftwidth=4 softtabstop=4
set autoindent smartindent
set shiftround

" Search
set ignorecase smartcase
set incsearch hlsearch

" Theme — only load after PlugInstall has run
silent! colorscheme dracula
let g:lightline = { 'colorscheme': 'dracula' }

" --- NERDTree (sidebar) -----------------------------------------------
let g:NERDTreeShowHidden = 1
let g:NERDTreeMinimalUI = 1
let g:NERDTreeWinSize = 32
" Auto-close vim if NERDTree is the last window
autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

" --- coc.nvim (IntelliSense) ------------------------------------------
" Recommended language servers — install via :CocInstall once running:
"   coc-tsserver coc-json coc-html coc-css coc-pyright coc-rust-analyzer
"   coc-go coc-sh coc-yaml coc-docker
let g:coc_global_extensions = [
    \ 'coc-json', 'coc-tsserver', 'coc-html', 'coc-css',
    \ 'coc-pyright', 'coc-sh', 'coc-yaml' ]

" Tab to trigger / navigate completion
inoremap <silent><expr> <Tab>
    \ coc#pum#visible() ? coc#pum#next(1) :
    \ <SID>check_back_space() ? "\<Tab>" : coc#refresh()
inoremap <expr><S-Tab> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
inoremap <silent><expr> <CR>
    \ coc#pum#visible() ? coc#pum#confirm() : "\<C-g>u\<CR>"
function! s:check_back_space() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Go to def / refs / hover
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
nnoremap <silent> K :call CocActionAsync('doHover')<CR>

" Rename symbol (F2 like VSCode)
nmap <F2> <Plug>(coc-rename)

" Code action / quick fix
nmap <leader>a <Plug>(coc-codeaction-cursor)
nmap <leader>qf <Plug>(coc-fix-current)

" --- VSCode-like keybindings ------------------------------------------
" Ctrl+S        save
nnoremap <C-s> :w<CR>
inoremap <C-s> <Esc>:w<CR>a

" Ctrl+P        quick open (fuzzy file)
nnoremap <C-p> :Files<CR>

" Ctrl+Shift+P  command palette (closest analog: command-line history)
nnoremap <C-S-p> :Commands<CR>

" Ctrl+B        toggle sidebar
nnoremap <silent> <C-b> :NERDTreeToggle<CR>

" Ctrl+`        toggle integrated terminal (split)
nnoremap <silent> <C-_> :belowright terminal<CR>
tnoremap <silent> <C-_> <C-w>N

" Ctrl+/        toggle line comment (vim-commentary)
nmap <C-_> gcc
vmap <C-_> gc

" Ctrl+F        find in file
nnoremap <C-f> /
" Ctrl+Shift+F  find in project (ripgrep)
nnoremap <C-S-f> :Rg<CR>

" Ctrl+H        find & replace (cwd of current buffer)
nnoremap <C-h> :%s//gc<Left><Left><Left>

" Alt+Up / Alt+Down  move line up/down
nnoremap <A-Up>   :m .-2<CR>==
nnoremap <A-Down> :m .+1<CR>==
inoremap <A-Up>   <Esc>:m .-2<CR>==gi
inoremap <A-Down> <Esc>:m .+1<CR>==gi
vnoremap <A-Up>   :m '<-2<CR>gv=gv
vnoremap <A-Down> :m '>+1<CR>gv=gv

" Alt+Shift+Up / Down  duplicate line
nnoremap <A-S-Up>   :t .-1<CR>
nnoremap <A-S-Down> :t .<CR>

" Ctrl+D        select next occurrence of word (multi-cursor handles this too)
nmap <C-d> <Plug>(VM-Find-Under)
xmap <C-d> <Plug>(VM-Find-Subword-Under)

" Ctrl+\        split editor right
nnoremap <C-Bslash> :vsplit<CR>

" Ctrl+W        close buffer (preserves window)
nnoremap <C-w> :bd<CR>

" Ctrl+Tab / Ctrl+Shift+Tab   cycle buffers
nnoremap <C-Tab>   :bnext<CR>
nnoremap <C-S-Tab> :bprev<CR>

" Esc clears highlight after a search
nnoremap <Esc> :nohlsearch<CR>

" --- Filetype tweaks --------------------------------------------------
autocmd FileType yaml,json,html,css,scss,javascript,typescript
    \ setlocal tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType make setlocal noexpandtab

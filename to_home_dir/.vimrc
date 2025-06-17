scriptencoding utf-8
set encoding=utf-8
syntax on

" With a leader we can do extra key combinations like <leader>w to save the current file
let mapleader = ","

let g:airline_theme='molokai'
set mouse=a
set mousemodel=popup

let b:signcolumn_on=0

" These functions are used to over-ride color scheme settings
" and must be _before_ the colorscheme directive.
function! MyHighlights() abort
    highlight LineNr ctermfg=white ctermbg=59
    highlight SignColumn ctermfg=white ctermbg=59
endfunction

augroup MyColors
    autocmd!
    autocmd ColorScheme * call MyHighlights()
augroup END

colorscheme desert

" Sets how many lines of history VIM has to remember
set history=500

" Turn on the Wild menu
set wildmenu

" Ignore compiled files
set wildignore=*.o,*~,*.pyc
if has("win16") || has("win32")
    set wildignore+=.git\*,.hg\*,.svn\*
else
    set wildignore+=*/.git/*,*/.hg/*,*/.svn/*,*/.DS_Store
endif

" Display tabs and trialing spaces
set list listchars=tab:»-,trail:·,nbsp:·,precedes:<,extends:>
let &showbreak = '>'
nmap <leader><leader>l :set invlist<cr>

" Fast saving
nmap <leader>w :w!<cr>

" :W sudo saves the file
" (useful for handling the permission-denied error)
command! W execute 'w !sudo tee % > /dev/null' <bar> edit!

" ignore case if the pattern doesn't contain uppercase characters (use '\C'
" anywhere in pattern to override these two settings)
set ignorecase smartcase

" Don't redraw while executing macros (good performance config)
set lazyredraw

" For regular expressions turn magic on
set magic

" Show matching brackets when text indicator is over them
set showmatch
" How many tenths of a second to blink when matching brackets
set mat=2

" No annoying sound on errors
set noerrorbells
set novisualbell
set t_vb=
set tm=500

" " Change how vim represents characters on the screen
set encoding=utf-8
"
"" Set the encoding of files written
set fileencoding=utf-8

" Turn backup off, since most stuff is in SVN, git etc. anyway...
set nobackup
set nowb
set noswapfile

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Text, tab and indent related
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Use spaces instead of tabs
set expandtab

" Be smart when using tabs ;)
set smarttab

" 1 tab == 4 spaces
set shiftwidth=4
set tabstop=4

" Auto Linebreak off
set lbr
set tw=0
set wrapmargin=0

set ai "Auto indent
set si "Smart indent
set wrap "Wrap lines


""""""""""""""""""""""""""""""
" => Visual mode related
""""""""""""""""""""""""""""""
" Highlight search results
set hlsearch

" Makes search act like search in modern browsers
set incsearch

" Search mappings: These will make it so that going to the next one in a
" search will center on the line it's found in.
nnoremap n nzzzv
nnoremap N Nzzzv

" Visual mode pressing * or # searches for the current selection
" Super useful! From an idea by Michael Naumann
vnoremap <silent> * :<C-u>call VisualSelection('', '')<CR>/<C-R>=@/<CR><CR>
vnoremap <silent> # :<C-u>call VisualSelection('', '')<CR>?<C-R>=@/<CR><CR>

" Map <Space> to / (search) and Ctrl-<Space> to ? (backwards search)
map <space> /
map <C-space> ?
" Disable highlight when <leader><space> is pressed
map <silent> <leader><space> :noh<cr>

function! BuffersList()
    let all = range(0, bufnr('$'))
    let res = []
    for b in all
    if buflisted(b)
        call add(res, bufname(b))
    endif
    endfor
    return res
endfunction

function! GrepBuffers (expression)
    exec 'vimgrep/'.a:expression.'/ '.join(BuffersList())
endfunction

command! -nargs=+ GrepBufs call GrepBuffers(<q-args>)
nnoremap <leader>F :call GrepBuffers("<C-R><C-W>")<CR>

" grep.vim
let Grep_Default_Options = '-IR'
let Grep_Skip_Files = '*.log *.db'
let Grep_Skip_Dirs = '.git node_modules'


" Replace

" quick insertion of the substitution command
nnoremap gs :%s///g<Left><Left><Left>
xnoremap gs :s///g<Left><Left><Left>
nnoremap gss :%s///g<Left><Left>
xnoremap gss :s///g<Left><Left>


" Formatting

  " don't insert a comment after hitting 'o' or 'O' in the Normal mode
augroup vimrc-editing-formatting
    autocmd!
    autocmd FileType * set formatoptions-=o
augroup END

" make the default Vim mappings more consistent
" https://www.reddit.com/r/vim/comments/dgbr9l/mappings_i_would_change_for_more_consistent_vim/
nnoremap U <C-r>
nnoremap Y y$

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Moving around, tabs, windows and buffers
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" allow moving cursor just after the last chraracter of the line
set virtualedit=all

" Smart way to move between windows
map <C-j> <C-W>j
map <C-k> <C-W>k
map <C-h> <C-W>h
map <C-l> <C-W>l

" Close the current buffer
map <leader>bd :Bclose<cr>:tabclose<cr>gT

" Close all the buffers
map <leader>ba :bufdo bd<cr>

map <leader>l :bnext!<cr>
map <leader>h :bprevious!<cr>

" Useful mappings for managing tabs
map <leader>tn :tabnew<cr>
map <leader>to :tabonly<cr>
map <leader>tc :tabclose<cr>
map <leader>tm :tabmove
map <leader>t<leader> :tabnext

" Let 'tl' toggle between this and the last accessed tab
let g:lasttab = 1
nmap <Leader>tl :exe "tabn ".g:lasttab<CR>
au TabLeave * let g:lasttab = tabpagenr()


" Opens a new tab with the current buffer's path
" Super useful when editing files in the same directory
map <leader>te :tabedit <C-r>=expand("%:p:h")<cr>/

" Switch CWD to the directory of the open buffer
map <leader>cd :cd %:p:h<cr>:pwd<cr>

" Specify the behavior when switching between buffers
try
  set switchbuf=useopen,usetab,newtab
  set stal=2
catch
endtry

" Return to last edit position when opening files (You want this!)
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" Toggle signcolumn. Works only on vim>=8.0 or NeoVim
function! ToggleSignColumn()
    if !exists("b:signcolumn_on") || b:signcolumn_on
        set signcolumn=no
        set nonumber
        set nornu
        let b:signcolumn_on=0
        set colorcolumn=0
    else
        set signcolumn=yes
        set number
        set rnu
        let b:signcolumn_on=1
        set colorcolumn=120
    endif
endfunction

"" Add toggle for line numbers and sign column
noremap <leader><leader>n :call ToggleSignColumn()<CR>
set cursorline

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Editing mappings
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Move a line of text using ALT+[jk] on mac
nnoremap j :m .+1<CR>==
nnoremap k :m .-2<CR>==
inoremap j <Esc>:m .+1<CR>==gi
inoremap k <Esc>:m .-2<CR>==gi
vnoremap j :m '>+1<CR>gv=gv
vnoremap k :m '<-2<CR>gv=gv

autocmd Filetype python setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
autocmd Filetype go setlocal tabstop=4 shiftwidth=4 softtabstop=4

set undofile " Maintain undo history between sessions
set undodir=~/.vim/undodiri

filetype plugin indent on

" Allow backspace to delete indentation and inserted text
" i.e. how it works in most programs
set backspace=indent,eol,start

" Delete trailing white space on save, useful for some filetypes ;)
fun! CleanExtraSpaces()
    let save_cursor = getpos(".")
    let old_query = getreg('/')
    silent! %s/\s\+$//e
    call setpos('.', save_cursor)
    call setreg('/', old_query)
endfun

if has("autocmd")
    autocmd BufWritePre *.txt,*.js,*.py,*.wiki,*.sh,*.coffee,*.vimrc,*.bashrc :call CleanExtraSpaces()
endif

"Remove all trailing whitespace by pressing ,<backspace>
nnoremap <leader> :call CleanExtraSpaces()<CR>

"" Copy current word
nnoremap <leader>e yiwe
"" Replace current word
nnoremap <leader>w viw"_dPe

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Spell checking
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Pressing ,ss will toggle and untoggle spell checking
map <leader>ss :setlocal spell!<cr>

" Shortcuts using <leader>
map <leader>sn ]s
map <leader>sp [s
map <leader>sa zg
map <leader>s? z=

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" GOLANG
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" go-vim plugin specific commands
" Also run `goimports` on your current file on every save
" Might be be slow on large codebases, if so, just comment it out
let g:go_fmt_command = "goimports"

" Status line types/signatures.
let g:go_auto_type_info = 1

"au filetype go inoremap <buffer> . .<C-x><C-o>

" If you want to disable gofmt on save
" let g:go_fmt_autosave = 0


" NERDTree plugin specific commands
:nnoremap <C-g> :NERDTreeToggle<CR>
"autocmd vimenter * NERDTree


" ------------------------------------------------------------------------------
"  AIRLINE SETTINGS
" ------------------------------------------------------------------------------

" vim-airline
"let g:airline_theme = 'powerlineish'
"let g:airline#extensions#ale#enabled = 1
"let g:airline#extensions#branch#enabled = 1
"let g:airline#extensions#tabline#enabled = 1
"let g:airline#extensions#tagbar#enabled = 1
let g:airline_powerline_fonts = 1

"let g:airline_skip_empty_sections = 1

" vim-airline
"let g:airline#extensions#virtualenv#enabled = 1

if !exists('g:airline_symbols')
    let g:airline_symbols = {}
endif

" unicode symbols
let g:airline_left_sep = '»'
let g:airline_left_sep = '▶'
let g:airline_right_sep = '«'
let g:airline_right_sep = '◀'
let g:airline_symbols.linenr = '␊'
let g:airline_symbols.linenr = '␤'
let g:airline_symbols.linenr = '¶'
let g:airline_symbols.branch = ''
let g:airline_symbols.paste = 'ρ'
let g:airline_symbols.paste = 'Þ'
let g:airline_symbols.paste = '∥'
let g:airline_symbols.whitespace = 'Ξ'

" airline symbols
let g:airline_left_sep = ''
let g:airline_left_alt_sep = ''
let g:airline_right_sep = ''
let g:airline_right_alt_sep = ''
let g:airline_symbols.branch = ''
let g:airline_symbols.readonly = ''
let g:airline_symbols.linenr = ''

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Helper functions
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Returns true if paste mode is enabled
function! HasPaste()
    if &paste
        return 'PASTE MODE  '
    endif
    return ''
endfunction

" Don't close window, when deleting a buffer
command! Bclose call <SID>BufcloseCloseIt()
function! <SID>BufcloseCloseIt()
    let l:currentBufNum = bufnr("%")
    let l:alternateBufNum = bufnr("#")

    if buflisted(l:alternateBufNum)
        buffer #
    else
        bnext
    endif

    if bufnr("%") == l:currentBufNum
        new
    endif

    if buflisted(l:currentBufNum)
        execute("bdelete! ".l:currentBufNum)
    endif
endfunction

function! CmdLine(str)
    call feedkeys(":" . a:str)
endfunction

function! VisualSelection(direction, extra_filter) range
    let l:saved_reg = @"
    execute "normal! vgvy"

    let l:pattern = escape(@", "\\/.*'$^~[]")
    let l:pattern = substitute(l:pattern, "\n$", "", "")

    if a:direction == 'gv'
        call CmdLine("Ack '" . l:pattern . "' " )
    elseif a:direction == 'replace'
        call CmdLine("%s" . '/'. l:pattern . '/')
    endif

    let @/ = l:pattern
    let @" = l:saved_reg
endfunction

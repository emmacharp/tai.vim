" tai.vim — Official Vim integration for the tai system-wide CLI.
" tai is assumed to be installed in $PATH (e.g., ~/.local/bin/tai).
" tai must expose at least: `tai task "<text>"` and optionally `tai split`.

if exists("g:loaded_tai")
  finish
endif
let g:loaded_tai = 1

" Ensure tai exists on PATH
if !executable('tai')
  echohl WarningMsg
  echom "[tai] Warning: 'tai' command is not found in $PATH."
  echom "[tai] Install tai system-wide (~/.local/bin/tai)."
  echohl None
endif

"==============================================================================
" Internal helper: queue a task asynchronously
"==============================================================================
function! s:tai_has_tui() abort
  if !executable('tmux')
    return 0
  endif

  let l:root = getcwd()
  let l:pane_id_file = l:root . '/.tai_bus/tui-pane.id'
  if !filereadable(l:pane_id_file)
    return 0
  endif

  let l:pane_id = trim(readfile(l:pane_id_file)[0])
  if empty(l:pane_id)
    return 0
  endif

  let l:panes = systemlist('tmux list-panes -F "#{pane_id}"')
  return index(l:panes, l:pane_id) >= 0
endfunction

function! s:tai_handle_input(task) abort
  if !executable('tai')
    echohl ErrorMsg | echom "[tai] Cannot send task: 'tai' is not executable." | echohl None
    return
  endif

  let l:cmd = s:tai_has_tui()
        \ ? ['tai', 'send', a:task]
        \ : ['tai', 'task', a:task]
  let l:message = l:cmd[1] ==# 'send' ? 'sent to tui' : 'task queued'

  if exists('*job_start')
    call job_start(l:cmd)
    echo "[tai] " . l:message
  else
    call system(l:cmd)
    echo "[tai] " . l:message . ' (blocking)'
  endif
endfunction

"==============================================================================
" :Tai <text> — Freeform command prompt
" Usage: :Tai Refactor this file
"==============================================================================
command! -nargs=+ Tai call s:tai_handle_input(<q-args>)

"==============================================================================
" :TaiVisual — Use the visually selected text as context
"==============================================================================
function! s:tai_visual_task() range abort
  " Visually selected text
  let l:lines = getline(a:firstline, a:lastline)
  let l:selection = join(l:lines, "\n")

  " User action
  let l:action = input("[tai] Action? ")
  if empty(l:action)
    echo "[tai] cancelled"
    return
  endif

  " Prompt structure
  let l:prompt = "Context:\n" . l:selection . "\n\nAction: " . l:action

  " JSON payload (single string)
  let l:json = json_encode({'task': l:prompt})

  " Destination directory
  let l:root = getcwd()
  let l:req_dir = l:root . "/.tai_bus/requests"
  call mkdir(l:req_dir, "p")

  " Filename
  let l:filename = l:req_dir . "/task-" . strftime("%Y%m%d-%H%M%S") . ".json"

  " Write JSON as ONE SINGLE LINE
  call writefile([l:json], l:filename)

  echo "[tai] queued: " . l:filename
endfunction

command! -range TaiVisual call s:tai_visual_task()


"==============================================================================
" :TaiBuffer — Send entire buffer as context
"==============================================================================
command! TaiBuffer call s:tai_handle_input(
      \ "Here is the entire buffer (" . expand('%:p') . "):\n" .
      \ join(getline(1, '$'), "\n")
      \ )

"==============================================================================
" :TaiFile <task> — Operate on the current file path
" Example: :TaiFile Add exhaustive error handling
"==============================================================================
command! -nargs=+ TaiFile call s:tai_handle_input(
      \ "Edit file: " . expand('%:p') . "\n\nTask: " . <q-args>
      \ )

"==============================================================================
" Optional shortcuts (commented out)
"==============================================================================
" nnoremap <silent> <leader>ta :Tai 
" vnoremap <silent> <leader>tv :'<,'>TaiVisual<CR>
" nnoremap <silent> <leader>tb :TaiBuffer<CR>
" nnoremap <silent> <leader>tf :TaiFile 

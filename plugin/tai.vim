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
"


function! s:send_to_chat(type) range abort
	let l:root = getcwd()
	let l:pane_id_file = l:root . '/.tai_bus/tui-pane.id'
	if !filereadable(l:pane_id_file)
		echo "[tai] tui pane id file not found"
		return
	endif

	let l:pane_contents = readfile(l:pane_id_file)
	if empty(l:pane_contents)
		echo "[tai] tui pane id file is empty"
		return
	endif

	let l:pane_id = trim(l:pane_contents[0])
	if empty(l:pane_id)
		echo "[tai] tui pane id not available"
		return
	endif

	let l:payload = input('Prompt (append @f to include file): ')
	if empty(l:payload)
		echo "No prompt entered"
		return
	endif

	if l:payload =~ '@f$'
		let l:payload = substitute(l:payload, '@f$', '', '')
		" Use %:. for cwd-relative; swap to %:p for absolute.
		let l:payload .= "\nFILE: " . expand('%:.')
	endif

	if a:type ==# 'v' || a:type ==# 'char'
		let l:payload .= "\n\n" . join(getline("'<", "'>"), "\n")
	endif

	" Respect user overrides when set globally; default to the stored pane id.
	let l:target_id = exists('g:chat_pane') ? g:chat_pane : l:pane_id
	let l:cmd = 'target=' . shellescape(l:target_id)
				\ . '; tmux load-buffer -b chatbuf -'
				\ . '; tmux paste-buffer -p -b chatbuf -t "$target"'
				\ . '; tmux send-keys -t "$target" C-m'

	call system(l:cmd, l:payload)
endfunction

" Optional chat shortcuts (uncomment to use)
nnoremap <silent> <leader>z :call <SID>send_to_chat('n')<CR>
xnoremap <silent> <leader>z :<C-U>call <SID>send_to_chat('v')<CR>

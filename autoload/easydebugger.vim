" 插件初始化入口
function! easydebugger#Enable()
	"nmap <S-R> <Plug>EasyDebuggerInspect
	"nmap <S-W> <Plug>EasyDebuggerWebInspect
	nnoremap <silent> <Plug>EasyDebuggerInspect :call easydebugger#NodeInspect()<CR>
	nnoremap <silent> <Plug>EasyDebuggerWebInspect :call easydebugger#NodeWebInspect()<CR>
endfunction

function! s:Echo_debugging_info(command)
	exec "echom '>>> ". a:command . " : Press <Ctrl-C> to stop debugger Server...'"
endfunction

function! easydebugger#NodeWebInspect()
	let l:command = 'node --inspect-brk '.getbufinfo('%')[0].name
	call s:Echo_debugging_info(l:command)
	if version <= 800
		call system(l:command . " 2>/dev/null")
	else 
		call term_start(l:command . " 2>/dev/null",{ 
						\ 'term_finish': 'close',
						\ 'term_rows':11,
						\ })
	endif
endfunction

function! easydebugger#NodeInspect()
	let l:command = 'node inspect '.getbufinfo('%')[0].name
	call s:Echo_debugging_info(l:command)
	call s:Create_Debugger()
	if version <= 800
		call system(l:command . " 2>/dev/null")
	else 
		call term_start(l:command . " 2>/dev/null",{ 
						\ 'term_finish': 'close',
						\ 'term_name':'debugger_window',
						\ 'term_rows':23,
						\ 'out_cb':'easydebugger#Term_callback',
						\ 'exit_cb':'easydebugger#Reset_Editor'
						\ })
		let g:debugger.term_winnr = bufnr('debugger_window')
		tnoremap <buffer> <silent> <CR> <C-\><C-n>:call easydebugger#Special_Cmd_Handler()<CR>i<C-P><Down>
		call term_wait('debugger_window')
		call s:Debugger_Break_Action(g:debugger.log)
	endif
endfunction

function! easydebugger#Reset_Editor(...)
	call execute(g:debugger.term_winnr.'wincmd w','silent!')
	exec ":b ". g:debugger.original_bufname
	exec ":sign unplace 1 file=".g:debugger.original_bufname
	call execute('redraw','silent!')
	call s:Debugger_del_tmpbuf()
endfunction

function! easydebugger#Term_callback(channel, msg)
	if empty(a:msg)
		return
	endif
	let m = substitute(a:msg,"\\W\\[\\d\\{-}[a-zA-Z]","","g")
	let g:msgs = split(m,"\r\n")
	let g:debugger.log += g:msgs
	let g:debugger.log += [""]
	
	call s:Debugger_Break_Action(g:debugger.log)
endfunction

function! s:Debugger_Break_Action(log)
	let break_msg = s:Get_Term_Break_Msg(a:log)
	if type(break_msg) == type({})
		call s:Debugger_Stop(get(break_msg,'fname'), get(break_msg,'break_line'))
	endif
	"exec "echom 'channel: ".a:channel.", msg:".a."'"
	" TODO: msgs 是输出结果，按行组成一个 List
endfunction

function! s:Get_Term_Break_Msg(log)
	if len(a:log) == 0
		return 0
	endif
	let break_line = 0
	let fname = ''
	if len(a:log) > 0 
		for line in a:log
			let fn = matchstr(line, "\\(\\(break in\\|Break on start in\\)\\s\\)\\@<=.\\{\-}\\(:\\)\\@=")
			let nr =  matchstr(line, "\\(^>\\s\\|^>\\)\\@<=\\(\\d\\{1,10000}\\)\\(\\s\\)\\@=")
			if s:StringTrim(fn) != ''
				let fname = fn
			endif
			if s:StringTrim(nr) != ''
				let break_line = str2nr(nr)
			endif
		endfor
	endif
	if break_line != 0 && fname != ''
		return {"fname":fname, "break_line":break_line}
	else 
		return 0
	endif
endfunction

" 相当于 trim，去掉首尾的空字符
function! s:StringTrim(str)
	if !empty(a:str)
		return substitute(a:str, "^\\s\\+\\(.\\{\-}\\)\\s\\+$","\\1","g")
	endif
	return ""
endfunction

function! s:Create_Debugger()
	let g:debugger = {}
	let g:debugger.original_bnr = bufnr('')
	let g:debugger.original_buf = getbufinfo()
	let g:debugger.cwd = getcwd()
	let g:debugger.original_bufname = bufname('%')
	let g:debugger.original_line_nr = line(".")
	let g:debugger.original_col_nr = col(".")
	let g:debugger.buf_winnr = bufwinnr('%')
	let g:debugger.bufs = []
	let g:debugger.stop_line = 0
	let g:debugger.stop_fname = ''
	let g:debugger.log = []
	call add(g:debugger.bufs, g:debugger.original_bufname)
	exec 'sign define stop_point text=>> texthl=SignColumn linehl=CursorLine '
	return g:debugger
endfunction

function! s:Debugger_Stop(fname, line)
	if !exists("g:debugger")
		let g:debugger = s:Create_Debugger()
	endif

	if a:fname == get(g:debugger,'stop_fname') && a:line == get(g:debugger,'stop_line')
		return
	else
		let g:debugger.stop_fname = a:fname
		let g:debugger.stop_line = a:line
	endif

	call execute(g:debugger.term_winnr.'wincmd w','silent!')
	let fname = s:Debugger_get_filebuf(a:fname)
	exec ":sign unplace 1 file=".fname
	exec ":sign place 1 line=".string(a:line)." name=stop_point file=".fname
	sleep 10m
	call cursor(a:line,1)
	"sleep 100m
	call execute(g:debugger.original_bnr.'wincmd w','silent!')
endfunction


function! s:Debugger_add_filebuf(fname)
	exec ":badd ". a:fname
	exec ":b ". a:fname
	call add(g:debugger.bufs, a:fname)
endfunction

function! s:Debugger_del_tmpbuf()
	let tmp_bufs = deepcopy(g:debugger.bufs)
	for t_buf in tmp_bufs
		if t_buf != g:debugger.original_bufname
			call execute('bdelete! '.t_buf,'silent!')
		endif
	endfor
	let g:debugger.bufs = []
endfunction

function! s:Debugger_get_filebuf(fname)
	" TODO bufname用的相对路径需要改为绝对路径
	" fnameescape(fnamemodify(l:filename,':p'))
	if index(g:debugger.bufs , a:fname) < 0 
		call s:Debugger_add_filebuf(a:fname)
	endif
	" TODO debugger 里只能获得 文件名，怎么获得文件路径
	" 比如跟踪到 modules.js 里，怎么也能buffer进来？
	call execute('buffer '.a:fname,'silent!')
	return a:fname
endfunction

function! s:Close_Term()
	call term_sendkeys('debugger_window',"\<CR>\<C-C>\<C-C>")
endfunction

function! easydebugger#Special_Cmd_Handler()
	let cmd = getline('.')[0 : col('.')-1]
	let cmd = substitute(cmd,"^.*> ","","g")
	if cmd == 'kill'
		" 关掉term
		call s:Close_Term()
	endif
	call term_sendkeys('debugger_window',"\<CR>")
endfunction


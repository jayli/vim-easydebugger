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

function! easydebugger#NodeInspect()
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



function! debugger#python#Setup()

	" Delve 不支持 Pause 
	let setup_options = {
		\	'ctrl_cmd_continue':          "continue",
		\	'ctrl_cmd_next':              "next",
		\	'ctrl_cmd_stepin':            "step",
		\	'ctrl_cmd_stepout':           "up",
		\	'ctrl_cmd_pause':             "doNothing",
		\	'InspectInit':                function('lib#runtime#InspectInit'),
		\	'WebInspectInit':             function('lib#runtime#WebInspectInit'),
		\	'InspectCont':                function('lib#runtime#InspectCont'),
		\	'InspectNext':                function('lib#runtime#InspectNext'),
		\	'InspectStep':                function('lib#runtime#InspectStep'),
		\	'InspectOut':                 function('lib#runtime#InspectOut'),
		\	'InspectPause':               function('debugger#python#InpectPause'),
		\	'InspectSetBreakPoint':       function('lib#runtime#InspectSetBreakPoint'),
		\	'DebuggerTester':             function('debugger#python#CommandExists'),
		\	'ClearBreakPoint':            function("debugger#python#ClearBreakPoint"),
		\	'SetBreakPoint':              function("debugger#python#SetBreakPoint"),
		\	'TermSetupScript':            function('debugger#python#TermSetupScript'),
		\	'AfterStopScript':            function('debugger#python#AfterStopScript'),
		\	'TermCallbackHandler':        function('debugger#python#TermCallbackHandler'),
		\	'DebuggerNotInstalled':       'pdb not installed ！Please install pdb first.',
		\	'WebDebuggerCommandPrefix':   'python3 -m pdb',
		\	'LocalDebuggerCommandPrefix': 'python3 -m pdb',
		\	'LocalDebuggerCommandSufix':  '',
		\	'ExecutionTerminatedMsg':     "\\(Process \\d\\{-} has exited with status\\|Process has exited with status\\)",
		\	'BreakFileNameRegex':		  "\\(>\\s\\+\\)\\@<=\\S\\{-}\\.py\\(\\S\\+\\)\\@=",
		\	'BreakLineNrRegex':           "\\(>.\\{-}\\.py(\\)\\@<=\\d\\+\\(\\S\\)\\@=",
		\ }
	return setup_options
endfunction

function! debugger#python#TermCallbackHandler(msg)
	" 确保只在应该刷新stack时执行
	if !exists('g:debugger.show_stack_log') || g:debugger.show_stack_log != 1
		return
	endif
	if type(a:msg) == type([]) &&
				\ len(a:msg) == 1 &&
				\ a:msg[0] == "Can not debug non-main package" 
		call timer_start(500,
				\ {-> s:LogMsg(a:msg[0])},
				\ {'repeat' : 1})
	endif
	call s:Fillup_Quickfix_window(a:msg)
	let g:debugger.show_stack_log = 0
endfunction

function! s:Fillup_Quickfix_window(msg)
	let stacks = s:Get_Stack(a:msg)
	if len(stacks) == 0 
		return
	endif
	call s:Set_qflist(stacks)
	let g:debugger.log = []
	let g:debugger.go_stacks = stacks
endfunction

function! s:Set_qflist(stacks)
	let fullstacks = []
	for item in a:stacks
		call add(fullstacks, {
			\ 'filename':item.filename,
			\ 'module': s:Get_FileName(item.filename),
			\ 'lnum':str2nr(item.linnr),
			\ 'text':item.callstack,
			\ 'valid':1
			\ })
	" \ 'module': len(item.filename) >= 40 ? pathshorten(item.filename) : item.filename,
	endfor
	" call setqflist(fullstacks, 'r')
	call g:Goto_window(g:debugger.original_winid)
	" TODO 这句话执行速度很慢
	call s:LogMsg('执行 setloclist 开始')
	call setloclist(0, fullstacks, 'r')  " TODO local list 和 quick fix 窗口
	call s:LogMsg('执行 setloclist 结束')
	" 对于 locallist 来说，必须要先设置其值，再打开，顺序不能错，quickfix 窗口
	" 可以先打开窗口再传值
	call g:Open_localistwindow_once()
	call g:Goto_window(get(g:debugger,'term_winid'))
endfunction

function! s:Get_FileName(path)
	let path  = simplify(a:path)
	let fname = matchstr(path,"\\([\\/]\\)\\@<=[^\\/]\\+$")
	return fname
endfunction

function! s:Get_Stack(msg)
	let stacks = []
	let go_stack_regx = "^->\\s\\+\\S\\{-}"

	" 如果是键盘输入了单个字符
	if len(a:msg) == 1
		return []
	endif

	" " 如果不是 w 命令输出 stack，直接反馈空
	" if a:msg[0] != 'w'
	" 	return []
	" endif

	let endline = len(a:msg) - 1
	call s:LogMsg(string(a:msg))
	let i = 0

	"stack 信息样例:
	"2	0x000000000105e7c1 in runtime.goexit
	"		at /usr/local/go/src/runtime/asm_amd64.s:1333
	" 这个循环执行的是很快的
	while i <= endline
		if a:msg[i] =~ go_stack_regx
			let pointer = " "
			let callstack = lib#util#StringTrim(matchstr(a:msg[i],"\\(->\\s\\+\\)\\@<=.\\+"))
			call s:LogMsg("============" . callstack)
			" if i == endline 
			" 	break
			" endif
			let filename = lib#util#StringTrim(matchstr(a:msg[i-1],"\\(\\s\\+\\)\\@<=\\S.\\+\\.py\\((\\d\\)\\@="))
			let linnr = lib#util#StringTrim(matchstr(a:msg[i-1],"\\(\\S\\.py(\\)\\@<=\\d\\+\\()\\)\\@="))
			if filename == "" || linnr == "" || callstack == ""
				let i = i + 1
				continue
			else
				call add(stacks, {
					\	'filename': filename,
					\	'linnr': linnr,
					\	'callstack':callstack,
					\	'pointer':pointer . linnr
					\ })
				let i = i + 1 
			endif
		else
			let i = i + 1
		endif
	endwhile

	return stacks
endfunction

function! debugger#python#CommandExists()
	let result =	system("python3 --version 2>/dev/null")
	return empty(result) ? 0 : 1
endfunction

function! debugger#python#TermSetupScript()
	call s:LogMsg('Do Nothing')
	" call term_sendkeys(get(g:debugger,'debugger_window_name'), 
	" 			\ "break " .s:Get_Package(). ".main\<CR>")
	" call term_sendkeys(get(g:debugger,'debugger_window_name'), "continue\<CR>")
endfunction

function! debugger#python#AfterStopScript(msg)
	call s:LogMsg('11111111111')
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "w\<CR>")
	call s:LogMsg('22222222222')
	let g:debugger.show_stack_log = 1
endfunction

function! debugger#python#InpectPause()
	call lib#util#LogMsg("PDB 不支持 Pause，'Pause' is not supported by PDB")
endfunction

function! debugger#python#ClearBreakPoint(fname,line)
	return "clearall ".a:fname.":".a:line."\<CR>"
endfunction

function! debugger#python#SetBreakPoint(fname,line)
	return "break ".a:fname.":".a:line."\<CR>"
endfunction

function! s:Get_Package()
	let lines = getbufline(g:debugger.original_bnr,1,'$')
	let pkg = ""
	for line in lines
		if line =~ "^\\s\\{-}package\\s\\{-}\\w\\{1,}"
			let pkg = matchstr(line,"\\(^\\s\\{-}package\\s\\{-}\\)\\@<=\\w\\{1,}")
			break
		endif
	endfor
	return pkg
endfunction

" 输出 LogMsg
function! s:LogMsg(msg)
	call lib#util#LogMsg(a:msg)
endfunction

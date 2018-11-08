
function! debugger#go#Setup()

	" Delve 不支持 Pause 
	let setup_options = {
		\	'ctrl_cmd_continue':          "continue",
		\	'ctrl_cmd_next':              "next",
		\	'ctrl_cmd_stepin':            "step",
		\	'ctrl_cmd_stepout':           "stepout",
		\	'ctrl_cmd_pause':             "doNothing",
		\	'InspectInit':                function('lib#runtime#InspectInit'),
		\	'WebInspectInit':             function('lib#runtime#WebInspectInit'),
		\	'InspectCont':                function('lib#runtime#InspectCont'),
		\	'InspectNext':                function('lib#runtime#InspectNext'),
		\	'InspectStep':                function('lib#runtime#InspectStep'),
		\	'InspectOut':                 function('lib#runtime#InspectOut'),
		\	'InspectPause':               function('debugger#go#InpectPause'),
		\	'InspectSetBreakPoint':       function('lib#runtime#InspectSetBreakPoint'),
		\	'DebuggerTester':             function('debugger#go#CommandExists'),
		\	'ClearBreakPoint':            function("debugger#go#ClearBreakPoint"),
		\	'SetBreakPoint':              function("debugger#go#SetBreakPoint"),
		\	'TermSetupScript':            function('debugger#go#TermSetupScript'),
		\	'AfterStopScript':            function('debugger#go#AfterStopScript'),
		\	'TermCallbackHandler':        function('debugger#go#TermCallbackHandler'),
		\	'DebuggerNotInstalled':       '系统没有安装 Delve ！Please install Delve first.',
		\	'WebDebuggerCommandPrefix':   'dlv debug',
		\	'LocalDebuggerCommandPrefix': 'dlv debug',
		\	'LocalDebuggerCommandSufix':  '',
		\	'ExecutionTerminatedMsg':     "\\(Process \\d\\{-} has exited with status\\|Process has exited with status\\)",
		\	'BreakFileNameRegex':         "\\(>\\s\\S\\+\\s\\)\\@<=\\S\\{-}.\\(go\\|s\\|c\\|cpp\\|h\\)\\(:\\d\\)\\@=",
		\	'BreakLineNrRegex':           "\\(>\\s\\S\\+\\s\\S\\{-}.\\(go\\|s\\|c\\|cpp\\|h\\):\\)\\@<=\\d\\{-}\\(\\s\\)\\@=",
		\ }
	return setup_options
endfunction

function! debugger#go#TermCallbackHandler(msg)
	" call s:LogMsg(string(a:msg))
	if type(a:msg) == type([]) &&
				\ len(a:msg) == 1 &&
				\ a:msg[0] == "Can not debug non-main package" 
		call timer_start(500,
				\ {-> s:LogMsg(a:msg[0])},
				\ {'repeat' : 1})
	endif
	call s:Fillup_Quickfix_window(a:msg)
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
			\ 'lnum':str2nr(item.linnr),
			\ 'text':item.callstack.' | '. item.pointer,
			\ 'valid':1
			\ })
	endfor
	call setqflist(fullstacks, 'r')
endfunction

function! s:Get_Stack(msg)
	let stacks = []
	let go_stack_regx = "^\\d\\{-}\\s\\{-}0x\\w\\{-}\\s\\{-}in\\s\\{-}"
	let endline = len(a:msg) - 1
	let i = 0

	"stack 信息样例:
	"2	0x000000000105e7c1 in runtime.goexit
	"		at /usr/local/go/src/runtime/asm_amd64.s:1333
	while i <= endline
		if a:msg[i] =~ go_stack_regx
			let pointer = lib#util#StringTrim(matchstr(a:msg[i],"0x\\S\\+"))
			let callstack = lib#util#StringTrim(matchstr(a:msg[i],"\\(in\\s\\)\\@<=.\\+$"))
			if i == endline
				break
			endif
			let filename = lib#util#StringTrim(matchstr(a:msg[i+1],"\\(at\\s\\)\\@<=.\\{-}\\(:\\d\\{-}\\)\\@="))
			let linnr = lib#util#StringTrim(matchstr(a:msg[i+1],"\\(:\\)\\@<=\\d\\{-}$"))
			if filename == "" || linnr == "" || callstack == "" || pointer == ""
				let i = i + 1
				continue
			else
				call add(stacks, {
					\	'filename': filename,
					\	'linnr': linnr,
					\	'callstack':callstack,
					\	'pointer':pointer
					\ })
				let i = i + 2
			endif
		else
			let i = i + 1
		endif
	endwhile

	return stacks
endfunction

function! debugger#go#CommandExists()
	let result =	system("dlv version 2>/dev/null")
	return empty(result) ? 0 : 1
endfunction

function! debugger#go#TermSetupScript()
	call term_sendkeys(get(g:debugger,'debugger_window_name'), 
				\ "break " .s:Get_Package(). ".main\<CR>")
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "continue\<CR>")
endfunction

function! debugger#go#AfterStopScript(msg)
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "stack\<CR>")
endfunction

function! debugger#go#InpectPause()
	call lib#util#LogMsg("Delve 不支持 Pause，'Pause' is not supported by Delve")
endfunction

function! debugger#go#ClearBreakPoint(fname,line)
	return "clearall ".a:fname.":".a:line."\<CR>"
endfunction

function! debugger#go#SetBreakPoint(fname,line)
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

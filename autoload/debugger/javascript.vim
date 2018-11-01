" 语言全局配置
function! debugger#javascript#Setup()
	let setup_options = {
		\	'ctrl_cmd_continue':          "cont",
		\	'ctrl_cmd_next':              "next",
		\	'ctrl_cmd_stepin':            "step",
		\	'ctrl_cmd_stepout':           "out",
		\	'ctrl_cmd_pause':             "pause",
		\	'InspectInit':                function('debugger#runtime#InspectInit'),
		\	'WebInspectInit':             function('debugger#runtime#WebInspectInit'),
		\	'InspectCont':                function('debugger#runtime#InspectCont'),
		\	'InspectNext':                function('debugger#runtime#InspectNext'),
		\	'InspectStep':                function('debugger#runtime#InspectStep'),
		\	'InspectOut':                 function('debugger#runtime#InspectOut'),
		\	'InspectPause':               function('debugger#runtime#InspectPause'),
		\	'InspectSetBreakPoint':       function('debugger#runtime#InspectSetBreakPoint'),
		\	'DebuggerTester':             function('debugger#javascript#CommandExists'),
		\	'ClearBreakPoint':            function("debugger#javascript#ClearBreakPoint"),
		\	'SetBreakPoint':              function("debugger#javascript#SetBreakPoint"),
		\	'TermSetupScript':            function('debugger#javascript#TermSetupScript'),
		\	'AfterStopScript':            function('debugger#javascript#AfterStopScript'),
		\	'TermCallbackHandler':        function('debugger#javascript#TermCallbackHandler'),
		\
		\	'DebuggerNotInstalled':       '系统没有安装 Node！Please install node first.',
		\	'WebDebuggerCommandPrefix':   'node --inspect-brk',
		\	'LocalDebuggerCommandPrefix': 'node inspect',
		\	'LocalDebuggerCommandSufix':  '2>/dev/null',
		\	'ExecutionTerminatedMsg':     'Waiting for the debugger to disconnect',
		\	'BreakFileNameRegex':         "\\(\\(break in\\|Break on start in\\)\\s\\)\\@<=.\\{\-}\\(:\\)\\@=",
		\	'BreakLineNrRegex':           "\\(^>\\s\\|^>\\)\\@<=\\(\\d\\{1,10000}\\)\\(\\s\\)\\@=",
		\ }

	return setup_options
endfunction

function! debugger#javascript#CommandExists()
	let result =  system("node -v 2>/dev/null")
	return len(matchstr(result,"^v\\d\\{1,}")) >=1 ? 1 : 0
endfunction

function! debugger#javascript#ClearBreakPoint(fname,line)
	return "clearBreakpoint('".a:fname."', ".a:line.")\<CR>"
endfunction

function! debugger#javascript#SetBreakPoint(fname,line)
	return "setBreakpoint('".a:fname."', ".a:line.");list(1)\<CR>"
endfunction

function! debugger#javascript#TermCallbackHandler(msg)
	call s:Fillup_Quickfix_window(a:msg)
endfunction

function! s:Fillup_Quickfix_window(msg)
	if len(a:msg) < 2
		return
	endif

	let stacks = reverse(s:Get_Stack(a:msg))
	if len(stacks) == 0
		return
	endif
	call s:Set_qflist(stacks)
	" 清空log很重要
	let g:debugger.log = []
	let g:debugger.javascript_stacks = stacks
endfunction

function! s:Set_qflist(stacks)
	let fullstacks = []
	for item in a:stacks
		call add(fullstacks, {
					\ 'filename':item.filename,
					\ 'lnum':str2nr(item.linnr),
					\ 'text':item.callstack,
					\ 'valid':1
					\ })
	endfor
	call setqflist(fullstacks, 'r')
endfunction

function! s:Get_Stack(msg)
	let stacks = []
	let js_stack_regx = "#\\d\\{-}\\s.\\+:\\d\\{-}:\\d\\{-}"
	let msg = reverse(a:msg)
	let endline = len(a:msg) - 1
	let i = 0

	" find startline
	"#7 startup bootstrap_node.js:191:15
	while i <= endline
		if msg[i] =~ js_stack_regx
			let filename = debugger#util#StringTrim(matchstr(msg[i],"\\(\\s\\)\\@<=\\S\\{-}\\(:\\d\\)\\@="))
			let linnr = debugger#util#StringTrim(matchstr(msg[i],"\\(js:\\)\\@<=\\d\\{-}\\(:\\d\\)\\@="))
			let callstack = debugger#util#StringTrim(matchstr(msg[i],"\\(#\\d\\{-}\\s\\)\\@<=\\S\\{-}\\(\\s\\)\\@="))
			let pointer = debugger#util#StringTrim(matchstr(msg[i],"\\(#\\)\\@<=\\d\\{-}\\(\\s\\)\\@="))
			call add(stacks, {
						\	'filename': filename,
						\	'linnr': linnr,
						\	'callstack':callstack,
						\	'pointer':pointer
						\ })
		endif
		let i = i + 1
	endwhile

	return stacks
endfunction

function! debugger#javascript#TermSetupScript()
	" Do Nothing
endfunction

function! debugger#javascript#AfterStopScript(msg)
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "backtrace\<CR>")
endfunction

" 输出 LogMsg
function! s:LogMsg(msg)
	call debugger#util#LogMsg(a:msg)
endfunction

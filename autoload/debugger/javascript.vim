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
		\	'__TermCallbackHandler':        function('debugger#javascript#TermCallbackHandler'),
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
	let stacks = reverse(s:Get_Stack(a:msg))
	if type(stacks) == type(0) && stacks == 0
		return
	endif
	call s:Set_qflist(stacks)
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
	let startline = 0
	let msg = reverse(a:msg)
	let endline = len(a:msg) - 1
	let i = 0
	
	if len(a:msg) < 2
		return 0
	endif

	" find startline
	while i < endline - 1
		"#7 startup bootstrap_node.js:191:15
		if msg[i] =~ "^debug>" && msg[i+1] =~ js_stack_regx
			let startline = i + 1
			let j = 0
			while startline + j < endline - 1 
				if msg[startline + j] =~ js_stack_regx
					let filename = debugger#util#StringTrim(matchstr(msg[startline + j],"\\(\\s\\)\\@<=\\S\\{-}\\(:\\d\\)\\@="))
					let linnr = debugger#util#StringTrim(matchstr(msg[startline + j],"\\(js:\\)\\@<=\\d\\{-}\\(:\\d\\)\\@="))
					let callstack = debugger#util#StringTrim(matchstr(msg[startline + j],"\\(#\\d\\{-}\\s\\)\\@<=\\S\\{-}\\(\\s\\)\\@="))
					let pointer = debugger#util#StringTrim(matchstr(msg[startline + j],"\\(#\\)\\@<=\\d\\{-}\\(\\s\\)\\@="))
					call add(stacks, {
								\	'filename': filename,
								\	'linnr': linnr,
								\	'callstack':callstack,
								\	'pointer':pointer
								\ })
					let j = j + 1
				else
					break
				endif
			endwhile
			break
		endif
		let i = i + 1
	endwhile

	return stacks
endfunction

function! debugger#javascript#TermSetupScript()
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "backtrace\<CR>")
endfunction

function! debugger#javascript#AfterStopScript()
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "backtrace\<CR>")
endfunction

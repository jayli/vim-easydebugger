" 语言全局配置
function! debugger#javascript#Setup()
	let setup_options = {
		\	'ctrl_cmd_continue':          "cont",
		\	'ctrl_cmd_next':              "next",
		\	'ctrl_cmd_stepin':            "step",
		\	'ctrl_cmd_stepout':           "out",
		\	'ctrl_cmd_pause':             "pause",
		\	'InspectInit':                function('lib#runtime#InspectInit'),
		\	'WebInspectInit':             function('lib#runtime#WebInspectInit'),
		\	'InspectCont':                function('lib#runtime#InspectCont'),
		\	'InspectNext':                function('lib#runtime#InspectNext'),
		\	'InspectStep':                function('lib#runtime#InspectStep'),
		\	'InspectOut':                 function('lib#runtime#InspectOut'),
		\	'InspectPause':               function('lib#runtime#InspectPause'),
		\	'InspectSetBreakPoint':       function('lib#runtime#InspectSetBreakPoint'),
		\	'DebuggerTester':             function('debugger#javascript#CommandExists'),
		\	'ClearBreakPoint':            function("debugger#javascript#ClearBreakPoint"),
		\	'SetBreakPoint':              function("debugger#javascript#SetBreakPoint"),
		\	'TermSetupScript':            function('debugger#javascript#TermSetupScript'),
		\	'AfterStopScript':            function('debugger#javascript#AfterStopScript'),
		\	'TermCallbackHandler':        function('debugger#javascript#TermCallbackHandler'),
		\	'ShowLocalVarsWindow':		  0,
		\	'DebuggerNotInstalled':       '系统没有安装 Node！Please install node first.',
		\	'WebDebuggerCommandPrefix':   'node --inspect-brk',
		\	'LocalDebuggerCommandPrefix': 'node inspect',
		\	'LocalDebuggerCommandSufix':  '2>/dev/null',
		\	'ExecutionTerminatedMsg':     'Waiting for the debugger to disconnect',
		\	'BreakFileNameRegex':         "\\(^\\(break in\\|Break on start in\\)\\s.\\{-}:\\/\\/\\)\\@<=.\\{-}\\(:\\)\\@=",
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
	call s:Fillup_Stacks_window(a:msg)
endfunction

function! s:Fillup_Stacks_window(msg)
	if len(a:msg) < 2
		return
	endif
	let stacks = reverse(s:Get_Stack(a:msg))
	if len(stacks) == 0
		return
	endif
	call s:Set_stackslist(stacks)
	let g:debugger.log = []
	let g:debugger.callback_stacks = stacks
	let g:debugger.show_stack_log = 0
endfunction

function! s:Set_stackslist(stacks)
	let bufnr = get(g:debugger,'stacks_bufinfo')[0].bufnr
	let buf_oldlnum = len(getbufline(bufnr,0,'$'))
	call setbufvar(bufnr, '&modifiable', 1)
	let ix = 0 
	for item in a:stacks
		let ix = ix + 1
		let bufline_str = "*" . lib#util#GetFileName(item.filename) . "* : " .
					\ "|" . item.linnr . "|" .
					\ " → " . item.callstack . " [at] " . item.filename
		call setbufline(bufnr, ix, bufline_str)
	endfor
	if buf_oldlnum >= ix + 1
		call deletebufline(bufnr, ix + 1, buf_oldlnum)
	elseif ix == 0
		call deletebufline(bufnr, 1, len(getbufline(bufnr,0,'$')))
	endif
	call setbufvar(bufnr, '&modifiable', 0)
	let g:debugger.stacks_bufinfo = getbufinfo(bufnr)
	call g:Goto_window(get(g:debugger,'term_winid'))
	call execute('redraw','silent!')
endfunction

function! s:Get_Stack(msg)
	let stacks = []
	let js_stack_regx = "#\\d\\{-}\\s.\\+:\\d\\{-}:\\d\\{-}"
	let msg = reverse(a:msg)
	let endline = len(a:msg) - 1
	let i = 0

	"stack 信息样例:
	"#7 startup bootstrap_node.js:191:15
	while i <= endline
		if msg[i] =~ js_stack_regx
			let filename = lib#util#StringTrim(matchstr(msg[i],"\\(\\s\\)\\@<=\\S\\{-}\\(:\\d\\)\\@="))
			let linnr = lib#util#StringTrim(matchstr(msg[i],"\\(js:\\)\\@<=\\d\\{-}\\(:\\d\\)\\@="))
			let callstack = lib#util#StringTrim(matchstr(msg[i],"\\(#\\d\\{-}\\s\\)\\@<=\\S\\{-}\\(\\s\\)\\@="))
			let pointer = lib#util#StringTrim(matchstr(msg[i],"\\(#\\)\\@<=\\d\\{-}\\(\\s\\)\\@="))
			call add(stacks, {
				\	'filename': substitute(filename, "^file:\\/\\/","","g"),
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
	call lib#util#LogMsg(a:msg)
endfunction

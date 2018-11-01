
" 语言全局配置
function! debugger#go#Setup()

	" Delve 不支持 Pause 
	" TODO ，这里需要将 命令行里的 stack 去掉
	let setup_options = {
		\	'ctrl_cmd_continue':          "continue\<CR>stack\<CR>",
		\	'ctrl_cmd_next':              "next\<CR>stack\<CR>",
		\	'ctrl_cmd_stepin':            "step\<CR>stack\<CR>",
		\	'ctrl_cmd_stepout':           "stepout\<CR>stack\<CR>",
		\	'ctrl_cmd_pause':             "doNothing",
		\	'InspectInit':                function('debugger#runtime#InspectInit'),
		\	'WebInspectInit':             function('debugger#runtime#WebInspectInit'),
		\	'InspectCont':                function('debugger#runtime#InspectCont'),
		\	'InspectNext':                function('debugger#runtime#InspectNext'),
		\	'InspectStep':                function('debugger#runtime#InspectStep'),
		\	'InspectOut':                 function('debugger#runtime#InspectOut'),
		\	'InspectPause':               function('debugger#go#InpectPause'),
		\	'InspectSetBreakPoint':       function('debugger#runtime#InspectSetBreakPoint'),
		\	'DebuggerTester':             function('debugger#go#CommandExists'),
		\	'ClearBreakPoint':            function("debugger#go#ClearBreakPoint"),
		\	'SetBreakPoint':              function("debugger#go#SetBreakPoint"),
		\	'TermSetupScript':            function('debugger#go#TermSetupScript'),
		\	'AfterStopScript':            function('debugger#go#AfterStopScript'),
		\	'TermCallbackHandler':        function('debugger#go#TermCallbackHandler'),
		\
		\	'DebuggerNotInstalled':       '系统没有安装 Delve ！Please install Delve first.',
		\	'WebDebuggerCommandPrefix':   'dlv debug',
		\	'LocalDebuggerCommandPrefix': 'dlv debug',
		\	'LocalDebuggerCommandSufix':  '',
		\	'ExecutionTerminatedMsg':     "\\(Process \\d\\{-} has exited with status\\|Process has exited with status\\)",
		\	'BreakFileNameRegex':         "\\(>\\s\\S\\+\\s\\)\\@<=\\S\\{-}.\\(go\\|s\\|c\\|cpp\\|h\\)\\(:\\d\\)\\@=",
		\	'BreakLineNrRegex':           "\\(>\\s\\S\\+\\s\\S\\{-}.\\(go\\|s\\|c\\|cpp\\|h\\):\\)\\@<=\\d\\{-}\\(\\s\\)\\@=",
		\
		\	'_GoPkgName':                 debugger#go#Get_Package()
		\ }
	return setup_options
endfunction

function! debugger#go#TermCallbackHandler(msg)
	call s:Fillup_Quickfix_window(a:msg)
endfunction

" TODO 如果源码跟踪到s文件里，执行这里没反应
function! s:Fillup_Quickfix_window(msg)
	let stacks = s:Get_Stack(a:msg)
	if type(stacks) == type(0) && stacks == 0
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
	let startline = 0
	let endline = len(a:msg) - 1
	let cnt = 0
	let i = endline
	" jayli TODO here 卡顿太严重
	while i > startline
		if a:msg[i] =~ '^(dlv)' 
			let cnt = cnt + 1
		endif
		if cnt == 2
			let startline = i
			break
		endif
		let i = i - 1
	endwhile

	if len(a:msg) > startline + 1  && !(a:msg[startline + 1] =~ "^\\d\\{-}\\s\\{-}0x\\w\\{-}\\s\\{-}in\\s\\{-}")
		" call debugger#util#LogMsg(a:msg[startline + 1])
		return 0
	endif

	let j = startline + 1

	while j < endline - 2
		let pointer = debugger#util#StringTrim(matchstr(a:msg[j],"0x\\S\\+"))
		let callstack = debugger#util#StringTrim(matchstr(a:msg[j],"\\(in\\s\\)\\@<=.\\+$"))
		if len(a:msg) >= j + 1
			let filename = debugger#util#StringTrim(matchstr(a:msg[j+1],"\\(at\\s\\)\\@<=.\\{-}\\(:\\d\\{-}\\)\\@="))
			let linnr = debugger#util#StringTrim(matchstr(a:msg[j+1],"\\(:\\)\\@<=\\d\\{-}$"))
		endif

		let j = j + 2

		if pointer == '' || callstack == ''
			continue
		endif
		call add(stacks, {
					\	'filename': filename,
					\	'linnr': linnr,
					\	'callstack':callstack,
					\	'pointer':pointer
					\ })
	endwhile
	return stacks
endfunction

function! debugger#go#CommandExists()
	let result =  system("dlv version 2>/dev/null")
	return empty(result) ? 0 : 1
endfunction

function! debugger#go#TermSetupScript()
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "break " .get(g:language_setup,'_GoPkgName'). ".main\<CR>")
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "continue\<CR>")
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "stack\<CR>")
endfunction

function! debugger#go#AfterStopScript(msg)
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "stack\<CR>")
endfunction

function! debugger#go#InpectPause()
	call debugger#util#LogMsg("Delve 不支持 Pause，'Pause' is not supported by Delve")
endfunction

function! debugger#go#ClearBreakPoint(fname,line)
	return "clearall ".a:fname.":".a:line."\<CR>"
endfunction

function! debugger#go#SetBreakPoint(fname,line)
	return "break ".a:fname.":".a:line."\<CR>"
endfunction

function! debugger#go#Get_Package()
	let lines = getbufline('%',1,'$')
	let pkg = ""
	for line in lines
		if line =~ "^\\s\\{-}package\\s\\{-}\\w\\{1,}"
			let pkg = matchstr(line,"\\(^\\s\\{-}package\\s\\{-}\\)\\@<=\\w\\{1,}")
			break
		endif
	endfor
	return pkg
endfunction

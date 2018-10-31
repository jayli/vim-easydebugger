
" 语言全局配置
function! debugger#go#Setup()

	" Delve 不支持 Pause 
	let setup_options = {
		\	'ctrl_cmd_continue':          'continue',
		\	'ctrl_cmd_next':              'next<CR>stack',
		\	'ctrl_cmd_stepin':            'step',
		\	'ctrl_cmd_stepout':           'stepout',
		\	'ctrl_cmd_pause':             'doNothing',
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

" TODO Pattern not found: debugger.go_stacks = stacks
" Jayli

function! debugger#go#TermCallbackHandler(msg)
	let stacks = s:Get_Stack(a:msg)
	if type(stacks) == type(0) && stacks == 0
		return
	endif
	if !exists('g:debugger.go_stacks')
		let g:debugger.go_stacks = stacks
		call s:Set_qflist(stacks)
	elseif !s:Stack_is_equal(g:debugger.go_stacks, stacks)
		call s:Set_qflist(stacks)
		g:debugger.go_stacks = stacks
	endif
endfunction

function! s:Set_qflist(stacks)
	call setqflist([],'r')  
	for item in a:stacks
		call setqflist([{'filename':item.filename,
					\ 'lnum':str2nr(item.linnr),
					\ 'text':item.callstack.' | '. item.pointer}], 'a')
	endfor
endfunction

function! s:Stack_is_equal(old,new)
	return 0
	" jayli stack 是数组
	if len(a:old) != len(a:new)
		return 0
	endif

	let equal = 1
	let i = 0

	while i < len(a:new)
		let old = a:old[i]
		let new = a:new[i]
		if old.filename == new.filename &&
					\ get(old,'linnr') == get(new,'linnr') &&
					\ get(old,'callstack') == get(new,'callstack') &&
					\ get(old,'pointer') == get(new,'pointer')
			continue
		else
			let equal = 0
			break
		endif
		let i = i + 1
	endwhile

	return equal
endfunction

function! s:Get_Stack(msg)
	"call debugger#util#LogMsg(a:msg[0])
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
		" TODO jayli，这里的正则提取的有问题，main.main 这个字段如果是 url 这
		" 种形态就提取不出来了
		let pointer = debugger#util#StringTrim(matchstr(a:msg[j],"0x\\S\\+"))
		let callstack = debugger#util#StringTrim(matchstr(a:msg[j],"\\(in\\s\\)\\@<=.\\+$"))
		if len(a:msg) >= j + 1
			let filename = debugger#util#StringTrim(matchstr(a:msg[j+1],"\\(at\\s\\)\\@<=.\\{-}\\(:\\d\\{-}\\)\\@="))
			let linnr = debugger#util#StringTrim(matchstr(a:msg[j+1],"\\(:\\)\\@<=\\d\\{-}$"))
		endif
		call add(stacks, {
					\	'filename': filename,
					\	'linnr': linnr,
					\	'callstack':callstack,
					\	'pointer':pointer
					\ })
		let j = j + 2
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
	" call term_wait(get(g:debugger,'debugger_window_name'))
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

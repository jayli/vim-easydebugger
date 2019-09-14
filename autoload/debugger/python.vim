

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
		\	'ShowLocalVarsWindow':		  1,
		\	'LocalDebuggerCommandSufix':  '',
		\	'ExecutionTerminatedMsg':     "\\(Process \\d\\{-} has exited with status\\|Process has exited with status\\)",
		\	'BreakFileNameRegex':		  "\\(>\\s\\+\\)\\@<=\\S\\{-}\\.py\\(\\S\\+\\)\\@=",
		\	'BreakLineNrRegex':           "\\(>.\\{-}\\.py(\\)\\@<=\\d\\+\\(\\S\\)\\@=",
		\ }
	return setup_options
endfunction

function! debugger#python#TermCallbackHandler(msg)
	" 刷新函数调用堆栈
	if exists('g:debugger.show_stack_log') && g:debugger.show_stack_log == 1
		" 确保只在应该刷新stack时执行
		let g:debugger.show_stack_log = 0
		" 为了确保show_stack 和 show_localvars 的处理时序基本不乱，这个条件里
		" 只做term的命令输出，在show_localvars 时统一做渲染，可能会有一定的冗
		" 余，比如Fillup_Stacks_window的操作可能会有多次，但始终会保证最后
		" 一次parse是正确的
		call debugger#python#ShowLocalVarNames()
	endif

	" 刷新本地变量列表
	if exists('g:debugger.show_localvars') && g:debugger.show_localvars == 1
		let localvars =  s:Fillup_localvars_window(a:msg)
		call s:Fillup_Stacks_window(a:msg)
		if len(localvars) != 0
			let g:debugger.show_localvars = 0
		endif
	endif
endfunction

function! s:Fillup_localvars_window(msg)
	let localvars = s:Get_Localvars(a:msg)
	call s:Set_localvarlist(localvars)

	let g:debugger.log = []
	let g:debugger.localvars = localvars
	return localvars
endfunction

function! s:Get_Localvars(msg)
	let vars = []
	let var_names = []
	for item in a:msg
		if item =~ "^$\\s\\S\\{-}"
			let var_name = matchstr(item,"\\(^$\\s\\)\\@<=.\\+\\(\\s=\\)\\@=")
			let var_value = matchstr(item,"\\(^$\\s\\S\\+\\s=\\s\\)\\@<=.\\+")
			if index(var_names, var_name) == -1 && var_name != '__localvars__'
				call add(vars, {"var_name":var_name, "var_value": var_value})
				call add(var_names, var_name)
			endif
		endif
	endfor
	return vars
endfunction

function! s:Fillup_Stacks_window(msg)
	let stacks = s:Get_Stack(a:msg)
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
					\ " → " . item.callstack
		call setbufline(bufnr, ix, bufline_str)
	endfor
	if buf_oldlnum >= ix + 1
		call deletebufline(bufnr, ix + 1, buf_oldlnum)
	elseif ix == 0
		call deletebufline(bufnr, 1, len(getbufline(bufnr,0,'$')))
	endif
	call setbufvar(bufnr, '&modifiable', 0)
	let g:debugger.stacks_bufinfo = getbufinfo(bufnr)
endfunction

function! s:Set_localvarlist(localvars)
	let bufnr = get(g:debugger,'localvars_bufinfo')[0].bufnr
	let buf_oldlnum = len(getbufline(bufnr,0,'$'))
	call setbufvar(bufnr, '&modifiable', 1)
	let ix = 0 
	for item in a:localvars
		let ix = ix + 1
		let bufline_str = "*" . item.var_name . "* " . item.var_value
		call setbufline(bufnr, ix, bufline_str)
	endfor
	if buf_oldlnum >= ix + 1
		call deletebufline(bufnr, ix + 1, buf_oldlnum)
	elseif ix == 0
		call deletebufline(bufnr, 1, len(getbufline(bufnr,0,'$')))
	endif
	call setbufvar(bufnr, '&modifiable', 0)
	let g:debugger.localvars_bufinfo = getbufinfo(bufnr)
endfunction

" 从path中得到文件名
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

	let endline = len(a:msg) - 1
	let i = 0

	"stack 信息提取，备注：这个循环执行的是很快的
	while i <= endline
		if a:msg[i] =~ go_stack_regx
			let pointer = " "
			let callstack = lib#util#StringTrim(matchstr(a:msg[i],"\\(->\\s\\+\\)\\@<=.\\+"))
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
	call s:SetPythonLocalvarsCmd()
endfunction

function! s:SetPythonLocalvarsCmd()
	call term_sendkeys(get(g:debugger,'debugger_window_name'), 
				\ "alias pi for __localvars__ in dir(): print('$ '+__localvars__+' =',str(eval(__localvars__))[0:80])\<CR>")
endfunction

function! debugger#python#AfterStopScript(msg)
	call debugger#python#ShowStacks()
	call s:SetPythonLocalvarsCmd()
endfunction

function s:set_stacks_flag(flag)
	let g:debugger.show_stack_log = a:flag
endfunction

function! debugger#python#ShowStacks()
	let g:debugger.show_stack_log = 1
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "w\<CR>")
endfunction

function s:set_localvars_flag(flag)
	let g:debugger.show_localvars = a:flag
endfunction

function! debugger#python#ShowLocalVarNames()
	let g:debugger.show_localvars = 1
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "pi\<CR>")
endfunction

function! debugger#python#InpectPause()
	call lib#util#LogMsg("PDB 不支持 Pause，'Pause' is not supported by PDB")
endfunction

function! debugger#python#ClearBreakPoint(fname,line)
	return "clear ".a:fname.":".a:line."\<CR>"
endfunction

function! debugger#python#SetBreakPoint(fname,line)
	return "break ".a:fname.":".a:line."\<CR>"
endfunction

" 输出 LogMsg
function! s:LogMsg(msg)
	call lib#util#LogMsg(a:msg)
endfunction

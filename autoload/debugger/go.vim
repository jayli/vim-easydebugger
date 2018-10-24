


function! debugger#go#Setup()

	" Delve 不支持 Pause 
	let setup_options = {
				\	'ctrl_cmd_continue':          'continue',
				\	'ctrl_cmd_next':              'next',
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
				\	'TermSetupScript': function('debugger#go#TermSetupScript'),
				\
				\	'DebuggerNotInstalled':       '系统没有安装 Delve ！Please install Delve first.',
				\	'WebDebuggerCommandPrefix':   'dlv debug',
				\	'LocalDebuggerCommandPrefix': 'dlv debug',
				\	'LocalDebuggerCommandSufix':  '',
				\
				\	'GoPkgName':debugger#go#Get_Package()
				\ }
	return setup_options
endfunction

function! debugger#go#CommandExists()
	return 1
endfunction

function! debugger#go#TermSetupScript()
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "break " .get(g:language_setup,'GoPkgName'). ".main\<CR>")
	call term_sendkeys(get(g:debugger,'debugger_window_name'), "continue\<CR>")
endfunction

function! debugger#go#InpectPause()
	call debugger#util#LogMsg("Delve 不支持 Pause，'Pause' is not supported by Delve")
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

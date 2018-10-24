














function! debugger#javascript#Setup()
	let setup_options = {
				\	'ctrl_cmd_continue':          'cont',
				\	'ctrl_cmd_next':              'next',
				\	'ctrl_cmd_stepin':            'step',
				\	'ctrl_cmd_stepout':           'out',
				\	'ctrl_cmd_pause':             'pause',
				\	'InspectInit':                function('debugger#runtime#InspectInit'),
				\	'WebInspectInit':             function('debugger#runtime#WebInspectInit'),
				\	'InspectCont':                function('debugger#runtime#InspectCont'),
				\	'InspectNext':                function('debugger#runtime#InspectNext'),
				\	'InspectStep':                function('debugger#runtime#InspectStep'),
				\	'InspectOut':                 function('debugger#runtime#InspectOut'),
				\	'InspectPause':               function('debugger#runtime#InspectPause'),
				\	'InspectSetBreakPoint':       function('debugger#runtime#InspectSetBreakPoint'),
				\	'DebuggerTester':             function('debugger#javascript#CommandExists'),
				\
				\	'DebuggerNotInstalled':       '系统没有安装 Node！Please install node first.',
				\	'WebDebuggerCommandPrefix':   'node --inspect-brk',
				\	'LocalDebuggerCommandPrefix': 'node inspect',
				\	'LocalDebuggerCommandSufix':  '2>/dev/null',
				\ }

	return setup_options
endfunction

function! debugger#javascript#CommandExists()
	let result =  system("node -v 2>/dev/null")
	return len(matchstr(result,"^v\\d\\{1,}")) >=1 ? 1 : 0
endfunction


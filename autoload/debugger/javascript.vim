














function! debugger#javascript#Setup()

	let setup_options = {
				\	'ctrl_cmd_continue':          'cont',
				\	'ctrl_cmd_next':              'next',
				\	'ctrl_cmd_stepin':            'step',
				\	'ctrl_cmd_stepout':           'out',
				\	'ctrl_cmd_pause':             'pause',
				\	'InspectInit':                function('easydebugger#InspectInit'),
				\	'WebInspectInit':             function('easydebugger#WebInspectInit'),
				\	'InspectCont':                function('easydebugger#InspectCont'),
				\	'InspectNext':                function('easydebugger#InspectNext'),
				\	'InspectStep':                function('easydebugger#InspectStep'),
				\	'InspectOut':                 function('easydebugger#InspectOut'),
				\	'InspectPause':               function('easydebugger#InspectPause'),
				\	'InspectSetBreakPoint':       function('easydebugger#InspectSetBreakPoint'),
				\	'DebuggerTester':             function('debugger#javascript#Command_Exists'),
				\
				\	'DebuggerNotInstalled':       '系统没有安装 Node！Please install node first.',
				\	'WebDebuggerCommandPrefix':   'node --inspect-brk',
				\	'LocalDebuggerCommandPrefix': 'node inspect',
				\ }

	return setup_options
endfunction

function! debugger#javascript#Command_Exists()
	let result =  system("node -v 2>/dev/null")
	return len(matchstr(result,"^v\\d\\{1,}")) >=1 ? 1 : 0
endfunction


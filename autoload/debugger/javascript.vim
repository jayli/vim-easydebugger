" 语言全局配置
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
				\	'ClearBreakPoint':            function("debugger#javascript#ClearBreakPoint"),
				\	'SetBreakPoint':              function("debugger#javascript#SetBreakPoint"),
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

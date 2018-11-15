" File:			autoload/easydebugger.vim
" Author:		@jayli <http://jayli.github.io>
" Description:	vim-easydebugger 的事件绑定基本在这里

" 插件初始化入口
function! easydebugger#Enable()

	" VIM 8.1 以下版本不支持
	if version <= 800
		return
	endif

	" 全局对象
	" g:debugger				Debugger 全局对象，运行 Term 时被初始化
	" g:language_setup			当前语言的 Debugger 配置，当支持当前语言的情况下随文件加载初始化
	"							在debugger/[编程语言].vim中配置
	" g:Debug_Lang_Supported	当前支持的debug语言种类
	" g:None_Lang_Sp_Msg		当前代码不支持调试
	
	let g:Debug_Lang_Supported = ["javascript","javascript.jsx","go"]
	let g:None_Lang_Sp_Msg = "不支持该语言，或者需要将光标切换到调试窗口, ".
				\ "not support current lang"

	" if index(g:Debug_Lang_Supported, &filetype) >= 0
	" 	call execute('let g:language_setup = debugger#'. &filetype .'#Setup()' )
	" endif

	call s:Bind_Nor_Map_Keys()
	call s:Build_Command()
endfunction

" 每进入一个 Buffer 都重新绑定一下 Term 的映射命令
function! easydebugger#BindTermMapKeys()
	call s:Bind_Term_Map_Keys()
endfunction

" VIM 启动的时候绑定一次
function! s:Bind_Nor_Map_Keys()
	" 服务启动唤醒键映射
	nnoremap <silent> <Plug>EasyDebuggerInspect :call easydebugger#InspectInit()<CR>
	nnoremap <silent> <Plug>EasyDebuggerWebInspect :call easydebugger#WebInspectInit()<CR>
	" 调试快捷键映射
	nnoremap <silent> <Plug>EasyDebuggerContinue :call easydebugger#InspectCont()<CR>
	nnoremap <silent> <Plug>EasyDebuggerNext :call easydebugger#InspectNext()<CR>
	nnoremap <silent> <Plug>EasyDebuggerStepIn :call easydebugger#InspectStep()<CR>
	nnoremap <silent> <Plug>EasyDebuggerStepOut :call easydebugger#InspectOut()<CR>
	nnoremap <silent> <Plug>EasyDebuggerPause :call easydebugger#InspectPause()<CR>
	" 设置断点快捷键映射
	nnoremap <silent> <Plug>EasyDebuggerSetBreakPoint :call easydebugger#InspectSetBreakPoint()<CR>
endfunction

" 每次进入一个新 Buffer 都要重新绑定一次
function! s:Bind_Term_Map_Keys()
	exec "tnoremap <silent> <Plug>EasyDebuggerContinue ".easydebugger#GetCtrlCmd('ctrl_cmd_continue')
	exec "tnoremap <silent> <Plug>EasyDebuggerNext ".easydebugger#GetCtrlCmd('ctrl_cmd_next')
	exec "tnoremap <silent> <Plug>EasyDebuggerStepIn ".easydebugger#GetCtrlCmd('ctrl_cmd_stepin')
	exec "tnoremap <silent> <Plug>EasyDebuggerStepOut ".easydebugger#GetCtrlCmd('ctrl_cmd_stepout')
	exec "tnoremap <silent> <Plug>EasyDebuggerPause ".easydebugger#GetCtrlCmd('ctrl_cmd_pause')
endfunction

function! s:Build_Command()
	command! -nargs=0 -complete=command -buffer InspectInit call easydebugger#InspectInit()
	command! -nargs=0 -complete=command -buffer WebInspectInit call easydebugger#WebInspectInit()
	command! -nargs=0 -complete=command InspectCont call easydebugger#InspectCont()
	command! -nargs=0 -complete=command InspectNext call easydebugger#InspectNext()
	command! -nargs=0 -complete=command InspectStep call easydebugger#InspectStep()
	command! -nargs=0 -complete=command InspectOut  call easydebugger#InspectOut()
	command! -nargs=0 -complete=command InspectPause call easydebugger#InspectPause()
endfunction

function! s:Create_Lang_Setup()
	if index(g:Debug_Lang_Supported, &filetype) >= 0
		call execute('let g:language_setup = debugger#'. &filetype .'#Setup()' )
		if exists("g:language_setup")
			let g:language_setup.language = &filetype
		endif
	else
		let g:language_setup = 0
		unlet g:language_setup 
	endif
endfunction

function! easydebugger#GetCtrlCmd(cmd)
	if !exists('g:language_setup') || !s:Language_supported(get(g:language_setup,"language")) 
		return "should_execute_nothing"
	endif
	if has_key(g:language_setup, a:cmd)
		return get(g:language_setup, a:cmd) . "<CR>"
	else
		return "should_execute_nothing"
	endif
endfunction

function! easydebugger#InspectInit()
	call s:Create_Lang_Setup()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectInit')()
endfunction

function! easydebugger#WebInspectInit()
	call s:Create_Lang_Setup()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'WebInspectInit')()
endfunction

function! easydebugger#InspectCont()
	call s:Create_Lang_Setup()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectCont')()
endfunction

function! easydebugger#InspectNext()
	call s:Create_Lang_Setup()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectNext')()
endfunction

function! easydebugger#InspectStep()
	call s:Create_Lang_Setup()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectStep')()
endfunction

function! easydebugger#InspectOut()
	call s:Create_Lang_Setup()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectOut')()
endfunction

function! easydebugger#InspectPause()
	call s:Create_Lang_Setup()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectPause')()
endfunction

function! easydebugger#InspectSetBreakPoint()
	call s:Create_Lang_Setup()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectSetBreakPoint')()
endfunction

" 判断语言是否支持
function! s:Language_supported(...)
	" 如果是 quickfix window 和 tagbar 时忽略
	let ft = exists(a:0) ? a:0 : &filetype
	return index(extend(deepcopy(g:Debug_Lang_Supported),['qf','tagbar']), ft) >= 0 ? 1 : 0
endfunction

" TODO:
" - 调试窗口启动位置可配置，比如在底部打开
" - Quickfix：执行到某一行，打印出当前行所在所有变量的值，以及 watch 变量的值
"   参照：https://github.com/cpiger/NeoDebug
"   https://github.com/huawenyu/neogdb.vim

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
	
	let g:Debug_Lang_Supported = ["javascript","go"]
	let g:None_Lang_Sp_Msg = "不支持该语言，或者需要将光标切换到调试窗口, ".
				\ "not support current lang"

	if index(g:Debug_Lang_Supported, &filetype) >= 0
		call execute('let g:language_setup = debugger#'. &filetype .'#Setup()' )
	endif

	call s:Bind_Map_Keys()
endfunction

function! s:Bind_Map_Keys()
	" 服务启动唤醒键映射
	nnoremap <silent> <Plug>EasyDebuggerInspect :call easydebugger#InspectInit()<CR>
	nnoremap <silent> <Plug>EasyDebuggerWebInspect :call easydebugger#WebInspectInit()<CR>
	" 调试快捷键映射
	nnoremap <silent> <Plug>EasyDebuggerContinue :call easydebugger#InspectCont()<CR>
	exec "tnoremap <silent> <Plug>EasyDebuggerContinue ".easydebugger#GetCtrlCmd('ctrl_cmd_continue')
	nnoremap <silent> <Plug>EasyDebuggerNext :call easydebugger#InspectNext()<CR>
	exec "tnoremap <silent> <Plug>EasyDebuggerNext ".easydebugger#GetCtrlCmd('ctrl_cmd_next')
	nnoremap <silent> <Plug>EasyDebuggerStepIn :call easydebugger#InspectStep()<CR>
	exec "tnoremap <silent> <Plug>EasyDebuggerStepIn ".easydebugger#GetCtrlCmd('ctrl_cmd_stepin')
	nnoremap <silent> <Plug>EasyDebuggerStepOut :call easydebugger#InspectOut()<CR>
	exec "tnoremap <silent> <Plug>EasyDebuggerStepOut ".easydebugger#GetCtrlCmd('ctrl_cmd_stepout')
	nnoremap <silent> <Plug>EasyDebuggerPause :call easydebugger#InspectPause()<CR>
	exec "tnoremap <silent> <Plug>EasyDebuggerPause ".easydebugger#GetCtrlCmd('ctrl_cmd_pause')
	" 设置断点快捷键映射
	nnoremap <silent> <Plug>EasyDebuggerSetBreakPoint :call easydebugger#InspectSetBreakPoint()<CR>

	command! -nargs=0 -complete=command -buffer InspectInit call easydebugger#InspectInit()
	command! -nargs=0 -complete=command -buffer WebInspectInit call easydebugger#WebInspectInit()
	command! -nargs=0 -complete=command InspectCont call easydebugger#InspectCont()
	command! -nargs=0 -complete=command InspectNext call easydebugger#InspectNext()
	command! -nargs=0 -complete=command InspectStep call easydebugger#InspectStep()
	command! -nargs=0 -complete=command InspectOut  call easydebugger#InspectOut()
	command! -nargs=0 -complete=command InspectPause call easydebugger#InspectPause()
endfunction

function! easydebugger#GetCtrlCmd(cmd)
	if !s:Language_supported() || !exists('g:language_setup')
		return "should_execute_nothing"
	endif
	if has_key(g:language_setup, a:cmd)
		return get(g:language_setup, a:cmd) . "<CR>"
	else
		return "should_execute_nothing"
	endif
endfunction

function! easydebugger#InspectInit()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectInit')()
endfunction

function! easydebugger#WebInspectInit()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'WebInspectInit')()
endfunction

function! easydebugger#InspectCont()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectCont')()
endfunction

function! easydebugger#InspectNext()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectNext')()
endfunction

function! easydebugger#InspectStep()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectStep')()
endfunction

function! easydebugger#InspectOut()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectOut')()
endfunction

function! easydebugger#InspectPause()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectPause')()
endfunction

function! easydebugger#InspectSetBreakPoint()
	if !s:Language_supported() || !exists('g:language_setup')
		call lib#util#LogMsg(g:None_Lang_Sp_Msg)
		return ""
	endif
	call get(g:language_setup,'InspectSetBreakPoint')()
endfunction

" 判断语言是否支持
function! s:Language_supported()
	" 如果是 quickfix window 和 tagbar 时忽略
	return index(extend(g:Debug_Lang_Supported,['qf','tagbar']), &filetype) >= 0 ? 1 : 0
endfunction

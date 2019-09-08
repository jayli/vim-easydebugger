" 文件说明：
" file: debugger/runtime.vim 这里是 Debugger 运行时的标准实现，无特殊情况应当
" 优先使用这些默认实现，如果不能满足当前调试器（比如 go 语言的 delve 不支持
" pause），就需要重新实现一下，在 debugger/[编程语言].vim 中重写

" 实现原理：
" Debugger 程序运行在 Term 内，VIM 创建 Term 时可以绑定输出回调，通过监听 Term
" 内的输出字符来执行单步执行、继续执行、暂停、输出回调堆栈等等操作，VIM 作为
" UI 层的交互，由于 Term 回调机制可以更好的完成，难度不大，关键是做好各个语言
" 的 Debugger 输出的格式过滤，目前已经将 runtime.vim 基本抽象出来了，debugger
" 目录下的 [编程语言].vim 的实现基于这个 runtime 抽象，目前有这些已经定义好的
" 接口：
"   - ctrl_cmd_continue : {string} : Debugger 继续执行的命令
"   - ctrl_cmd_next : {string} : Debugger 单步执行的命令
"   - ctrl_cmd_stepin : {string} : Debugger 进入函数的命令
"   - ctrl_cmd_stepout : {string} : Debugger 退出函数的命令
"   - ctrl_cmd_pause : {string} : Debugger 程序暂停的命令
"   - InspectInit : {function} : Debugger 启动函数
"   - WebInspectInit : {function} : Debugger Web 服务启动函数
"   - InspectCont : {function} : 继续执行的函数
"   - InspectNext : {function} : 单步执行的函数
"   - InspectStep : {function} : 单步进入的函数
"   - InspectOut : {function} : 退出函数
"   - InspectPause : {function} : 暂停执行的函数
"   - InspectSetBreakPoint : {function} : 设置断点主函数
"   - DebuggerTester : {function} : 判断当前语言的 Debugger 是否安装
"   - ClearBreakPoint : {function} : 返回清除断点的命令字符串
"   - SetBreakPoint : {function} : 返回添加断点的命令字符串
"   - TermSetupScript : {function} : Terminal 初始化完成后执行的脚本
"   - AfterStopScript : {function} : 程序进行到新行后追加的执行的脚本
"   - TermCallbackHandler : {function} : Terminal 有输出回调时，会追加执行的脚本
"   - DebuggerNotInstalled : {string} : Debugger 未安装的提示文案
"   - WebDebuggerCommandPrefix : {string} : Debugger Web 服务启动的命令前缀
"   - LocalDebuggerCommandPrefix : {string} : Debugger 启动的命令前缀
"   - LocalDebuggerCommandSufix : {string} : Debugger 命令启动的后缀
"   - ExecutionTerminatedMsg : {regex} : 判断 Debugger 运行结束的结束语正则
"   - BreakFileNameRegex : {regex} : 获得程序停驻所在文件的正则
"   - BreakLineNrRegex : {regex} : 获得程序停驻行号的正则

" 启动 Chrome DevTools 模式的调试服务
function! lib#runtime#WebInspectInit()
	if exists("g:debugger") && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call s:LogMsg("请先关掉正在运行的调试器, Only One Running Debugger is Allowed..")
		return ""
	endif

	if !get(g:language_setup,'DebuggerTester')()
		if has_key(g:language_setup, 'DebuggerNotInstalled')
			call s:LogMsg(get(g:language_setup,'DebuggerNotInstalled'))
		endif
		return ""
	endif

	let l:command = get(g:language_setup,'WebDebuggerCommandPrefix') . ' ' . getbufinfo('%')[0].name
	if has_key(g:language_setup, "LocalDebuggerCommandSufix")
		let l:full_command = s:StringTrim(l:command . ' ' . get(g:language_setup, "LocalDebuggerCommandSufix"))
	else
		let l:full_command = s:StringTrim(l:command)
	endif
	if version <= 800
		call system(l:full_command)
	else 
		call term_start(l:full_command,{ 
			\ 'term_finish': 'close',
			\ 'term_cols':s:Get_Term_Width(),
			\ 'vertical':'1',
			\ })
	endif
	call s:Echo_debugging_info(l:full_command)
endfunction

" VIM 调试模式
function! lib#runtime#InspectInit()
	if exists("g:debugger") && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call s:LogMsg("请先关掉正在运行的调试器, Only One Running Debugger is Allowed..")
		return ""
	endif

	if !get(g:language_setup,'DebuggerTester')()
		if has_key(g:language_setup, 'DebuggerNotInstalled')
			call s:LogMsg(get(g:language_setup,'DebuggerNotInstalled'))
		endif
		return ""
	endif

	let l:command = get(g:language_setup,'LocalDebuggerCommandPrefix') . ' ' . getbufinfo('%')[0].name
	if has_key(g:language_setup, "LocalDebuggerCommandSufix")
		let l:full_command = s:StringTrim(l:command . ' ' . get(g:language_setup, "LocalDebuggerCommandSufix"))
	else
		let l:full_command = s:StringTrim(l:command)
	endif
	" 创建 g:debugger ，最重要的一个全局变量
	call s:Create_Debugger()
	call lib#runtime#Reset_Editor('silently')
	if version <= 800
		call system(l:full_command)
	else 
		call s:Set_Debug_CursorLine()
		exec "vertical botright split new"
		call term_start(l:full_command,{ 
			\ 'term_finish': 'close',
			\ 'term_name':get(g:debugger,'debugger_window_name') ,
			\ 'vertical':'1',
			\ 'curwin':'1',
			\ 'out_cb':'lib#runtime#Term_callback',
			\ 'close_cb':'lib#runtime#Reset_Editor',
			\ })
		" 记录 Term 的 Winid
		let g:debugger.term_winid = bufwinid(get(g:debugger,'debugger_window_name'))
		" 监听 Terminal 模式里的回车键
		tnoremap <silent> <CR> <C-\><C-n>:call lib#runtime#Special_Cmd_Handler()<CR>i<C-P><Down>
		call term_wait(get(g:debugger,'debugger_window_name'))
		call s:Debugger_Stop_Action(g:debugger.log)

		" Jayli
		" 如果定义了 Quickfix Window 的输出日志的逻辑，则打开 Quickfix Window
		if has_key(g:language_setup,"AfterStopScript")
			" exec "keepa bo 1new" " 打开一个新窗口
			" call s:Open_qfwindow()
			" call s:Open_localistwindow() " 是否打开这行，对结果不影响
		endif

		" 启动调试器后执行需要运行的脚本，有的调试器是需要的（比如go）
		if has_key(g:language_setup, "TermSetupScript")
			call get(g:language_setup,"TermSetupScript")()
		endif

		call s:Open_localvars_window()
	endif
endfunction

" 在调试窗口下方打开一个新窗口
function s:Open_localvars_window()


endfunction

function! lib#runtime#InspectCont()
	if !exists('g:debugger')
		call s:LogMsg("请先启动 Debugger, Please Run Debugger First..")
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_continue."\<CR>")
	endif
endfunction

function! lib#runtime#InspectNext()
	if !exists('g:debugger')
		call s:LogMsg("请先启动 Debugger, Please Run Debugger First..")
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_next."\<CR>")
	endif
endfunction

function! lib#runtime#InspectStep()
	if !exists('g:debugger')
		call s:LogMsg("请先启动 Debugger, Please Run Debugger First..")
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_stepin."\<CR>")
	endif
endfunction

function! lib#runtime#InspectOut()
	if !exists('g:debugger')
		call s:LogMsg("请先启动 Debugger, Please Run Debugger First..")
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_stepout."\<CR>")
	endif
endfunction

function! lib#runtime#InspectPause()
	if !exists('g:debugger')
		call s:LogMsg("请先启动 Debugger, Please Run Debugger First..")
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_pause."\<CR>")
	endif
endfunction

" 设置/取消断点，在当前行按 F12
function! lib#runtime#InspectSetBreakPoint()
	if !exists('g:debugger') || term_getstatus(get(g:debugger,'debugger_window_name')) != 'running'
		call s:LogMsg("请先启动 Debugger, Please Run Debugger First..")
		return ""
	endif
	" 如果是当前文件所在的 Buf 或者是临时加载的 Buf
	if exists("g:debugger") && (bufnr('') == g:debugger.original_bnr || index(g:debugger.bufs,bufname('%')) >= 0)
		let line = line('.')
		let fname = bufname('%')
		let breakpoint_contained = index(g:debugger.break_points, fname."|".line)
		if breakpoint_contained >= 0
			" 已经存在 BreakPoint，则清除掉 BreakPoint
			call term_sendkeys(get(g:debugger,'debugger_window_name'),lib#runtime#clearBreakpoint(fname,line))
			let sid = string(index(g:debugger.break_points, fname."|".line) + 1)
			exec ":sign unplace ".sid." file=".s:Get_Fullname(fname)
			call remove(g:debugger.break_points, breakpoint_contained)
			call s:LogMsg("取消断点成功")
		else
			" 如果不存在 BreakPoint，则新增 BreakPoint
			call term_sendkeys(get(g:debugger,'debugger_window_name'),lib#runtime#setBreakpoint(fname,line))
			call add(g:debugger.break_points, fname."|".line)
			let g:debugger.break_points =  uniq(g:debugger.break_points)
			let sid = string(index(g:debugger.break_points, fname."|".line) + 1)
			exec ":sign place ".sid." line=".line." name=break_point file=".s:Get_Fullname(fname)
			call s:LogMsg("设置断点成功")
		endif
	endif
endfunction

" 清除断点
function! lib#runtime#clearBreakpoint(fname,line)
	return get(g:language_setup, "ClearBreakPoint")(a:fname,a:line)
endfunction

" 设置断点
function! lib#runtime#setBreakpoint(fname,line)
	return get(g:language_setup, "SetBreakPoint")(a:fname,a:line)
endfunction

" 退出 Terminal 时重置编辑器
" 可传入单独的参数：
" - silently: 不关闭Term
function! lib#runtime#Reset_Editor(...)
	if !exists("g:debugger") 
		return
	endif
	call s:Goto_sourcecode_window()
	" 短名长名都不等，当前所在buf不是原始buf的话，先切换到原始Buf
	if g:debugger.original_bufname !=  bufname('%') &&
				\ g:debugger.original_bufname != fnameescape(fnamemodify(bufname('%'),':p'))
		exec ":b ". g:debugger.original_bufname
	endif
	call s:Debugger_del_tmpbuf()
	if g:debugger.original_cursor_color
		" 恢复 CursorLine 的高亮样式
		call execute("setlocal cursorline","silent!")
		call execute("hi CursorLine ctermbg=".g:debugger.original_cursor_color,"silent!")
	endif
	if g:debugger.original_winid != bufwinid(bufnr(""))
		if !(type(a:1) == type('string') && a:1 == 'silently')
			call feedkeys("\<S-ZZ>")
		endif
		" call s:Show_Close_Msg()
	endif
	call s:Clear_All_Signs()
	call execute('redraw','silent!')
	" 最后清空本次 Terminal 里的 log
	"call s:LogMsg("调试结束,Debug over..")
	"call s:Close_qfwidow()
	call s:Close_localistwindow()
	let g:debugger.log = []
	if exists('g:debugger._prev_msg')
		unlet g:debugger._prev_msg
	endif
endfunction

" Terminal 消息回传
function! lib#runtime#Term_callback(channel, msg)
	" 如果消息为空
	" 如果消息长度为1，说明正在敲入字符
	" 如果首字母和尾字符ascii码值在[0,31]是控制字符，说明正在删除字符，TODO 这
	" 句话不精确
	"call s:LogMsg("--- " . a:msg . " --- 首字母 Ascii 码是: ". char2nr(a:msg))
	if !exists('g:debugger._prev_msg')
		let g:debugger._prev_msg = a:msg
	endif
	if !exists('g:debugger') || empty(a:msg) || 
				\ len(a:msg) == 1 || 
				\ (!s:Is_Ascii_Visiable(a:msg) && len(a:msg) == len(g:debugger._prev_msg) - 1)
				"\ char2nr(a:msg) == 13"
		"call s:LogMsg("=== 被拦截了, 首字母iscii码是: ". char2nr(a:msg))
		return
	endif
	let g:debugger._prev_msg = a:msg
	let m = substitute(a:msg,"\\W\\[\\d\\{-}[a-zA-Z]","","g")
	let msgslist = split(m,"\r\n")
	let g:debugger.log += msgslist
	" let g:debugger.log += [""]
	" 为了防止 log 过长带来的性能问题，这里做一个上限
	let log_max_length = 50
	if len(g:debugger.log) >= log_max_length
		unlet g:debugger.log[0:len(g:debugger.log) - (log_max_length)]
	endif
	let full_log = deepcopy(g:debugger.log)

	if has_key(g:language_setup, "ExecutionTerminatedMsg") && 
				\ a:msg =~ get(g:language_setup, "ExecutionTerminatedMsg")
		call s:Show_Close_Msg()
		call lib#runtime#Reset_Editor('silently')
		" 调试终止之后应该将光标停止在 Term 内
		if winnr() != get(g:debugger, 'original_winnr')
			call s:Goto_terminal_window()
		endif
	else
		call s:Debugger_Stop_Action(g:debugger.log)
	endif

	if has_key(g:language_setup,"TermCallbackHandler")
		call g:language_setup.TermCallbackHandler(full_log)
	endif

endfunction

" 判断首字母是否是可见的 ASCII 码
function! s:Is_Ascii_Visiable(c)
	if char2nr(a:c) >= 32 && char2nr(a:c) <= 126
		return 1
	else
		return 0
	endif
endfunction

" 输出初始调试信息
function! s:Echo_debugging_info(command)
	call s:LogMsg(a:command . ' ' . ' : [Quit with "exit<CR>" or <Ctrl-C><Ctrl-C>].')
endfunction

" 设置停驻的行高亮样式
function! s:Set_Debug_CursorLine()
	" Do Nothing
	" 停驻行的跳转使用 cursor() 完成
	" 停驻行的样式使用 setlocal nocursorline 清除掉，以免光标样式覆盖 sign linehl 样式
	" 清除样式的时机在 Debugger_Stop_Action() 函数内
	" 调试结束后恢复默认 cursorline 样式： setlocal cursorline
endfunction

" 获得 term 宽度
function! s:Get_Term_Width()
	if winwidth(winnr()) >= 130
		let term_width = 40 
		let term_width = float2nr(floor(winwidth(winnr()) * 40 / 100))
	else
		let term_width = float2nr(floor(winwidth(winnr()) * 25 / 100))
	endif
	return term_width
endfunction

" 将标记清除
function! s:Clear_All_Signs()
	exec ":sign unplace 100 file=".s:Get_Fullname(g:debugger.original_bufname)
	for bfname in g:debugger.bufs
		exec ":sign unplace 100 file=".s:Get_Fullname(bfname)
	endfor
	for item in g:debugger.break_points
		" break_points 的存储格式为: ['a.js|3','t/b.js|34']
		" break_points 里的索引作为 sign id
		let fname = split(item,"|")[0]
		let line  = split(item,"|")[1]
		let sid   = string(index(g:debugger.break_points, item) + 1)
		exec ":sign unplace ".sid." file=".s:Get_Fullname(fname)
	endfor
	" 退出 Debug 时清除当前所有断点
	let g:debugger.break_points = []
endfunction

" 显示 Term 窗口关闭消息
function! s:Show_Close_Msg()
	call s:LogMsg(bufname('%')." ". get(g:debugger,'close_msg'))
endfunction

" 设置停留的代码行
function! s:Debugger_Stop_Action(log)
	let break_msg = s:Get_Term_Stop_Msg(a:log)
	if type(break_msg) == type({})
		call s:Debugger_Stop(get(break_msg,'fname'), get(break_msg,'breakline'))
	endif
endfunction

" 处理Termnal里的log,这里的 log 是 g:debugger.log
" 这里比较奇怪，Log 不是整片输出的，是碎片输出的
function! s:Get_Term_Stop_Msg(log)
	if len(a:log) == 0
		return 0
	endif

	" 因为碎片输出，这里会被执行很多次，可能有潜在的性能问题
	let break_line = 0
	let fname = ''
	let fn_regex = get(g:language_setup, "BreakFileNameRegex")
	let nr_regex = get(g:language_setup, "BreakLineNrRegex")

	for line in a:log
		let fn = matchstr(line, fn_regex)
		let nr = matchstr(line, nr_regex)
		if s:StringTrim(fn) != ''
			let fname = fn
		endif
		if s:StringTrim(nr) != ''
			let break_line = str2nr(nr)
		endif
	endfor
	
	if break_line != 0 && fname != ''
		return {"fname":fname, "breakline":break_line}
	else 
		return 0
	endif
endfunction

" 相当于 trim，去掉首尾的空字符
function! s:StringTrim(str)
	return lib#util#StringTrim(a:str)
endfunction

" 创建全局 g:debugger 对象
function! s:Create_Debugger()
	let g:debugger = {}
	if !exists('g:debugger_window_id')
		let g:debugger_window_id = 1
	else
		let g:debugger_window_id += 1
	endif
	
	" 调试窗口随机一下，其实不用随机，固定名字也可以
	let g:debugger.debugger_window_name = "dw" . g:debugger_window_id
	let g:debugger.original_bnr         = bufnr('')
	" winnr 并不和 最初的 Buf 强绑定，原始 winnr 不能作为 window 的标识
	" 要用 bufinfo 里的 windows 数组来代替唯一性
	let g:debugger.original_winnr       = winnr()
	let g:debugger.original_winid       = bufwinid(bufnr(""))
	let g:debugger.original_buf         = getbufinfo(bufnr(''))
	let g:debugger.cwd                  = getcwd()
	let g:debugger.original_bufname     = bufname('%')
	let g:debugger.original_line_nr     = line(".")
	let g:debugger.original_col_nr      = col(".")
	let g:debugger.buf_winnr            = bufwinnr('%')
	let g:debugger.current_winnr        = -1
	let g:debugger.bufs                 = []
	let g:debugger.stop_line            = 0
	let g:debugger.stop_fname           = ''
	let g:debugger.log                  = []
	let g:debugger.close_msg            = "调试结束,两个<Ctrl-C>结束掉,或者输入exit回车结束掉, " .
										\ "Debug Finished, <C-C><C-C> to Close Term..."
	" break_points: ['a.js|3','t/b.js|34']
	" break_points 里的索引作为 sign id
	let g:debugger.break_points= []
	" 原始的光标行背景色
	let g:debugger.original_cursor_color = lib#util#Get_CursorLine_bgColor()
	" 这句话没用其实
	call add(g:debugger.bufs, s:Get_Fullname(g:debugger.original_bufname))
	exec "hi BreakPointStyle ctermfg=197 ctermbg=". lib#util#Get_BgColor('SignColumn')
	exec "hi StopPointLineStyle ctermbg=19"
	exec "hi StopPointTextStyle cterm=bold ctermfg=green ctermbg=".lib#util#Get_BgColor('SignColumn')
	" 定义一个占位符，防止 sigin 切换时的抖动, id 为 9999
	exec 'hi PlaceHolder ctermfg='. lib#util#Get_BgColor('SignColumn') . 
				\ ' ctermbg='. lib#util#Get_BgColor('SignColumn')
	exec 'sign define place_holder text=>> texthl=PlaceHolder'
	" 语句执行位置标记 id=100
	exec 'sign define stop_point text=>> texthl=StopPointTextStyle linehl=StopPointLineStyle'
	" 断点标记 id 以 g:debugger.break_points 里的索引 +1 来表示
	exec 'sign define break_point text=** texthl=BreakPointStyle'
	return g:debugger
endfunction

" 执行到什么文件的什么行
function! s:Debugger_Stop(fname, line)
	let fname = s:Get_Fullname(a:fname)

	" 如果当前停驻行和文件较上次没变化，则什么也不做
	if fname == g:debugger.stop_fname && a:line == g:debugger.stop_line
		return
	endif

	let g:debugger.stop_fname = fname
	let g:debugger.stop_line = a:line

	call s:Goto_sourcecode_window()
	let fname = s:Debugger_get_filebuf(fname)
	" 如果读到一个不存在的文件，认为进入到 Native 部分的 Debugging，
	" 比如进入到了 Node Native 部分 Debugging, node inspect 没有给
	" 出完整路径，调试不得不中断
	if (type(fname) == type(0) && fname == 0) || (type(fname) == type('string') && fname == '0')
		call term_sendkeys(get(g:debugger,'debugger_window_name'),"kill\<CR>")
		call lib#runtime#Reset_Editor('silently')
		call s:Show_Close_Msg()
		return
	endif
	call execute('setlocal nocursorline','silent!')
	call s:Sign_Set_StopPoint(fname, a:line)
	call cursor(a:line,1)
	call s:LogMsg('程序执行到 '.fname.' 的第 '.a:line.' 行。 ' . 
				\  '[Quit with "exit<CR>" or <Ctrl-C><Ctrl-C>].')
	if has_key(g:language_setup, 'AfterStopScript')
		call get(g:language_setup, 'AfterStopScript')(g:debugger.log)
	endif
	" 凡是执行完停驻行跳转的动作，都重新定位到 Term 里，方便用户直接输入命令
	call s:Goto_terminal_window()
	" 只要重新停驻到新行，这一阶段的解析就完成了，log清空
	let g:debugger.log = []
endfunction

" 重新设置 Break Point 的 Sign 标记的位置
function! s:Sign_Set_StopPoint(fname, line)
	try
		" sign 9999 是为了防止界面抖动
		exec ":sign place 9999 line=1 name=place_holder file=".s:Get_Fullname(a:fname)
		exec ":sign unplace 100 file=".s:Get_Fullname(a:fname)
		exec ":sign place 100 line=".string(a:line)." name=stop_point file=".s:Get_Fullname(a:fname)
		exec ":sign unplace 9999 file=".s:Get_Fullname(a:fname)
	catch
	endtry
endfunction

" s:goto_win(winnr) 
function! s:Goto_winnr(winnr) abort
    let cmd = type(a:winnr) == type(0) ? a:winnr . 'wincmd w'
                                     \ : 'wincmd ' . a:winnr
	noautocmd execute cmd
	call execute('redraw','silent!')
endfunction

" 跳转到原始源码所在的窗口
function! s:Goto_sourcecode_window()
	call g:Goto_window(g:debugger.original_winid)
endfunction

" 跳转到 Term 所在的窗口
function! s:Goto_terminal_window()
	if exists("g:debugger") && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call g:Goto_window(get(g:debugger,'term_winid'))
	endif
endfunction

" 打开 Quickfix window
function! s:Open_qfwindow()
	call s:Goto_sourcecode_window()
	call execute('below copen','silent!')
endfunction

function! s:Open_localistwindow()
	call s:Goto_sourcecode_window()
	call execute('below lopen','silent!')
endfunction

function g:Open_localistwindow_once()
	if !exists('g:debugger.lopen_done') || g:debugger.lopen_done != 1
		call s:Goto_sourcecode_window()
		" call s:Goto_terminal_window()
		call execute("below lopen",'silent!')
		let g:debugger.lopen_done = 1
	endif
endfunction


function! s:Close_localistwindow()
	call execute('lclose','silent!')
endfunction

" 关闭 Quickfix window
function! s:Close_qfwidow()
	call execute('cclose','silent!')
endfunction

" 跳转到 Window
function! g:Goto_window(winid) abort
	if a:winid == bufwinid(bufnr(""))
		return
	endif
	for window in range(1, winnr('$'))
		call s:Goto_winnr(window)
		if a:winid == bufwinid(bufnr(""))
			break
		endif
	endfor
endfunction

" 如果跳转到一个新文件，新增一个 Buffer
" fname 是文件绝对地址
function! s:Debugger_add_filebuf(fname)
	exec ":badd ". a:fname
	exec ":b ". a:fname
	call add(g:debugger.bufs, a:fname)
endfunction

" 退出调试后需要删除这些新增的 Buffer
function! s:Debugger_del_tmpbuf()
	let tmp_bufs = deepcopy(g:debugger.bufs)
	for t_buf in tmp_bufs
		" 如果 Buf 短名不是原始值，长名也不是原始值
		if t_buf != g:debugger.original_bufname && 
					\ s:Get_Fullname(g:debugger.original_bufname) != s:Get_Fullname(t_buf)
			call execute('bdelete! '.t_buf,'silent!')
		endif
	endfor
	let g:debugger.bufs = []
endfunction

" 获得当前Buffer里的文件名字
function! s:Debugger_get_filebuf(fname)
	" bufname用的相对路径为绝对路径:fixed
	let fname = s:Get_Fullname(a:fname)
	if !filereadable(fname)
		return 0
	endif
	if index(g:debugger.bufs , fname) < 0 
		call s:Debugger_add_filebuf(fname)
	endif
	if fname != s:Get_Fullname(bufname("%"))
		" call execute('redraw','silent!')
		call execute('buffer '.a:fname)
	endif
	return fname
endfunction

" 获得完整路径
function! s:Get_Fullname(fname)
	return fnameescape(fnamemodify(a:fname,':p'))
endfunction

" 关闭 Terminal
function! s:Close_Term()
	call term_sendkeys(get(g:debugger,'debugger_window_name'),"\<CR>\<C-C>\<C-C>")
	if exists('g:debugger') && g:debugger.original_winid != bufwinid(bufnr(""))
		call feedkeys("\<C-C>\<C-C>", 't')
		unlet g:debugger.term_winid
	endif
	call execute('redraw','silent!')
	call s:LogMsg("调试结束,Debug over..")
endfunction

" 命令行的特殊命令处理：比如这里输入 exit 直接关掉 Terminal
function! lib#runtime#Special_Cmd_Handler()
	let cmd = getline('.')[0 : col('.')-1]
	let cmd = s:StringTrim(substitute(cmd,"^.*debug>\\s","","g"))
	if cmd == 'exit'
		call s:Close_Term()
	elseif cmd == 'restart'
		call s:Set_Debug_CursorLine()
	elseif cmd == 'run'
		call s:Set_Debug_CursorLine()
	endif
	call term_sendkeys(get(g:debugger,'debugger_window_name'),"\<CR>")
endfunction

" 输出 LogMsg
function! s:LogMsg(msg)
	call lib#util#LogMsg(a:msg)
endfunction


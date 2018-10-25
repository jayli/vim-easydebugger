" file: debugger/runtime.vim 这里是 Debugger 运行时的标准实现，无特殊情况应当
" 优先使用这些默认实现，如果不能满足当前调试器（比如 go 语言的 delve 不支持
" pause），就需要重新实现一下，就放在 debugger/[编程语言].vim 中重写下就好了

" 启动Chrome DevTools 模式的调试服务
function! debugger#runtime#WebInspectInit()
	if exists("g:debugger") && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call s:LogMsg("请先关掉正在运行的调试器")
		return ""
	endif

	if !get(g:language_setup,'DebuggerTester')()
		call s:LogMsg(get(g:language_setup,'DebuggerNotInstalled'))
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
function! debugger#runtime#InspectInit()
	if exists("g:debugger") && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call s:LogMsg("请先关掉正在运行的调试器")
		return ""
	endif

	if !get(g:language_setup,'DebuggerTester')()
		call s:LogMsg(get(g:language_setup,'DebuggerNotInstalled'))
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
	call debugger#runtime#Reset_Editor('silently')
	if version <= 800
		call system(l:full_command)
	else 

		call term_start(l:full_command,{ 
						\ 'term_finish': 'close',
						\ 'term_name':get(g:debugger,'debugger_window_name') ,
						\ 'term_cols':s:Get_Term_Width(),
						\ 'vertical':'1',
						\ 'out_cb':'debugger#runtime#Term_callback',
						\ 'close_cb':'debugger#runtime#Reset_Editor',
						\ })
		if !exists('g:debugger_term_winnr')
			let g:debugger_term_winnr = bufnr(get(g:debugger,'debugger_window_name'))
		endif
		let g:debugger.term_winnr = string(g:debugger_term_winnr)
		" 监听 Terminal 模式里的回车键，这个会带来代码视窗的抖动 TODO
		tnoremap <silent> <CR> <C-\><C-n>:call debugger#runtime#Special_Cmd_Handler()<CR>i<C-P><Down>
		call term_wait(get(g:debugger,'debugger_window_name'))
		call s:Debugger_Break_Action(g:debugger.log)

		call s:Set_Debug_CursorLine()

		" 启动调试器后执行需要运行的脚本，有的调试器是需要的（比如go）
		if has_key(g:language_setup, "TermSetupScript")
			call get(g:language_setup,"TermSetupScript")()
		endif
		call s:Echo_debugging_info(l:full_command)
	endif
endfunction

function! debugger#runtime#InspectCont()
	if !exists('g:debugger')
		call s:LogMsg(g:None_Run_Msg)
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_continue."\<CR>")
	endif
endfunction

function! debugger#runtime#InspectNext()
	if !exists('g:debugger')
		call s:LogMsg(g:None_Run_Msg)
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_next."\<CR>")
	endif
endfunction

function! debugger#runtime#InspectStep()
	if !exists('g:debugger')
		call s:LogMsg(g:None_Run_Msg)
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_stepin."\<CR>")
	endif
endfunction

function! debugger#runtime#InspectOut()
	if !exists('g:debugger')
		call s:LogMsg(g:None_Run_Msg)
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_stepout."\<CR>")
	endif
endfunction

function! debugger#runtime#InspectPause()
	if !exists('g:debugger')
		call s:LogMsg(g:None_Run_Msg)
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_pause."\<CR>")
	endif
endfunction

" 设置/取消断点，在当前行按 F12
function! debugger#runtime#InspectSetBreakPoint()
	if !exists('g:debugger') || term_getstatus(get(g:debugger,'debugger_window_name')) != 'running'
		call s:LogMsg(g:None_Run_Msg)
		return ""
	endif
	" 如果是当前文件所在的 Buf 或者是临时加载的 Buf
	if exists("g:debugger") && (bufnr('') == g:debugger.original_bnr || index(g:debugger.bufs,bufname('%')) >= 0)
		let line = line('.')
		let fname = bufname('%')
		let breakpoint_contained = index(g:debugger.break_points, fname."|".line)
		if breakpoint_contained >= 0
			" 已经存在 BreakPoint，则清除掉 BreakPoint
			call term_sendkeys(get(g:debugger,'debugger_window_name'),debugger#runtime#clearBreakpoint(fname,line))
			let sid = string(index(g:debugger.break_points, fname."|".line) + 1)
			exec ":sign unplace ".sid." file=".fname
			call remove(g:debugger.break_points, breakpoint_contained)
		else
			" 如果不存在 BreakPoint，则新增 BreakPoint
			call term_sendkeys(get(g:debugger,'debugger_window_name'),debugger#runtime#setBreakpoint(fname,line))
			call add(g:debugger.break_points, fname."|".line)
			let g:debugger.break_points =  uniq(g:debugger.break_points)
			let sid = string(index(g:debugger.break_points, fname."|".line) + 1)
			exec ":sign place ".sid." line=".line." name=break_point file=".fname
		endif
	endif
endfunction

function! debugger#runtime#clearBreakpoint(fname,line)
	return get(g:language_setup, "ClearBreakPoint")(a:fname,a:line)
endfunction

function! debugger#runtime#setBreakpoint(fname,line)
	return get(g:language_setup, "SetBreakPoint")(a:fname,a:line)
endfunction

" 退出 Terminal 时重置编辑器
" 可传入单独的参数：
" - silently: 不关闭Term
function! debugger#runtime#Reset_Editor(...)
	" 如果多个 Tab 存在，开启 Term 的时候会莫名其妙的调用到这里
	" 不得不加一个保护
	if !exists("g:debugger") || !get(g:debugger, "term_winnr")
		return
	endif
	call execute(g:debugger.term_winnr.'wincmd w','silent!')
	" 短名长名都不等，当前所在buf不是原始buf的话，先切换到原始Buf
	if g:debugger.original_bufname !=  bufname('%') &&
				\ g:debugger.original_bufname != fnameescape(fnamemodify(bufname('%'),':p'))
		exec ":b ". g:debugger.original_bufname
	endif
	call s:Debugger_del_tmpbuf()
	if g:debugger.original_cursor_color
		" 恢复 CursorLine 的高亮样式
		call execute("hi CursorLine ctermbg=".g:debugger.original_cursor_color,"silent!")
	endif
	" if winnr() != g:debugger.original_winnr 
	"if g:debugger.original_buf[0].windows != getbufinfo(bufnr(""))[0].windows
	if g:debugger.original_winid != bufwinid(bufnr(""))
		if !(type(a:1) == type('string') && a:1 == 'silently')
			call feedkeys("\<S-ZZ>")
		else
			call s:Show_Close_Msg()
		endif
	endif
	call s:Clear_All_Signs()
	call execute('redraw','silent!')
	" 最后清空本次 Terminal 里的 log
	let g:debugger.log = []
endfunction

" Terminal 消息回传
function! debugger#runtime#Term_callback(channel, msg)
	if !exists('g:debugger') || empty(a:msg)
		return
	endif
	let m = substitute(a:msg,"\\W\\[\\d\\{-}[a-zA-Z]","","g")
	let g:msgs = split(m,"\r\n")
	let g:debugger.log += g:msgs
	let g:debugger.log += [""]

	if has_key(g:language_setup, "ExecutionTerminatedMsg") && 
				\ a:msg =~ get(g:language_setup, "ExecutionTerminatedMsg")
		call s:Show_Close_Msg()
		call debugger#runtime#Reset_Editor('silently')
		" 调试终止之后应该将光标停止在 Term 内
		if winnr() != get(g:debugger, 'original_winnr')
			call execute(get(g:debugger, 'original_winnr').'wincmd w','silent!')
		endif
	else
		call s:Debugger_Break_Action(g:debugger.log)
	endif
endfunction

function! s:Echo_debugging_info(command)
	call s:LogMsg(a:command . ' ' . " : 点击两次 <Ctrl-C> 终止调试, Press <Ctrl-C><Ctrl-C> to stop debugging..'")
endfunction

" 设置停住的行高亮样式
function! s:Set_Debug_CursorLine()
	if g:debugger.original_cursor_color
		call execute("hi CursorLine ctermbg=18","silent!")
		call execute('redraw','silent!')
	endif
endfunction

" 获得 term 宽度
function! s:Get_Term_Width()
	if winwidth(winnr()) >= 130
		let term_width = 40 
	else
		let term_width = float2nr(floor(winwidth(winnr()) * 25 / 100))
	endif
	return term_width
endfunction

" 将标记清除
function! s:Clear_All_Signs()
	exec ":sign unplace 100 file=".g:debugger.original_bufname
	for bfname in g:debugger.bufs
		exec ":sign unplace 100 file=".bfname
	endfor
	for item in g:debugger.break_points
		" break_points 的存储格式为: ['a.js|3','t/b.js|34']
		" break_points 里的索引作为 sign id
		let fname = split(item,"|")[0]
		let line  = split(item,"|")[1]
		let sid   = string(index(g:debugger.break_points, item) + 1)
		exec ":sign unplace ".sid." file=".fname
	endfor
	" 退出 Debug 时清除当前所有断点
	let g:debugger.break_points = []
endfunction

function! s:Show_Close_Msg()
	call s:LogMsg(bufname('%')." ". get(g:debugger,'close_msg'))
endfunction

" 设置停留的代码行
function! s:Debugger_Break_Action(log)
	let break_msg = s:Get_Term_Break_Msg(a:log)
	if type(break_msg) == type({})
		call s:Debugger_Stop(get(break_msg,'fname'), get(break_msg,'break_line'))
	endif
endfunction

" 处理Termnal里的log
" 这里比较奇怪，Log 不是整片输出的，是碎片输出的
function! s:Get_Term_Break_Msg(log)
	if len(a:log) == 0
		return 0
	endif
	let break_line = 0
	let fname = ''
	let fn_regex = get(g:language_setup, "BreakFileNameRegex")
	let nr_regex = get(g:language_setup, "BreakLineNrRegex")
	if len(a:log) > 0 
		for line in a:log
			let fn = matchstr(line, fn_regex)
			let nr =  matchstr(line, nr_regex)
			if s:StringTrim(fn) != ''
				let fname = fn
			endif
			if s:StringTrim(nr) != ''
				let break_line = str2nr(nr)
			endif
		endfor
	endif
	if break_line != 0 && fname != ''
		return {"fname":fname, "break_line":break_line}
	else 
		return 0
	endif
endfunction

" 相当于 trim，去掉首尾的空字符
function! s:StringTrim(str)
	return debugger#util#StringTrim(a:str)
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
	let g:debugger.original_cursor_color = debugger#util#Get_CursorLine_bgColor()
	call add(g:debugger.bufs, g:debugger.original_bufname)
	exec "hi DebuggerBreakPoint ctermfg=197 cterm=bold ctermbg=". debugger#util#Get_BgColor('SignColumn')
	" 语句执行位置标记 id=100
	exec 'sign define stop_point text=>> texthl=SignColumn linehl=CursorLine'
	" 断点标记 id 以 g:debugger.break_points 里的索引 +1 来表示
	exec 'sign define break_point text=** texthl=DebuggerBreakPoint'
	return g:debugger
endfunction

" 执行到什么文件的什么行
function! s:Debugger_Stop(fname, line)
	"if !exists("g:debugger")
	"	let g:debugger = s:Create_Debugger()
	"endif

	if a:fname == get(g:debugger,'stop_fname') && a:line == get(g:debugger,'stop_line')
		call s:Sign_Set_BreakPoint(a:fname, a:line)
		return
	else
		let g:debugger.stop_fname = a:fname
		let g:debugger.stop_line = a:line
	endif

	call execute(g:debugger.term_winnr.'wincmd w','silent!')
	let fname = s:Debugger_get_filebuf(a:fname)
	" 如果读到一个不存在的文件，认为进入到了 Node Native 部分 Debugging
	" 这时 node inspect 没有给出完整路径，调试不得不中断
	if type(fname) == type(0)  && fname == 0
		call term_sendkeys(get(g:debugger,'debugger_window_name'),"kill\<CR>")
		call debugger#runtime#Reset_Editor('silently')
		call s:Show_Close_Msg()
	endif
	call s:Sign_Set_BreakPoint(a:fname, a:line)
	"sleep 40m
	call cursor(a:line,1)
	call execute('redraw','silent!')
	call execute(g:debugger.original_bnr.'wincmd w','silent!')
endfunction

" 重新设置 Break Point 的 Sign 标记的位置
function! s:Sign_Set_BreakPoint(fname, line)
	try
		exec ":sign unplace 100 file=".a:fname
		exec ":sign place 100 line=".string(a:line)." name=stop_point file=".a:fname
	catch
	endtry
endfunction

" 如果跳转到一个新文件，新增一个 Buffer
function! s:Debugger_add_filebuf(fname)
	exec ":badd ". a:fname
	exec ":!b ". a:fname
	call add(g:debugger.bufs, a:fname)
endfunction

" 退出调试后需要删除这些新增的 Buffer
function! s:Debugger_del_tmpbuf()
	let tmp_bufs = deepcopy(g:debugger.bufs)
	for t_buf in tmp_bufs
		" 如果 Buf 短名不是原始值，长名也不是原始值
		if t_buf != g:debugger.original_bufname && 
					\ fnameescape(fnamemodify(g:debugger.original_bufname,':p')) != fnameescape(fnamemodify(t_buf,':p'))
			call execute('bdelete! '.t_buf,'silent!')
		endif
	endfor
	let g:debugger.bufs = []
endfunction

" 获得当前Buffer里的文件名字
function! s:Debugger_get_filebuf(fname)
	" TODO bufname用的相对路径需要改为绝对路径，
	" 我现将这个功能屏蔽掉了
	if !filereadable(fnameescape(fnamemodify(a:fname,':p')))
		return 0
	endif
	if index(g:debugger.bufs , a:fname) < 0 
		call s:Debugger_add_filebuf(a:fname)
	endif
	" TODO debugger 里只能获得 文件名，怎么获得文件路径
	" 比如跟踪到 modules.js 里，怎么也能buffer进来？
	call execute('buffer '.a:fname,'silent!')
	return a:fname
endfunction

" 关闭 Terminal
function! s:Close_Term()
	call term_sendkeys(get(g:debugger,'debugger_window_name'),"\<CR>\<C-C>\<C-C>")
	call execute('redraw','silent!')
	" if exists('g:debugger') && winnr() != g:debugger.original_winnr
	if exists('g:debugger') && g:debugger.original_winid != bufwinid(bufnr(""))
		call s:LogMsg("关闭窗口")
		" TODO，当打开两个Tab时，exit关闭Term时这一句执行到了，但不生效 
		call feedkeys("\<C-C>\<C-C>", 't')
	endif
	call s:LogMsg("调试结束,Debug over..")
endfunction

" 命令行的特殊命令处理：比如这里输入 exit 直接关掉 Terminal
function! debugger#runtime#Special_Cmd_Handler()
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
	call debugger#util#LogMsg(a:msg)
endfunction


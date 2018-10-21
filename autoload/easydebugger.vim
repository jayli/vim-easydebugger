" TODO:
" - 基于 NetBeans 的重构
" - 调试窗口启动位置可配置，比如在底部打开
" - 进入命令的自定义

" 插件初始化入口
function! easydebugger#Enable()
	" 服务启动唤醒键映射
	nnoremap <silent> <Plug>EasyDebuggerInspect :call easydebugger#NodeInspect()<CR>
	nnoremap <silent> <Plug>EasyDebuggerWebInspect :call easydebugger#NodeWebInspect()<CR>
	" 调试快捷键映射
	nnoremap <silent> <Plug>EasyDebuggerContinue :call easydebugger#InspectCont()<CR>
	tnoremap <silent> <Plug>EasyDebuggerContinue cont<CR>
	nnoremap <silent> <Plug>EasyDebuggerNext :call easydebugger#InspectNext()<CR>
	tnoremap <silent> <Plug>EasyDebuggerNext next<CR>
	nnoremap <silent> <Plug>EasyDebuggerStepIn :call easydebugger#InspectStep()<CR>
	tnoremap <silent> <Plug>EasyDebuggerStepIn step<CR>
	nnoremap <silent> <Plug>EasyDebuggerStepOut :call easydebugger#InspectOut()<CR>
	tnoremap <silent> <Plug>EasyDebuggerStepOut out<CR>
	nnoremap <silent> <Plug>EasyDebuggerPause :call easydebugger#InspectPause()<CR>
	tnoremap <silent> <Plug>EasyDebuggerPause pause<CR>
	nnoremap <silent> <Plug>EasyDebuggerSetBreakPoint :call easydebugger#InspectSetBreakPoint()<CR>

	let s:None_Run_Msg = '请先启动 Debugger 再设置断点（<Shift-R>）, please run debuger first(<Shift-R>)..'
endfunction

function! easydebugger#InspectCont()
	if !exists('g:debugger')
		call s:LogMsg(s:None_Run_Msg)
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'),"cont\<CR>")
	endif
endfunction

function! easydebugger#InspectNext()
	if !exists('g:debugger')
		call s:LogMsg(s:None_Run_Msg)
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'),"next\<CR>")
	endif
endfunction

function! easydebugger#InspectStep()
	if !exists('g:debugger')
		call s:LogMsg(s:None_Run_Msg)
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'),"step\<CR>")
	endif
endfunction

function! easydebugger#InspectOut()
	if !exists('g:debugger')
		call s:LogMsg(s:None_Run_Msg)
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'),"out\<CR>")
	endif
endfunction

function! easydebugger#InspectPause()
	if !exists('g:debugger')
		call s:LogMsg(s:None_Run_Msg)
		return
	endif
	if len(get(g:debugger,'bufs')) != 0 && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
		call term_sendkeys(get(g:debugger,'debugger_window_name'),"pause\<CR>")
	endif
endfunction

" 设置/取消断点，在当前行按 F12
function! easydebugger#InspectSetBreakPoint()
	if !exists('g:debugger') || term_getstatus(get(g:debugger,'debugger_window_name')) != 'running'
		call s:LogMsg(s:None_Run_Msg)
		return ""
	endif
	" 如果是当前文件所在的 Buf 或者是临时加载的 Buf
	if exists("g:debugger") && (bufnr('') == g:debugger.original_bnr || index(g:debugger.bufs,bufname('%')) >= 0)
		let line = line('.')
		let fname = bufname('%')
		let breakpoint_contained = index(g:debugger.break_points, fname."|".line)
		if breakpoint_contained >= 0
			" 已经存在 BreakPoint，则清除掉 BreakPoint
			call term_sendkeys(get(g:debugger,'debugger_window_name'),"clearBreakpoint('".fname."', ".line.")\<CR>")
			let sid = string(index(g:debugger.break_points, fname."|".line) + 1)
			exec ":sign unplace ".sid." file=".fname
			call remove(g:debugger.break_points, breakpoint_contained)
		else
			" 如果不存在 BreakPoint，则新增 BreakPoint
			call term_sendkeys(get(g:debugger,'debugger_window_name'),"setBreakpoint('".fname."', ".line.");list(1)\<CR>")
			call add(g:debugger.break_points, fname."|".line)
			let g:debugger.break_points =  uniq(g:debugger.break_points)
			let sid = string(index(g:debugger.break_points, fname."|".line) + 1)
			exec ":sign place ".sid." line=".line." name=break_point file=".fname
		endif
	endif
endfunction

function! s:Echo_debugging_info(command)
	call s:LogMsg(a:command . ' ' . " : 点击两次 <Ctrl-C> 终止调试, Press <Ctrl-C><Ctrl-C> to stop debugging..'")
endfunction

" 启动Chrome DevTools 模式的调试服务
function! easydebugger#NodeWebInspect()
	if &filetype != 'javascript'
		return ""
	endif
	let l:command = 'node --inspect-brk '.getbufinfo('%')[0].name
	call s:Echo_debugging_info(l:command)
	if version <= 800
		call system(l:command . " 2>/dev/null")
	else 
		call term_start(l:command . " 2>/dev/null",{ 
						\ 'term_finish': 'close',
						\ 'term_cols':s:Get_Term_Width(),
						\ 'vertical':'1',
						\ })
	endif
endfunction

" VIM 调试模式
function! easydebugger#NodeInspect()
	if &filetype != 'javascript'
		return ""
	endif
	let l:command = 'node inspect '.getbufinfo('%')[0].name
	call s:Echo_debugging_info(l:command)
	" 创建 g:debugger ，最重要的一个全局变量
	call s:Create_Debugger()
	call easydebugger#Reset_Editor('manually')
	if version <= 800
		call system(l:command . " 2>/dev/null")
	else 
		call term_start(l:command . " 2>/dev/null",{ 
						\ 'term_finish': 'close',
						\ 'term_name':get(g:debugger,'debugger_window_name') ,
						\ 'term_cols':s:Get_Term_Width(),
						\ 'vertical':'1',
						\ 'out_cb':'easydebugger#Term_callback',
						\ 'close_cb':'easydebugger#Reset_Editor',
						\ })
		if !exists('g:debugger_term_winnr')
			let g:debugger_term_winnr = bufnr(get(g:debugger,'debugger_window_name'))
		endif
		let g:debugger.term_winnr = g:debugger_term_winnr
		" 监听 Terminal 模式里的回车键
		tnoremap <silent> <CR> <C-\><C-n>:call easydebugger#Special_Cmd_Handler()<CR>i<C-P><Down>
		call term_wait(get(g:debugger,'debugger_window_name'))
		call s:Debugger_Break_Action(g:debugger.log)

		call s:Set_Debug_CursorLine()
	endif
endfunction

" 设置停住的行高亮样式
function! s:Set_Debug_CursorLine()
	if g:debugger.original_cursor_color
		call execute("hi CursorLine ctermbg=18","silent!")
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

" 退出 Terminal 时重置编辑器
function! easydebugger#Reset_Editor(...)
	call execute(g:debugger.term_winnr.'wincmd w','silent!')
	if g:debugger.original_bufname !=  bufname('%')
		exec ":b ". g:debugger.original_bufname
	endif
	call s:Clear_All_Signs()
	call s:Debugger_del_tmpbuf()
	if g:debugger.original_cursor_color
		" 恢复 CursorLine 的高亮样式
		call execute("hi CursorLine ctermbg=".g:debugger.original_cursor_color,"silent!")
	endif
	if winnr() != g:debugger.original_winnr 
		if !(type(a:1) == type('string') && a:1 == 'manually')
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

" Terminal 消息回传
function! easydebugger#Term_callback(channel, msg)
	if !exists('g:debugger') || empty(a:msg)
		return
	endif
	let m = substitute(a:msg,"\\W\\[\\d\\{-}[a-zA-Z]","","g")
	let g:msgs = split(m,"\r\n")
	let g:debugger.log += g:msgs
	let g:debugger.log += [""]

	if a:msg =~ 'Waiting for the debugger to disconnect'
		call s:Show_Close_Msg()
		call easydebugger#Reset_Editor('manually')
		" 调试终止之后应该将光标停止在 Term 内
		if winnr() != get(g:debugger, 'original_winnr')
			call execute(get(g:debugger, 'original_winnr').'wincmd w','silent!')
		endif
	else
		call s:Debugger_Break_Action(g:debugger.log)
	endif
	
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
	if len(a:log) > 0 
		for line in a:log
			let fn = matchstr(line, "\\(\\(break in\\|Break on start in\\)\\s\\)\\@<=.\\{\-}\\(:\\)\\@=")
			let nr =  matchstr(line, "\\(^>\\s\\|^>\\)\\@<=\\(\\d\\{1,10000}\\)\\(\\s\\)\\@=")
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
	if !empty(a:str)
		return substitute(a:str, "^\\s\\+\\(.\\{\-}\\)\\s\\+$","\\1","g")
	endif
	return ""
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
	let g:debugger.original_buf         = getbufinfo()
	let g:debugger.original_winnr       = winnr()
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
	let g:debugger.original_cursor_color = s:Get_CursorLine_bgColor()
	call add(g:debugger.bufs, g:debugger.original_bufname)
	exec "hi DebuggerBreakPoint ctermfg=197 cterm=bold ctermbg=". s:Get_BgColor('SignColumn')
	" 语句执行位置标记 id=100
	exec 'sign define stop_point text=>> texthl=SignColumn linehl=CursorLine'
	" 断点标记 id 以 g:debugger.break_points 里的索引 +1 来表示
	exec 'sign define break_point text=** texthl=DebuggerBreakPoint'
	return g:debugger
endfunction

" 获得当前 CursorLine 样式
function! s:Get_CursorLine_bgColor()
	return s:Get_BgColor('CursorLine')
endfunction

" 获得某个颜色主题的背景色
function! s:Get_BgColor(name)
	if &t_Co > 255 && !has('gui_running')
		let hlString = s:Highlight_Args(a:name)
		let bgColor = matchstr(hlString,"\\(\\sctermbg=\\)\\@<=\\d\\{\-}\\(\\s\\)\\@=")
		if bgColor != ''
			return str2nr(bgColor)
		endif
	endif
	return 'none'
endfunction

" 执行高亮
function! s:Highlight_Args(name)
	return 'hi ' . substitute(split(execute('hi ' . a:name), '\n')[0], '\<xxx\>', '', '')
endfunction

" 执行到什么文件的什么行
function! s:Debugger_Stop(fname, line)
	"if !exists("g:debugger")
	"	let g:debugger = s:Create_Debugger()
	"endif

	if a:fname == get(g:debugger,'stop_fname') && a:line == get(g:debugger,'stop_line')
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
		call easydebugger#Reset_Editor('manually')
		call s:Show_Close_Msg()
	endif
	try
		exec ":sign unplace 100 file=".fname
		exec ":sign place 100 line=".string(a:line)." name=stop_point file=".fname
	catch
	endtry
	"sleep 40m
	call cursor(a:line,1)
	call execute('redraw','silent!')
	call execute(g:debugger.original_bnr.'wincmd w','silent!')
endfunction

" 如果跳转到一个新文件，新增一个 Buffer
function! s:Debugger_add_filebuf(fname)
	exec ":badd ". a:fname
	exec ":b ". a:fname
	call add(g:debugger.bufs, a:fname)
endfunction

" 退出调试后需要删除这些新增的 Buffer
function! s:Debugger_del_tmpbuf()
	let tmp_bufs = deepcopy(g:debugger.bufs)
	for t_buf in tmp_bufs
		if t_buf != g:debugger.original_bufname
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
	if exists('g:debugger') && winnr() != g:debugger.original_winnr
		call feedkeys("\<S-ZZ>")
	endif
	call s:LogMsg("调试结束,Debug over..")
endfunction

" 命令行的特殊命令处理：比如这里输入 exit 直接关掉 Terminal
function! easydebugger#Special_Cmd_Handler()
	let cmd = getline('.')[0 : col('.')-1]
	let cmd = substitute(cmd,"^.*> ","","g")
	if cmd == 'exit'
		call s:Close_Term()
	"elseif cmd =='restart'
	"	call s:Set_Debug_CursorLine()
	endif
	call term_sendkeys(get(g:debugger,'debugger_window_name'),"\<CR>")
endfunction

" 输出 LogMsg
function! s:LogMsg(msg)
	echohl MoreMsg 
	echom '>>> '. a:msg
	echohl NONE
endfunction


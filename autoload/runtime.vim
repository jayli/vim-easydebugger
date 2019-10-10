" File:         runtime.vim
" Author:       @jayli
" Description:  Debugger 运行时的标准实现，无特殊情况应当优先使用这些默认实现，
"               如果不能满足当前调试器（比如 go 语言的 delve 不支持 pause），
"               需要在 debugger/[language].vim 中重新实现
"
"  ╔═══════════════════════════════╤═══════════════════════════════╗
"  ║                               │                               ║
"  ║                               │                               ║
"  ║                               │                               ║
"  ║        Source Window          │         Debug Window          ║
"  ║    g:debugger.original_winid  │     g:debugger.term_winid     ║
"  ║                               │                               ║
"  ║                               │                               ║
"  ║                               │                               ║
"  ╟───────────────────────────────┼───────────────────────────────╢
"  ║                               │                               ║
"  ║          Call Stack           │        Local Variables        ║
"  ║    g:debugger.stacks_winid    │   g:debugger.localvars_winid  ║
"  ║                               │                               ║
"  ╚═══════════════════════════════╧═══════════════════════════════╝
"
" 原理：Term 内运行 Inspect 程序，Term 创建时绑定输出回调，监听 Term
" 内的输出字符来执行单步执行、继续执行、暂停、输出回调堆栈等等操作，VIM 作为
" UI 层的交互，由于 Term 回调机制可以更好的完成，难度不大，关键是做好各个语言
" 的 Debugger 输出的格式过滤，目前已经将 runtime.vim 基本抽象出来了，debugger
" 目录下的 [编程语言].vim 的实现基于这个 runtime ，目前有这些已经定义好的接口：
"
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
"   - ShowLocalVarsWindow : {Number} : 是否显示本地变量窗口
"   - TerminalCursorSticky: {Number} : 单个命令结束后是否总是将光标定位在Term
"   - DebugPrompt: {string} : 提示符
"   - LocalDebuggerCommandPrefix : {string} : Debugger 启动的命令前缀
"   - LocalDebuggerCommandSufix : {string} : Debugger 命令启动的后缀
"   - ExecutionTerminatedMsg : {regex} : 判断 Debugger 运行结束的结束语正则
"   - BreakFileNameRegex : {regex} : 获得程序停驻所在文件的正则
"   - BreakLineNrRegex : {regex} : 获得程序停驻行号的正则

" 创建全局 g:debugger 对象 {{{
function! s:Create_Debugger()
    let g:debugger = {}
    if !exists('g:debugger_window_id')
        let g:debugger_window_id = 1
    else
        let g:debugger_window_id += 1
    endif
    " 调试窗口名字随机一下（其实固定名字也可以）
    let g:debugger.debugger_window_name = "dw" . g:debugger_window_id
    let g:debugger.original_bnr         = bufnr('')
    " winnr 并不和 最初的 Buf 强绑定，原始 winnr 不能作为 window 的标识
    " 要用 bufinfo 里的 windows 数组来代替唯一性
    let g:debugger.original_winnr        = winnr()
    let g:debugger.original_winid        = bufwinid(bufnr(""))
    let g:debugger.original_buf          = getbufinfo(bufnr(''))
    let g:debugger.cwd                   = getcwd()
    let g:debugger.language              = g:language_setup.language
    let g:debugger.original_bufname      = bufname('%')
    let g:debugger.original_line_nr      = line(".")
    let g:debugger.original_col_nr       = col(".")
    let g:debugger.buf_winnr             = bufwinnr('%')
    let g:debugger.current_winnr         = -1
    let g:debugger.bufs                  = []
    let g:debugger.cursor_original_winid = 0    " 执行命令前光标所在的窗口
    let g:debugger.stop_fname            = ''   " 当前停驻文件
    let g:debugger.stop_line             = 0    " 当前停驻行
    let g:debugger.log                   = []
    let g:debugger.hangup                = 0 " 判断当前是否挂起,挂起状态不应该执行任何callback
    let g:debugger.close_msg             = "Debug Finished. Use <S-E> or 'exit' ".
                                            \ "in terminal to quit debugging"
    " break_points: ['a.js|3','t/b.js|34']
    " break_points 里的索引作为 sign id
    let g:debugger.break_points= []
    " 样式配置
    let g:debugger.original_cursor_color    = util#Get_CursorLine_bgColor()
    let g:debugger.prompt_stop_arrow        = ">>"
    let g:debugger.prompt_break_point       = "**"
    let g:debugger.break_point_style_fg     = has("gui_running") ? "#df005f" : 197
    let g:debugger.stop_point_line_style_bg = has("gui_running") ? "#0000af" : 19
    let g:debugger.stop_point_text_style_fg = has("gui_running") ? "green" : "green"
    " 这句话没用其实
    call add(g:debugger.bufs, s:Get_Fullname(g:debugger.original_bufname))

    call util#hi('BreakPointStyle', g:debugger.break_point_style_fg, util#Get_BgColor('SignColumn'), "")
    call util#hi('StopPointLineStyle', -1, g:debugger.stop_point_line_style_bg, "")
    call util#hi('StopPointTextStyle', g:debugger.stop_point_text_style_fg, util#Get_BgColor('SignColumn'), "bold")
    " 定义占位符，防止 sigin 切换时的抖动, id 为 9999
    call util#hi('PlaceHolder', util#Get_BgColor('SignColumn'), util#Get_BgColor('SignColumn'), "")

    exec 'sign define place_holder text='.g:debugger.prompt_stop_arrow.' texthl=PlaceHolder'
    " 语句执行位置标记 id=100
    exec 'sign define stop_point text='.g:debugger.prompt_stop_arrow.
                \ ' texthl=StopPointTextStyle linehl=StopPointLineStyle'
    " 断点标记 id 以 g:debugger.break_points 里的索引 +1 来表示
    exec 'sign define break_point text='.g:debugger.prompt_break_point.' texthl=BreakPointStyle'
    return g:debugger
endfunction " }}}

" 启动 Chrome DevTools 模式的调试服务（只实现了 NodeJS）{{{
function! runtime#WebInspectInit()
    if s:Term_is_running()
        return s:LogMsg("Please terminate the running debugger first.")
    endif

    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif

    if !get(g:language_setup,'DebuggerTester')()
        if has_key(g:language_setup, 'DebuggerNotInstalled')
            return s:LogMsg(get(g:language_setup,'DebuggerNotInstalled'))
        endif
    endif

    let l:command = get(g:language_setup,'WebDebuggerCommandPrefix') . ' ' . 
                    \ getbufinfo('%')[0].name
    if has_key(g:language_setup, "LocalDebuggerCommandSufix")
        let l:full_command = s:StringTrim(l:command . ' ' . 
                    \ get(g:language_setup, "LocalDebuggerCommandSufix"))
    else
        let l:full_command = s:StringTrim(l:command)
    endif

    call term_start(l:full_command,{ 
        \ 'term_finish': 'close',
        \ 'term_cols':s:Get_Term_Width(),
        \ 'vertical':'1',
        \ })

    call s:Echo_debugging_info(l:full_command)
endfunction " }}}

" 如果存在 debugger_entry = ... 优先启动文件入口 {{{
function! s:Get_DebuggerEntry()
    let filename = ''
    let code_lines = getbufline(bufnr(''),1,'$')
    for line in code_lines
        if line  =~ "^\\(#\\|\"\\|//\\)\\s\\{-}debugger_entry\\s\\{-}="
            let filename = matchstr(line ,
                        \ "\\(\\s\\{-}debugger_entry\\s\\{-}=\\s\\{-}\\)\\@<=\\S\\+")
            if filename =~ "^\\~/"
                let filename = expand(filename)
            endif
            if filename =~ "^\\."
                let bufile = getbufinfo(bufnr(''))[0].name
                let bufdir = util#GetDirName(bufile)
                let filename = simplify(bufdir . filename)
            endif
            return filename
        endif
    endfor
    return ""
endfunction " }}}

" 初始化 VIM 调试窗 {{{
function! runtime#InspectInit()
    if s:Term_is_running()
        return s:LogMsg("Please terminate the running debugger first.")
    endif

    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif

    if !get(g:language_setup,'DebuggerTester')()
        if has_key(g:language_setup, 'DebuggerNotInstalled')
            return s:LogMsg(get(g:language_setup,'DebuggerNotInstalled'))
        endif
    endif

    let in_file_debugger_entry = s:Get_DebuggerEntry()
    let debug_filename = in_file_debugger_entry == "" ? getbufinfo('%')[0].name : in_file_debugger_entry
    let l:command = get(g:language_setup,'LocalDebuggerCommandPrefix') . ' ' . debug_filename
    if has_key(g:language_setup, "LocalDebuggerCommandSufix")
        let l:full_command = s:StringTrim(l:command . ' ' .
                    \ get(g:language_setup, "LocalDebuggerCommandSufix"))
    else
        let l:full_command = s:StringTrim(l:command)
    endif

    call s:Create_Debugger()
    call runtime#Reset_Editor('silently')

    " ---开始创建 Terminal---
    call s:Set_Debug_CursorLine()
    " 创建call stack window {{{
    sil! exec "bo 10new"
    call s:Set_Bottom_Window_Statusline("stack")
    " 设置stack window 属性
    let g:debugger.stacks_winid = winnr()
    let g:debugger.stacks_bufinfo = getbufinfo(bufnr(''))
    exec s:Get_cfg_list_window_status_cmd()
    call s:Add_jump_mapping()
    call g:Goto_sourcecode_window()
    " }}}
    " 创建localvar window {{{
    sil! exec "vertical botright new"
    call s:Set_Bottom_Window_Statusline("localvars")
    " 设置localvar window 属性
    exec s:Get_cfg_list_window_status_cmd()
    exec 'setl nonu'
    let localvars_winid = winnr()
    let g:debugger.localvars_winid = localvars_winid
    let g:debugger.localvars_bufinfo = getbufinfo(bufnr(''))
    if has_key(g:language_setup,"ShowLocalVarsWindow") &&
                \ get(g:language_setup, 'ShowLocalVarsWindow') == 1
        " 如果调试器支持输出本地变量，则创建本地变量窗口,默认高度10
        exec "abo " . (winheight(localvars_winid) - 11) . "new"
    endif
    " }}}

    call term_start(l:full_command,{
        \ 'term_finish': 'close',
        \ 'term_name':get(g:debugger,'debugger_window_name') ,
        \ 'vertical':'1',
        \ 'curwin':'1',
        \ 'out_cb':'runtime#Term_callback',
        \ 'out_timeout':400,
        \ 'close_cb':'runtime#Reset_Editor',
        \ })
    let g:debugger.term_winid = bufwinid(get(g:debugger,'debugger_window_name'))
    " 监听 Terminal 模式里的回车键，根据敲入的字符串做一些自定义动作
    tnoremap <silent> <CR> <C-\><C-n>:call runtime#Special_Cmd_Handler()<CR>i
    " 监听上下键：
    " 上下键可以直接显示 history，这时应当按照输入过程处理，不应该走入回调
    tnoremap <silent> <Up> <C-\><C-n>:call runtime#Terminal_Do_Nothing()<CR>i<Up>
    tnoremap <silent> <Down> <C-\><C-n>:call runtime#Terminal_Do_Nothing()<CR>i<Down>
    call term_wait(get(g:debugger,'debugger_window_name'))
    call s:Debugger_Stop_Action(g:debugger.log)

    " 启动调试器后执行需要运行的脚本
    if has_key(g:language_setup, "TermSetupScript")
        call get(g:language_setup,"TermSetupScript")()
    endif
endfunction "}}}

" Terminal do nothing {{{
function! runtime#Terminal_Do_Nothing()
    let g:debugger.term_callback_hijacking = function("util#DoNothing")
    call timer_start(200,
            \ {-> util#DelTermCallbackHijacking()},
            \ {'repeat' : 1})
endfunction " }}}

" 设置本地变量和调用堆栈窗口的statusline样式{{{
function! s:Set_Bottom_Window_Statusline(name)
    if a:name == "stack"
        exec 'setl statusline=%1*\ Normal\ %*%5*\ Call\ Stack\ %*\ %r%f[%M]%=Depth\ :\ %L\ '
    elseif a:name == "localvars"
        exec 'setl statusline=%1*\ Normal\ %*%5*\ Local\ Variables\ %*\ %r%f[%M]%=No\ :\ %L\ '
    endif
endfunction "}}}

" Continue {{{
function! runtime#InspectCont()
    if !exists('g:language_setup')
        return easydebugger#Create_Lang_Setup()
    endif
    if !exists('g:debugger')
        return s:LogMsg("Please startup debugger first.")
    endif
    if len(get(g:debugger,'bufs')) != 0 && s:Term_is_running()
        call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_continue."\<CR>")
    endif
endfunction " }}}

" Next {{{
function! runtime#InspectNext()
    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif
    if !exists('g:debugger')
        return s:LogMsg("Please startup debugger first.")
    endif
    if len(get(g:debugger,'bufs')) != 0 && s:Term_is_running()
        call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_next."\<CR>")
    endif
endfunction " }}}

" Stepin {{{
function! runtime#InspectStep()
    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif
    if !exists('g:debugger')
        return s:LogMsg("Please startup debugger first.")
    endif
    if len(get(g:debugger,'bufs')) != 0 && s:Term_is_running()
        call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_stepin."\<CR>")
    endif
endfunction " }}}

" Stepout {{{
function! runtime#InspectOut()
    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif
    if !exists('g:debugger')
        return s:LogMsg("Please startup debugger first.")
    endif
    if len(get(g:debugger,'bufs')) != 0 && s:Term_is_running()
        call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_stepout."\<CR>")
    endif
endfunction " }}}

" Pause {{{
function! runtime#InspectPause()
    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif
    if !exists('g:debugger')
        return s:LogMsg("Please startup debugger first.")
    endif
    if len(get(g:debugger,'bufs')) != 0 && s:Term_is_running()
        call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_pause."\<CR>")
    endif
endfunction " }}}

" 设置/取消断点，在当前行按 F12 {{{
function! runtime#InspectSetBreakPoint()
    if !s:Term_is_running()
        return s:LogMsg("Please startup debugger first.")
    endif
    if g:debugger.hangup == 1
        return s:LogMsg("Terminal is hanging up!")
    endif
    " 如果是当前文件所在的 Buf 或者是临时加载的 Buf
    if exists("g:debugger") && (bufnr('') == g:debugger.original_bnr ||
                \ index(g:debugger.bufs,bufname('%')) >= 0 ||
                \ bufwinnr(bufnr('')) == g:debugger.original_winnr)
        let line = line('.')
        let fname = expand("%:p")
        let breakpoint_contained = index(g:debugger.break_points, fname."|".line)
        let g:debugger.term_callback_hijacking = function("util#DoNothing")
        if breakpoint_contained >= 0
            " 已经存在 BreakPoint，则清除掉 BreakPoint
            call term_sendkeys(get(g:debugger,'debugger_window_name'),runtime#clearBreakpoint(fname,line))
            let sid = string(index(g:debugger.break_points, fname."|".line) + 1)
            exec ":sign unplace ".sid." file=".s:Get_Fullname(fname)
            call remove(g:debugger.break_points, breakpoint_contained)
            call s:LogMsg("Remove break point successfully.")
        else
            " 如果不存在 BreakPoint，则新增 BreakPoint
            call term_sendkeys(get(g:debugger,'debugger_window_name'),runtime#setBreakpoint(fname,line))
            call add(g:debugger.break_points, fname."|".line)
            let g:debugger.break_points =  uniq(g:debugger.break_points)
            let sid = string(index(g:debugger.break_points, fname."|".line) + 1)
            exec ":sign place ".sid." line=".line." name=break_point file=".s:Get_Fullname(fname)
            call s:LogMsg("Add break point successfully.")
        endif
        call timer_start(200,
                \ {-> util#DelTermCallbackHijacking()},
                \ {'repeat' : 1})
    else
        call s:LogMsg('No response for break point setting.')
    endif
endfunction " }}}

" 清除断点 {{{
function! runtime#clearBreakpoint(fname,line)
    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif
    return get(g:language_setup, "ClearBreakPoint")(a:fname,a:line)
endfunction " }}}

" 设置断点 {{{
function! runtime#setBreakpoint(fname,line)
    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif
    return get(g:language_setup, "SetBreakPoint")(a:fname,a:line)
endfunction " }}}

" 退出 Terminal 时重置编辑器 {{{
" 可传入单独的参数：
" - silently: 不关闭Term
function! runtime#Reset_Editor(...)
    if !exists("g:debugger") 
        return
    endif
    call g:Goto_sourcecode_window()
    " 短名长名都不等，当前所在buf不是原始buf的话，先切换到原始Buf
    if g:debugger.original_bufname !=  bufname('%') &&
                \ g:debugger.original_bufname != fnameescape(fnamemodify(bufname('%'),':p'))
        exec ":b ". g:debugger.original_bufname
    endif
    call s:Debugger_del_tmpbuf()
    if g:debugger.original_cursor_color
        " 恢复 CursorLine 的高亮样式
        call execute("setlocal cursorline","silent!")
        call util#hi('CursorLine', -1 , g:debugger.original_cursor_color, "")
    endif
    if g:debugger.original_winid != bufwinid(bufnr(""))
        if !(type(a:1) == type('string') && a:1 == 'silently')
            call feedkeys("\<S-ZZ>")
        endif
    endif
    call s:Clear_All_Signs()
    call execute('redraw','silent!')
    " 最后清空本次 Terminal 里的 log
    call s:Close_varwindow()
    call s:Close_stackwindow()
    let g:debugger.log = []
    if exists('g:debugger._prev_msg')
        unlet g:debugger._prev_msg
    endif
endfunction " }}}

" hijacking 函数劫持监听 {{{
function! runtime#Term_callback_event_handler(channel, msg)
    if exists("g:debugger.term_callback_hijacking")
        call g:debugger.term_callback_hijacking(a:channel, a:msg)
    endif
endfunction " }}}

" Terminal 消息回传 {{{
function! runtime#Term_callback(channel, msg)
    call s:log('----------out_cb----------{{')
    call s:log('msg 原始信息' . a:msg)
    call s:log(util#ascii(a:msg))
    " 如果消息为空
    " 如果消息长度为1，说明正在敲入字符
    " 如果首字母和尾字符ascii码值在[0,31]是控制字符，说明正在删除字符
    " 如果首位字母是 7 bell，8 退格，9 制表符，说明正在敲入字符
    " 如果 =~ ^\w+$ ，说明tab匹配出联想词
    if !exists('g:debugger._prev_msg')
        let g:debugger._prev_msg = a:msg
    endif
    if !exists('g:debugger') || empty(a:msg) ||
                \ len(a:msg) == 1 || index([7,8,9,27], char2nr(a:msg)) >= 0 ||
                \ index([7,8,9],  char2nr(a:msg[len(a:msg) - 1])) >= 0 ||
                \ (!s:Is_Ascii_Visiable(a:msg) && len(a:msg) == len(g:debugger._prev_msg) - 1) ||
                \ a:msg =~ "^\\w\\+$"
                "\ char2nr(a:msg) == 13"
        return s:log("xxx输入字符被拦截xxx")
    endif
    let g:debugger._prev_msg = a:msg
    let m = substitute(a:msg,"\\W\\[\\d\\{-}[a-zA-Z]","","g")
    let msgslist = split(m,"\r\n")
    let g:debugger.log += msgslist
    " 为了防止 log 过长性能变慢，这里做一个上限
    let log_max_length = 50
    if len(g:debugger.log) >= log_max_length
        unlet g:debugger.log[0:len(g:debugger.log) - (log_max_length)]
    endif
    let full_log = deepcopy(g:debugger.log)

    if !exists("g:language_setup")
        call easydebugger#Create_Lang_Setup()
    endif
    if has_key(g:language_setup, "ExecutionTerminatedMsg") && 
                \ a:msg =~ get(g:language_setup, "ExecutionTerminatedMsg")
        call s:Show_Close_Msg()
        call runtime#Reset_Editor('silently')
        " 调试终止之后应该将光标停止在 Term 内
        if winnr() != get(g:debugger, 'original_winnr')
            if has_key(g:language_setup, "TerminalCursorSticky") && 
                        \ g:language_setup.TerminalCursorSticky == 1
                call g:Goto_terminal_window()
            else
                call s:Cursor_Restore()
            endif
        endif
        return
    endif

    " 有输出时的回调句柄
    if exists("g:debugger.term_callback_hijacking")
        " 不想被 Stop Action 干扰，先劫持掉，比如只计算call stack和localvars
        call g:debugger.term_callback_hijacking(a:channel, a:msg, full_log)
    else
        call s:Debugger_Stop_Action(g:debugger.log)
        if has_key(g:language_setup,"TermCallbackHandler")
            call g:language_setup.TermCallbackHandler(full_log)
        endif
    endif

    call s:log('----------out_cb----------}}')
endfunction " }}}

" 挂起样式设置 {{{
function! s:HangUp_Sign()
    " sign 9999 是为了防止界面抖动
    call s:log("清空停驻标记")
    if !has_key(g:debugger, "_place_holder_for_temp")
        let g:debugger._place_holder_for_temp = []
    endif
    if get(g:debugger,"stop_fname") != ""
        exec ":sign place 9998 line=1 name=place_holder file=".s:Get_Fullname(g:debugger.stop_fname)
        exec ":sign unplace 100 file=".s:Get_Fullname(g:debugger.stop_fname)
        if index(g:debugger._place_holder_for_temp, s:Get_Fullname(g:debugger.stop_fname)) < 0
            call add(g:debugger._place_holder_for_temp, s:Get_Fullname(g:debugger.stop_fname))
        endif
    endif
    let g:debugger.hangup = 1
endfunction " }}}

" 删除 stack 和 localvar {{{
function s:Empty_Stack_and_Localvars()
    let stack_bufnr = get(g:debugger,'stacks_bufinfo')[0].bufnr
    call setbufvar(stack_bufnr, '&modifiable', 1)
    call util#deletebufline(stack_bufnr, 1, len(getbufline(stack_bufnr, 0,'$')))
    call setbufvar(stack_bufnr, '&modifiable', 0)
    " 如果支持本地变量，一并清空
    if has_key(g:language_setup,"ShowLocalVarsWindow") && get(g:language_setup, 'ShowLocalVarsWindow') == 1
        let localvar_bufnr = get(g:debugger,'localvars_bufinfo')[0].bufnr
        call setbufvar(localvar_bufnr, '&modifiable', 1)
        call util#deletebufline(localvar_bufnr, 1, len(getbufline(localvar_bufnr, 0,'$')))
        call setbufvar(localvar_bufnr, '&modifiable', 0)
    endif
endfunction " }}}

" 清空挂起状态 {{{
function! s:Clear_HangUp_Sign()
    if !has_key(g:debugger, "_place_holder_for_temp")
        return
    endif
    for fname in g:debugger._place_holder_for_temp
        exec ":sign unplace 9998 file=".s:Get_Fullname(fname)
    endfor
endfunction " }}}

" 判断首字母是否是可见的 ASCII 码 {{{
function! s:Is_Ascii_Visiable(c)
    if char2nr(a:c) >= 32 && char2nr(a:c) <= 126
        return 1
    else
        return 0
    endif
endfunction " }}}

" 输出初始调试信息 {{{
function! s:Echo_debugging_info(command)
    call s:LogMsg(a:command)
endfunction " }}}

" 设置停驻的行高亮样式 {{{
function! s:Set_Debug_CursorLine()
    " Do Nothing
    " 停驻行的跳转使用 cursor() 完成
    " 停驻行的样式使用 setlocal nocursorline 清除掉，以免光标样式覆盖 sign linehl 样式
    " 清除样式的时机在 Debugger_Stop_Action() 函数内
    " 调试结束后恢复默认 cursorline 样式： setlocal cursorline
endfunction " }}}

" 获得 term 宽度 {{{
function! s:Get_Term_Width()
    let term_width = float2nr(floor(winwidth(winnr()) * 50 / 100))
    return term_width
endfunction " }}}

" 将标记清除 {{{
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
    " 清除挂起占位标记
    call s:Clear_HangUp_Sign()
endfunction " }}}

" 显示 Term 窗口关闭消息 {{{
function! s:Show_Close_Msg()
    call s:LogMsg(bufname('%')." ". get(g:debugger,'close_msg'))
endfunction " }}}

" 设置停留的代码行 {{{
function! s:Debugger_Stop_Action(log)
    let break_msg = s:Get_Term_Stop_Msg(a:log)
    call s:log('Debugger_Stop_Action '. string(a:log))
    " 清除hangup标记
    let g:debugger.hangup = 0
    if type(break_msg) == type({})
        call s:log("有停驻信息")
        call s:HangUp_Sign()
        call s:Debugger_Stop(get(break_msg,'fname'), get(break_msg,'breakline'))
    elseif len(a:log) > 0 && trim(a:log[len(a:log) - 1]) =~ get(g:language_setup, "DebugPrompt")
        call s:HangUp_Sign()
        call s:Debugger_Stop(g:debugger.stop_fname, g:debugger.stop_line)
        call s:log("无停驻信息, 元命令执行完，等待输入指令")
    else
        call s:HangUp_Sign()
        call s:Empty_Stack_and_Localvars()
        call s:log("无停驻信息, 程序还在运行，持续挂起状态")
    endif
endfunction " }}}

" 处理Termnal里的log,这里的 log 是 g:debugger.log {{{
" 这里比较奇怪，Log 不是整片输出的，是碎片输出的
function! s:Get_Term_Stop_Msg(log)
    if len(a:log) == 0
        return 0
    endif

    if !exists("g:language_setup")
        call easydebugger#Create_Lang_Setup()
    endif

    " 因为碎片输出，这里会被执行很多次，可能有潜在的性能问题
    let break_line = 0
    let fname = ''
    let fn_regex = get(g:language_setup, "BreakFileNameRegex")
    let nr_regex = get(g:language_setup, "BreakLineNrRegex")

    for line in a:log
        " 防止 E363 错误
        if len(line) > 200
            continue
        endif
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
endfunction " }}}

" 相当于 trim，去掉首尾的空字符 {{{
function! s:StringTrim(str)
    return util#StringTrim(a:str)
endfunction " }}}

" 执行到什么文件的什么行 {{{
function! s:Debugger_Stop(fname, line)
    let fname = s:Get_Fullname(a:fname)
    let g:debugger.hangup = 0

    if !exists("g:language_setup")
        call easydebugger#Create_Lang_Setup()
    endif

    call g:Goto_sourcecode_window()
    let fname = s:Debugger_get_filebuf(fname)
    " 如果读到一个不存在的文件，认为进入到 Native 部分的 Debugging，
    " 比如进入到了 Node Native 部分 Debugging, node inspect 没有给
    " 出完整路径，调试不得不中断，TODO，这里不应该中断
    if (type(fname) == type(0) && fname == 0) || (type(fname) == type('string') && fname == '0')
        call term_sendkeys(get(g:debugger,'debugger_window_name'),"kill\<CR>")
        call runtime#Reset_Editor('silently')
        call s:Show_Close_Msg()
        return
    endif
    call execute('setlocal nocursorline','silent!')

    let shorten_filename = len(fname) > 40 ? pathshorten(fname) : fname
    call s:LogMsg('Stop at '. shorten_filename .', line '.a:line. '.')
    " 如果定义了AfterStopScript，且停驻行变更
    " TODO：
    " 1. 解决了挂起的问题，这里的设计有问题，如果是一个循环里的语句，continue后还停留在这行，
    " 则不会重新算堆栈和localvar
    " 2. cursor(a:line,1) 有时候不起作用，done
    " 3. 挂起时，localvar和call stack 应该清空
    " 4. F12 设置断点时，光标又跑到停驻行去了 ,done
    if has_key(g:language_setup, 'AfterStopScript')
            \ &&  !(fname == g:debugger.stop_fname && a:line == g:debugger.stop_line)
        " call s:Empty_Stack_and_Localvars()
        call get(g:language_setup, 'AfterStopScript')(g:debugger.log)
    endif

    call s:Sign_Set_StopPoint(fname, a:line)
    call cursor(a:line,1)
    call execute('redraw','silent!')

    " 执行完停驻行跳转的动作，根据配置决定是否跳回 Terminal，方便用户直接输入命令
    if has_key(g:language_setup, "TerminalCursorSticky") &&
                \ g:language_setup.TerminalCursorSticky == 1
        call g:Goto_terminal_window()
    else
        call s:Cursor_Restore()
    endif
    " call g:Goto_terminal_window()

    let g:debugger.stop_fname = fname
    let g:debugger.stop_line = a:line

    " 只要重新停驻到新行，这一阶段的解析就完成了，log清空
    let g:debugger.log = []
endfunction " s:Debugger_Stop }}}

" 重新设置 Break Point 的 Sign 标记的位置 {{{
function! s:Sign_Set_StopPoint(fname, line)
    call s:log('设置停驻标记')
    try
        " 如果要停驻的文件名有变化...
        if a:fname != g:debugger.stop_fname && g:debugger.stop_fname != ""
            exec ":sign unplace 100 file=".g:debugger.stop_fname
        endif
        " sign 9999 是为了防止界面抖动
        exec ":sign place 9999 line=1 name=place_holder file=".s:Get_Fullname(a:fname)
        exec ":sign unplace 100 file=".s:Get_Fullname(a:fname)
        exec ":sign place 100 line=".string(a:line)." name=stop_point file=".s:Get_Fullname(a:fname)
        exec ":sign unplace 9999 file=".s:Get_Fullname(a:fname)
    catch
        call cursor(a:line,1)
    endtry
endfunction " }}}

" s:goto_win(winnr) {{{
function! s:Goto_winnr(winnr) abort
    let cmd = type(a:winnr) == type(0) ? a:winnr . 'wincmd w'
                                     \ : 'wincmd ' . a:winnr
    noautocmd execute cmd
    call execute('redraw','silent!')
endfunction " }}}

" 跳转到原始源码所在的窗口 {{{
function! g:Goto_sourcecode_window()
    call g:Goto_window(g:debugger.original_winid)
endfunction " }}}

" 跳转到 Term 所在的窗口 {{{
function! g:Goto_terminal_window()
    if s:Term_is_running()
        call g:Goto_window(get(g:debugger,'term_winid'))
    endif
endfunction " }}}

" 本地变量和调用堆栈窗口属性 {{{
function! s:Get_cfg_list_window_status_cmd()
    " nowrite 是一个全局配置，所有窗口不可写，退出时需重置
    return "setl nomodifiable nolist nu noudf " . 
                \ "nowrite nowrap buftype=nofile filetype=help"
endfunction " }}}

" stack 窗口中的回车事件监听 {{{
function! s:Add_jump_mapping()
    call execute("nnoremap <buffer> <CR> :call runtime#stack_jumpping()<CR>")
endfunction " }}}

" 调用堆栈窗口的文件行跳转 {{{
function! runtime#stack_jumpping()
    let lnum = getbufinfo(bufnr(''))[0].lnum
    if exists("g:debugger.callback_stacks")
        let stacks = g:debugger.callback_stacks
        let obj = stacks[lnum - 1]
        if filereadable(obj.filename)
            call g:Goto_sourcecode_window()
            call execute("e " . obj.filename)
            call cursor(obj.linnr, 1) "TODO 定位到对应列
        else
            call util#WarningMsg(obj.filename ." not exists!")
        endif
    else
        call util#WarningMsg("g:debugger.callback_stacks is undefined!")
    endif
endfunction " }}}

function! s:Close_varwindow() " {{{
    if exists('g:debugger.localvars_winid')
        call g:Goto_window(g:debugger.localvars_winid)
        if !exists('g:language_setup')
            call easydebugger#Create_Lang_Setup()
        endif
        if has_key(g:language_setup,"ShowLocalVarsWindow") && get(g:language_setup, 'ShowLocalVarsWindow') == 1
            let bufnr = get(g:debugger,'localvars_bufinfo')[0].bufnr
            call setbufvar(bufnr, '&modifiable', 1)
            call util#deletebufline(bufnr, 1, len(getbufline(bufnr,0,'$')))
            call setbufvar(bufnr, '&modifiable', 0)
            call execute(':q!', 'silent!')
        endif
        " 代码窗口回复可写状态
        call execute('setl write', 'silent!')
    endif
endfunction " }}}

function! s:Close_stackwindow() " {{{
    if exists('g:debugger.stacks_winid')
        call execute("close " . g:debugger.stacks_winid)
        " 代码窗口回复可写状态
        call execute('setl write', 'silent!')
    endif
endfunction " }}}

" 跳转到 Window {{{
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
endfunction " }}}

" 如果跳转到一个新文件，新增一个 Buffer {{{
" fname 是文件绝对地址
function! s:Debugger_add_filebuf(fname)
    exec ":badd ". a:fname
    exec ":b ". a:fname
    call add(g:debugger.bufs, a:fname)
endfunction " }}}

" 退出调试后需要删除这些新增的 Buffer {{{
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
endfunction " }}}

" 获得当前Buffer里的文件名字 {{{
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
        try 
            call execute('buffer '.a:fname)
        catch 
            call util#WarningMsg("File '" . a:fname . "' is opened in another shell. ".
                    \ " Close it first.")
        endtry
    endif
    return fname
endfunction " }}}

" 获得完整路径 {{{
function! s:Get_Fullname(fname)
    return fnameescape(fnamemodify(a:fname,':p'))
endfunction " }}}

" 关闭 Terminal , Hack for NodeJS {{{
function! s:Close_Term()
    call term_sendkeys(get(g:debugger,'debugger_window_name'),"\<CR>\<C-C>\<C-C>")
    if exists('g:debugger') && g:debugger.original_winid != bufwinid(bufnr(""))
        call feedkeys("\<C-C>\<C-C>", 't')
        unlet g:debugger.term_winid
    endif
    call execute('redraw','silent!')
    call s:LogMsg("Debug terminated.")
endfunction " }}}

function! runtime#Close_Term() " {{{
    call term_sendkeys(get(g:debugger,'debugger_window_name'),"\<CR>exit\<CR>")
    if has_key(g:debugger, 'term_winid')
        unlet g:debugger.term_winid
    endif
    call execute('redraw','silent!')
    call s:LogMsg("Debug terminated.")
endfunction " }}}

function! runtime#Mark_Cursor_Position() "{{{
    if s:Term_is_running()
        let g:debugger.cursor_original_winid = bufwinid(bufnr(""))
    endif
endfunction " }}}

function! s:Cursor_Restore() " {{{
    call runtime#Cursor_Restore()
endfunction " }}}

function! runtime#Cursor_Restore() " {{{
    if s:Term_is_running() && 
                \ g:debugger.cursor_original_winid != bufwinid(bufnr("")) &&
                \ g:debugger.cursor_original_winid != 0
        call g:Goto_window(g:debugger.cursor_original_winid)
    endif
endfunction " }}}

function! s:Term_is_running() " {{{
    if exists("g:debugger") && 
                \ term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
        return 1
    else 
        return 0
    endif
endfunction " }}}

" 命令行的特殊命令处理：比如这里输入 exit 直接关掉 Terminal {{{
function! runtime#Special_Cmd_Handler()
    let cmd = getline('.')[0 : col('.')-1]
    " node 中是 kill 关闭，let NodeJS support 'exit' cmd, Heck for NodeJS
    let cmd = s:StringTrim(substitute(cmd,"^.*debug>\\s","","g"))
    if cmd == 'exit'
        call s:Close_Term()
    elseif cmd == 'restart'
        call s:Set_Debug_CursorLine()
    elseif cmd == 'run'
        call s:Set_Debug_CursorLine()
    endif
    call term_sendkeys(get(g:debugger,'debugger_window_name'),"\<CR>")
endfunction " }}}

" 输出 LogMsg {{{
function! s:LogMsg(msg)
    return util#LogMsg(a:msg)
endfunction " }}}

" 输出调试信息 {{{
function! s:log(msg)
    return util#log(a:msg)
endfunction " }}}

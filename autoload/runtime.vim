" File:         runtime.vim
" Author:       @jayli
" Description:  Debugger runtime
"   _______________________________________________________________
"  |                               |                               |
"  |                               |                               |
"  |                               |                               |
"  |        Source Window          |         Debug Window          |
"  |    g:debugger.original_winid  |     g:debugger.term_winid     |
"  |                               |                               |
"  |                               |                               |
"  |_______________________________|_______________________________|
"  |                               |                               |
"  |          Call Stack           |        Local Variables        |
"  |    g:debugger.stacks_winid    |   g:debugger.localvars_winid  |
"  |_______________________________|_______________________________|
"
"
"  The whole process of user command execuation:
"    ____________________________________
"   |                                    |
"   |  Execute user command              |
"   |____________________________________|
"       │
"       │ Wait for terminal callback.
"       ↓
"    ____________________________________
"   |                                    |
"   |  Runtime#Term_Callback_Handler()   |
"   |____________________________________|
"       │
"       │ Exception filter.
"       ↓
"    ____________________________________
"   |                                    |
"   |   Runtime#Debugger_Stop_Action()   |
"   |____________________________________|
"       │
"       │ Exec done. Do stop action.
"       ↓
"    ____________________________________
"   |                                    |
"   |   Language#After_Stop_Script()     |
"   |____________________________________|
"       │
"       │ Do sth just after stop action.
"       ↓
"    ____________________________________
"   |                                    |
"   |  Language#Term_Callback_Handler()  |
"   |____________________________________|
"       │
"       │ Do sth after term callback all done.
"       ↓
"    ____________________________________
"   |                                    |
"   | Process ends Wait for next command |
"   |____________________________________|
"
" Language APIs:
"
"   - ctrl_cmd_continue : {string} : continue cmd
"   - ctrl_cmd_next : {string} : next cmd
"   - ctrl_cmd_stepin : {string} : stepin cmd
"   - ctrl_cmd_stepout : {string} : exit cmd
"   - ctrl_cmd_pause : {string} : pause cmd
"   - InspectInit : {function} : Debugger init
"   - WebInspectInit : {function} : Debugger Web Server init
"   - InspectCont : {function} : function to act continue
"   - InspectNext : {function} : function to act next
"   - InspectStep : {function} : function to act stepin
"   - InspectOut : {function} : function to act out
"   - InspectPause : {function} : function to act pause
"   - InspectSetBreakPoint : {function} : set break point
"   - DebuggerTester : {function} : checking if debug tool was installed or not
"   - ClearBreakPoint : {function} : clear break point
"   - SetBreakPoint : {function} : return add break point cmd string
"   - TermSetupScript : {function} : Do something after terminal is created
"   - AfterStopScript : {function} : Do something after stopping at a new line
"   - GetErrorMsg : {function} : checking if an exception was raised or not
"   - TermCallbackHandler : {function} : Terminal output callback
"   - DebuggerNotInstalled : {string} : a message for Debugger is nonavailable
"   - WebDebuggerCommandPrefix : {string} : Debugger Web server cmd prefix
"   - ShowLocalVarsWindow : {Number} : show local variables window or not
"   - TerminalCursorSticky: {Number} : should cursor always focus at terminal when debugging
"   - DebugPrompt: {string} : debug prompt message
"   - LocalDebuggerCommandPrefix : {string} : Debugger command prefix
"   - LocalDebuggerCommandSufix : {string} : Debugger command sufix
"   - ExecutionTerminatedMsg : {regex} : Regexp for debugger run into some error
"   - BreakFileNameRegex : {regex} : regexp for getting stop file
"   - BreakLineNrRegex : {regex} : regexp for getting line number of stop file

" create g:debugger global object {{{
function! s:Create_Debugger()
    let g:debugger = {}
    if !exists('g:debugger_window_id')
        let g:debugger_window_id = 1
    else
        let g:debugger_window_id += 1
    endif
    " debug window name is different every time (same is ok)
    let g:debugger.debugger_window_name = "dw" . g:debugger_window_id
    let g:debugger.original_bnr         = bufnr('')
    " winnr is non-uniqueness. I can not identfy window by winnr, use bufinfo instead
    let g:debugger.original_winnr        = winnr()
    let g:debugger.original_winid        = bufwinid(bufnr(""))
    let g:debugger.original_buf          = getbufinfo(bufnr(''))
    let g:debugger.original_wrap         = getwinvar(winnr(),"&wrap")
    let g:debugger.cwd                   = getcwd()
    let g:debugger.language              = g:language_setup.language
    let g:debugger.original_bufname      = bufname('%')
    let g:debugger.original_line_nr      = line(".")
    let g:debugger.original_col_nr       = col(".")
    let g:debugger.buf_winnr             = bufwinnr('%')
    let g:debugger.current_winnr         = -1
    let g:debugger.bufs                  = []
    let g:debugger.cursor_original_winid = 0    " current before terminal is created
    let g:debugger.stop_fname            = ''   " current stop file
    let g:debugger.stop_line             = 0    " current stop line
    let g:debugger.log                   = []
    let g:debugger.hangup                = 0    " check hangingup or not, no callback
                                                " shoule be exeuted while hangingup
    let g:debugger.close_msg             = "Debug Finished. Use <S-E> or 'exit' ".
                                            \ "in terminal to quit debugging"
    let g:debugger.callstack_content     = []
    let g:debugger.localvars_content     = []

    let g:debugger.stacks_winid          = 0
    let g:debugger.stacks_winnr          = 0
    let g:debugger.stacks_bufinfo        = 0
    let g:debugger.stacks_bufnr          = 0

    let g:debugger.localvars_winid       = 0
    let g:debugger.localvars_winnr       = 0
    let g:debugger.localvars_bufinfo     = 0
    let g:debugger.localvars_bufnr       = 0

    let g:debugger.tagbar_loaded         = 0

    " break_points: ['a.js|3','t/b.js|34']
    " indexs in break_points list are sign id
    let g:debugger.break_points= []
    " source code window style configuration
    let g:debugger.original_cursor_color    = util#Get_CursorLine_bgColor()
    let g:debugger.prompt_stop_arrow        = ">>"
    let g:debugger.prompt_break_point       = "**"
    let g:debugger.break_point_style_fg     = has("gui_running") ? "#df005f" : 197
    let g:debugger.stop_point_line_style_bg = has("gui_running") ? "#0000af" : 19
    let g:debugger.stop_point_text_style_fg = has("gui_running") ? "green" : "green"
    " Terminal style configuration
    let g:debugger.term_status_line         = util#Get_BgColor('StatusLineTerm')
    let g:debugger.term_status_line_nc      = util#Get_BgColor('StatusLineTermNC')
    let g:debugger.term_status_line_nc_fg   = util#Get_HiColor('StatusLineTermNC', 'fg')
    let g:debugger.hangup_term_statusline_bg_normal = has("gui_running") ? "#00af00" : "34" " normal style
    let g:debugger.hangup_term_statusline_bg_error = has("gui_running") ? "#ff0000" : "9"   " error style
    " hangup_term_style 是体验上能感知到的挂起状态，hangup 是程序真实的挂起状
    " 态，通常挂起缝隙很短，但从挂起到停驻到下一行仍然会重新计算callstack和
    " localvar，会造成闪烁，因此设置了一个hangup_term_style 的标记位
    let g:debugger.hangup_term_style         = 0
    " 这句话没用其实
    call add(g:debugger.bufs, s:Get_FullName(g:debugger.original_bufname))

    call util#hi('BreakPointStyle', g:debugger.break_point_style_fg, util#Get_BgColor('SignColumn'), "")
    call util#hi('StopPointLineStyle', -1, g:debugger.stop_point_line_style_bg, "")
    call util#hi('StopPointTextStyle', g:debugger.stop_point_text_style_fg, util#Get_BgColor('SignColumn'), "bold")
    " Define laceholder to avert screen flicker and flash during switching sign. id 9999
    call util#hi('PlaceHolder', util#Get_BgColor('SignColumn'), util#Get_BgColor('SignColumn'), "")

    exec 'sign define place_holder text='.g:debugger.prompt_stop_arrow.' texthl=PlaceHolder'
    " stop sign style, id=100
    exec 'sign define stop_point text='.g:debugger.prompt_stop_arrow.
                \ ' texthl=StopPointTextStyle linehl=StopPointLineStyle'
    " break point sign id (same as index+1 or g:debugger.break_points)
    exec 'sign define break_point text='.g:debugger.prompt_break_point.' texthl=BreakPointStyle'
    return g:debugger
endfunction " }}}

" Nodejs Chrome devtools startup {{{
function! runtime#WebInspect_Init()
    if s:Term_Is_Running()
        return s:Log_Msg("Please terminate the running debugger first.")
    endif

    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif

    if !get(g:language_setup,'DebuggerTester')()
        if has_key(g:language_setup, 'DebuggerNotInstalled')
            return s:Log_Msg(get(g:language_setup,'DebuggerNotInstalled'))
        endif
    endif

    let l:command = get(g:language_setup,'WebDebuggerCommandPrefix') .
                \ ' ' . getbufinfo('%')[0].name
    if has_key(g:language_setup, "LocalDebuggerCommandSufix")
        let l:full_command = s:String_Trim(l:command .
                    \ ' ' . get(g:language_setup, "LocalDebuggerCommandSufix"))
    else
        let l:full_command = s:String_Trim(l:command)
    endif

    call term_start(l:full_command,{
        \ 'term_finish': 'close',
        \ 'term_cols':s:Get_Term_Width(),
        \ 'vertical':'1',
        \ })

    call s:Echo_Debugging_Info(l:full_command)
endfunction " }}}

" get debugger_entry=... for startup entry file {{{
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
                let bufdir = util#Get_DirName(bufile)
                let filename = simplify(bufdir . filename)
            endif
            return filename
        endif
    endfor
    return ""
endfunction " }}}

" Inspect init {{{
function! runtime#Inspect_Init()
    if s:Term_Is_Running()
        return s:Log_Msg("Please terminate the running debugger first.")
    endif

    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif

    if !get(g:language_setup,'DebuggerTester')()
        if has_key(g:language_setup, 'DebuggerNotInstalled')
            return s:Log_Msg(get(g:language_setup,'DebuggerNotInstalled'))
        endif
    endif

    let in_file_debugger_entry = s:Get_DebuggerEntry()
    let debug_filename = in_file_debugger_entry == "" ? getbufinfo('%')[0].name : in_file_debugger_entry
    let l:command = get(g:language_setup,'LocalDebuggerCommandPrefix') . ' ' . debug_filename
    if has_key(g:language_setup, "LocalDebuggerCommandSufix")
        let l:full_command = s:String_Trim(l:command . ' ' .
                    \ get(g:language_setup, "LocalDebuggerCommandSufix"))
    else
        let l:full_command = s:String_Trim(l:command)
    endif

    call s:Create_Debugger()

    " if tagbar is loaded{{{
    if exists('g:loaded_tagbar')
        if exists('t:tagbar_buf_name') && bufwinnr(t:tagbar_buf_name) != -1
            let g:debugger.tagbar_loaded = 1
            exec "TagbarClose"
        else
            let g:debugger.tagbar_loaded = 0
        endif
    endif
    " }}}

    call runtime#Reset_Editor('silently')

    " ---Startup Terminal---
    call s:Set_Debug_CursorLine()
    call execute('setl nomodifiable')
    call execute('setl nowrap')
    " create call stack window {{{
    call s:Create_stackwindow()
    " }}}
    " create localvar window {{{
    sil! exec "vertical botright new"
    call s:Set_Bottom_Window_Statusline("localvars")
    " config localvar window
    exec s:Get_Cfg_List_Window_Wtatus_Cmd()
    call execute('setlocal nonu')
    let localvars_winnr = winnr()
    let g:debugger.localvars_winnr = localvars_winnr
    let g:debugger.localvars_bufinfo = getbufinfo(bufnr(''))
    let g:debugger.localvars_winid = bufwinid(bufnr(""))
    if has_key(g:language_setup,"ShowLocalVarsWindow") &&
                \ get(g:language_setup, 'ShowLocalVarsWindow') == 1
        " default hight of localvar window 10
        exec "abo " . (winheight(localvars_winnr) - 11) . "new"
    endif
    " }}}

    call term_start(l:full_command,{
        \ 'term_finish': 'close',
        \ 'term_name':get(g:debugger,'debugger_window_name') ,
        \ 'vertical':'1',
        \ 'curwin':'1',
        \ 'out_cb':'runtime#Term_Callback_Handler',
        \ 'out_timeout':400,
        \ 'exit_cb':'runtime#Reset_Editor',
        \ })
    call execute('setlocal nonu')
    let g:debugger.term_winid = bufwinid(get(g:debugger,'debugger_window_name'))
    " <CR>(Enter) Key linster in terminal. Do sth else when necessary.
    tnoremap <silent> <CR> <C-\><C-n>:call runtime#Special_Cmd_Handler()<CR>i
    " 监听上下键：
    " <Up> and <Down> is for showing history cmd. Should exlude them
    " <C-\><C-n> will cause pdb crash(I don't know why)，replace them to <C-W><S-N>
    tnoremap <silent> <Up> <C-W>:call runtime#Terminal_Do_Nothing()<CR><Up>
    tnoremap <silent> <Down> <C-W>:call runtime#Terminal_Do_Nothing()<CR><Down>
    call term_wait(get(g:debugger,'debugger_window_name'))
    call s:Debugger_Stop_Action(g:debugger.log)

    if has_key(g:language_setup, "TermSetupScript")
        call get(g:language_setup,"TermSetupScript")()
    endif
endfunction "}}}

" Terminal do nothing {{{
function! runtime#Terminal_Do_Nothing()
    let g:debugger.term_callback_hijacking = function("util#Do_Nothing")
    call timer_start(200,
            \ {-> util#Del_Term_Callback_Hijacking()},
             \ {'repeat' : 1})
endfunction " }}}

" Terminal do nothing but {{{
function! runtime#Terminal_Do_Nothing_But(fun_name)
    let g:debugger.term_callback_hijacking = function(a:fun_name)
    call timer_start(300,
            \ {-> util#Del_Term_Callback_Hijacking()},
             \ {'repeat' : 1})
endfunction " }}}

" set localvar window and callstack window statusline style {{{
function! s:Set_Bottom_Window_Statusline(name)
    if a:name == "stack"
        exec 'setl statusline=%1*\ Normal\ %*%5*\ Call\ Stack\ %*\ %r%f[%M]%=Depth\ :\ %L\ '
    elseif a:name == "localvars"
        exec 'setl statusline=%1*\ Normal\ %*%5*\ Local\ Variables\ %*\ %r%f[%M]%=No\ :\ %L\ '
    endif
endfunction "}}}

" Continue {{{
function! runtime#Inspect_Cont()
    if !exists('g:language_setup')
        return easydebugger#Create_Lang_Setup()
    endif
    if !exists('g:debugger')
        return s:Log_Msg("Please startup debugger first.")
    endif
    if len(get(g:debugger,'bufs')) != 0 && s:Term_Is_Running()
        call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_continue."\<CR>")
    endif
endfunction " }}}

" Next {{{
function! runtime#Inspect_Next()
    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif
    if !exists('g:debugger')
        return s:Log_Msg("Please startup debugger first.")
    endif
    if len(get(g:debugger,'bufs')) != 0 && s:Term_Is_Running()
        call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_next."\<CR>")
    endif
endfunction " }}}

" Stepin {{{
function! runtime#Inspect_Step()
    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif
    if !exists('g:debugger')
        return s:Log_Msg("Please startup debugger first.")
    endif
    if len(get(g:debugger,'bufs')) != 0 && s:Term_Is_Running()
        call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_stepin."\<CR>")
    endif
endfunction " }}}

" Stepout {{{
function! runtime#Inspect_Out()
    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif
    if !exists('g:debugger')
        return s:Log_Msg("Please startup debugger first.")
    endif
    if len(get(g:debugger,'bufs')) != 0 && s:Term_Is_Running()
        call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_stepout."\<CR>")
    endif
endfunction " }}}

" Pause {{{
function! runtime#Inspect_Pause()
    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif
    if !exists('g:debugger')
        return s:Log_Msg("Please startup debugger first.")
    endif
    if len(get(g:debugger,'bufs')) != 0 && s:Term_Is_Running()
        call term_sendkeys(get(g:debugger,'debugger_window_name'), g:language_setup.ctrl_cmd_pause."\<CR>")
    endif
endfunction " }}}

" toggle break points，press F12 {{{
function! runtime#Inspect_Set_BreakPoint()
    if !s:Term_Is_Running()
        return s:Log_Msg("Please startup debugger first.")
    endif
    let current_winid = bufwinid(bufnr(""))
    if g:debugger.original_winid != current_winid
        return s:Log_Msg("Please remove cursor to source code window.")
    endif
    if g:debugger.hangup == 1
        return util#Warning_Msg("Negative! Terminal is hanging up!")
    endif
    " If current file is original file or a new buf
    if exists("g:debugger") && (bufnr('') == g:debugger.original_bnr ||
                \ index(g:debugger.bufs,bufname('%')) >= 0 ||
                 \ bufwinnr(bufnr('')) == g:debugger.original_winnr)
        let line = line('.')
        let fname = expand("%:p")
        let breakpoint_contained = index(g:debugger.break_points, fname."|".line)
        let g:debugger.term_callback_hijacking = function("util#Do_Nothing")
        if breakpoint_contained >= 0
            " If exists break point ,then clean it
            call term_sendkeys(get(g:debugger,'debugger_window_name'),runtime#Clear_BreakPoint(fname,line))
            let sid = string(index(g:debugger.break_points, fname."|".line) + 1)
            exec ":sign unplace ".sid." file=".s:Get_FullName(fname)
            let g:debugger.break_points[str2nr(sid) - 1] = "None"
            call s:Log_Msg("Remove break point successfully.")
        else
            " If break point is not exists, then add a new one
            call term_sendkeys(get(g:debugger,'debugger_window_name'),runtime#Set_BreakPoint(fname,line))
            call add(g:debugger.break_points, fname."|".line)
            let sid = string(index(g:debugger.break_points, fname."|".line) + 1)
            exec ":sign place ".sid." line=".line." name=break_point file=".s:Get_FullName(fname)
            call s:Log_Msg("Add break point successfully.")
        endif
        call timer_start(200,
                \ {-> util#Del_Term_Callback_Hijacking()},
                 \ {'repeat' : 1})
    else
        call s:Log_Msg('No response for break point setting.')
    endif
endfunction " }}}

" clear break point {{{
function! runtime#Clear_BreakPoint(fname,line)
    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif
    return get(g:language_setup, "ClearBreakPoint")(a:fname,a:line)
endfunction " }}}

" set breakpoint {{{
function! runtime#Set_BreakPoint(fname,line)
    if !exists('g:language_setup')
        call easydebugger#Create_Lang_Setup()
    endif
    return get(g:language_setup, "SetBreakPoint")(a:fname,a:line)
endfunction " }}}

" Reset Editor when exit terminal {{{
" - silently for not closing term immediately
function! runtime#Reset_Editor(...)
    if !exists("g:debugger")
        return
    endif
    call g:Goto_Sourcecode_Window()
    " If current buf is not original buf, switch to original buf first
    if g:debugger.original_bufname !=  bufname('%') &&
                \ g:debugger.original_bufname != fnameescape(fnamemodify(bufname('%'),':p'))
        exec ":b ". g:debugger.original_bufname
    endif
    call s:Debugger_Del_TmpBuf()
    if g:debugger.original_cursor_color
        " recover cursorline style
        call execute("setlocal cursorline","silent!")
        call util#hi('CursorLine', -1 , g:debugger.original_cursor_color, "")
    endif
    if g:debugger.original_winid != bufwinid(bufnr(""))
        if !(type(a:1) == type('string') && a:1 == 'silently')
            call feedkeys("\<S-ZZ>")
        endif
    endif
    call s:Clear_All_Signs()
    call s:Clean_Hangup_Terminal_Style()
    if g:debugger.original_wrap
        call execute('set wrap','silent!')
    endif
    call execute('set modifiable','silent!')
    call execute('redraw','silent!')

    call s:Close_Varwindow()
    call s:Close_StackWindow()
    let g:debugger.log = []
    if exists('g:debugger._prev_msg')
        unlet g:debugger._prev_msg
    endif

    if exists('g:loaded_tagbar') &&
            \ !(type(a:1) == type('string') && a:1 == 'silently')
        if g:debugger.tagbar_loaded == 1
            exec "TagbarOpen"
        endif
    endif
endfunction " }}}

" hijacking term callback event {{{
function! runtime#Term_Callback_Event_Handler(channel, msg)
    if exists("g:debugger.term_callback_hijacking")
        call g:debugger.term_callback_hijacking(a:channel, a:msg, a:msg)
    endif
endfunction " }}}

function! s:None_String_Output(str) " {{{
    return s:log("→ 输入被拦截: " . a:str)
endfunction " }}}

" Terminal callback {{{
function! runtime#Term_Callback_Handler(channel, msg)
    call s:log('------------------------------out_cb----------------------------{{')
    call s:log('msg 原始信息字符串 ' . a:msg)
    call s:log('msg 原始信息Ascii  ' . join(util#ascii(a:msg), " "))

    if !exists('g:debugger._prev_msg')
        let g:debugger._prev_msg = a:msg
    endif
    let g:debugger._prev_msg = a:msg
    let m = substitute(a:msg,"\\W\\[\\d\\{-}[a-zA-Z]","","g")
    let msgslist = split(m,"\r\n")

    call s:log(string(msgslist))

    " 判断输出字符被拦截的情况{{{
    let ascii_msg = util#ascii(a:msg)

    if !exists('g:debugger') || empty(a:msg)
        return s:None_String_Output("输出为空")
    endif
    if len(a:msg) == 1
        return s:None_String_Output("正在敲入字符")
    endif
    if !s:Is_Ascii_Visiable(a:msg) && len(a:msg) == len(g:debugger._prev_msg) - 1
        return s:None_String_Output("输出字符为不可见字符, 且两次输出内容长度一致")
    endif
    if ascii_msg == [13,10]
        return s:None_String_Output("只输出回车，或者正在退出Terminal")
    endif
    if ascii_msg[-3:] == [27,91,67]
        return s:None_String_Output("带有方向键字符，说明正在输入")
    endif
    if index([7,8,9,27], char2nr(a:msg)) >= 0 &&
                \ !(len(msgslist) > 0 &&
                 \ s:String_Trim(msgslist[-1:][0]) =~ ("^". get(g:language_setup, "DebugPrompt")) . "$")
        return s:None_String_Output("首字符是 7 bell 8 退格 9 制表符 27 Esc, 且没有给出提示符")
    endif
    if index(ascii_msg, 27) >= 0 && char2nr(a:msg) != 27 &&
                \ index(ascii_msg, 13) < 0 &&
                 \ get(g:language_setup, "language") != "javascript"
        return s:None_String_Output("首字符不是 ESC，但内容中含有 ESC 符号且没有回车13，说明正在输入")
    endif
    if ascii_msg[-1:] == [8]
        return s:None_String_Output("有退格重输的情况")
    endif
    if uniq(ascii_msg) == [32]
        return s:None_String_Output("直接按Tab")
    endif
    " TODO for #50
    " c-v 粘贴进来的文本会根据这一行进行匹配，如果没有标点符号，基本就能匹配上
    " ，由此拦截成功
    " 但这个逻辑是不对的，c-v 应该被拦截，但不应该被这一句拦截，因为有好多误拦
    " 另外粘贴进来的文本种类很多，不能穷举，如果有标点符号的话就完蛋了，所以要
    " 找到一个更好的办法来拦截粘贴的文本。
    if a:msg =~ "^\\w\\+$"
        return s:None_String_Output("Tab匹配出了联想词")
    endif
    " }}}

    let g:debugger.log += msgslist
    " due to concerns about performance, limit the length of debug log under 50
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
        " cursor should focus in terminal or not after stop
        if winnr() != get(g:debugger, 'original_winnr')
            if has_key(g:language_setup, "TerminalCursorSticky") &&
                        \ g:language_setup.TerminalCursorSticky == 1
                call g:Goto_Terminal_Window()
            else
                call s:Cursor_Restore()
            endif
        endif
        return s:Log_Msg("Debug stopped")
    endif

    " Has callback hijacking
    if exists("g:debugger.term_callback_hijacking")
        " do not obstruct by stop action, only render call stack and localvars
        call s:log('term_callback_hijacking...')
        call g:debugger.term_callback_hijacking(a:channel, a:msg, full_log)
    else
        call s:Debugger_Stop_Action(g:debugger.log)
        if has_key(g:language_setup,"TermCallbackHandler")
            call g:language_setup.TermCallbackHandler(full_log)
        endif
    endif

    call s:log('------------------------------out_cb----------------------------}}')
endfunction " }}}

" Style for hangup {{{
function! s:HangUp_Sign()
    call s:log("清空停驻标记")
    if !has_key(g:debugger, "_place_holder_for_temp")
        let g:debugger._place_holder_for_temp = []
    endif
    if get(g:debugger,"stop_fname") != ""
        exec ":sign place 9998 line=1 name=place_holder file=".s:Get_FullName(g:debugger.stop_fname)
        exec ":sign unplace 100 file=".s:Get_FullName(g:debugger.stop_fname)
        if index(g:debugger._place_holder_for_temp, s:Get_FullName(g:debugger.stop_fname)) < 0
            call add(g:debugger._place_holder_for_temp, s:Get_FullName(g:debugger.stop_fname))
        endif
    endif
    let g:debugger.hangup = 1
    " we have 70ms to determine whether should terminal hangingup or not
    if exists("g:debugger._setup_terminal_style_timer")
        call timer_stop(g:debugger._setup_terminal_style_timer)
    endif
    let g:debugger._setup_terminal_style_timer =  timer_start(70,
            \ {-> s:Set_Hangup_Terminal_Style(1)},
             \ {'repeat' : 1})
endfunction " }}}

" set hangup term style : 1 → normal styel, 2 → error style {{{
function! s:Set_Hangup_Terminal_Style(flag)
    if a:flag == 1
        let bg_color = g:debugger.hangup_term_statusline_bg_normal
    else
        let bg_color = g:debugger.hangup_term_statusline_bg_error
    endif
    if g:debugger.hangup == 1
        call util#hi('StatusLineTerm', -1, bg_color, "")
        call util#hi('StatusLineTermNC', "white", bg_color, "")
        call execute('redraw','silent!')
        let g:debugger.hangup_term_style = 1
    endif
endfunction " }}}

" Clean hangup terminal style {{{
function! s:Clean_Hangup_Terminal_Style()
    if exists("g:debugger._setup_terminal_style_timer")
        call timer_stop(g:debugger._setup_terminal_style_timer)
    endif
    call s:log(util#Highlight_Args("StatusLineTerm"))
    call util#hi('StatusLineTerm', -1 , g:debugger.term_status_line , "")
    call s:log(util#Highlight_Args("StatusLineTerm"))
    call util#hi('StatusLineTermNC', g:debugger.term_status_line_nc_fg , g:debugger.term_status_line_nc , "")
    let g:debugger.hangup_term_style = 0
endfunction " }}}

" del stack and localvar {{{
function s:Empty_Stack_and_Localvars()
    call runtime#Empty_Stack_Window()
    call runtime#Empty_Localvars_Window()
endfunction " }}}

" empty stack window {{{
function! runtime#Empty_Stack_Window()
    if runtime#Stack_Window_Is_On()
        let stack_bufnr = get(g:debugger,'stacks_bufinfo')[0].bufnr
        call setbufvar(stack_bufnr, '&modifiable', 1)
        call util#deletebufline(stack_bufnr, 1, len(getbufline(stack_bufnr, 0,'$')))
        call setbufvar(stack_bufnr, '&modifiable', 0)
    endif
endfunction " }}}

" empty Localvar window {{{
function! runtime#Empty_Localvars_Window()
    if has_key(g:language_setup,"ShowLocalVarsWindow") &&
                \ get(g:language_setup, 'ShowLocalVarsWindow') == 1
        if runtime#Localvar_Window_Is_On()
            let localvar_bufnr = get(g:debugger,'localvars_bufinfo')[0].bufnr
            call setbufvar(localvar_bufnr, '&modifiable', 1)
            call util#deletebufline(localvar_bufnr, 1, len(getbufline(localvar_bufnr, 0,'$')))
            call setbufvar(localvar_bufnr, '&modifiable', 0)
        endif
    endif
endfunction " }}}

function! s:Clear_HangUp_Sign() " {{{
    if !has_key(g:debugger, "_place_holder_for_temp")
        return
    endif
    for fname in g:debugger._place_holder_for_temp
        exec ":sign unplace 9998 file=".s:Get_FullName(fname)
    endfor
endfunction " }}}

function! s:Is_Ascii_Visiable(c) " {{{
    if char2nr(a:c) >= 32 && char2nr(a:c) <= 126
        return 1
    else
        return 0
    endif
endfunction " }}}

function! s:Echo_Debugging_Info(command) " {{{
    call s:Log_Msg(a:command)
endfunction " }}}

function! s:Set_Debug_CursorLine() " {{{
    " Do Nothing
endfunction " }}}

function! s:Get_Term_Width() " {{{
    let term_width = float2nr(floor(winwidth(winnr()) * 50 / 100))
    return term_width
endfunction " }}}

function! s:Clear_All_Signs() " {{{
    exec ":sign unplace 100 file=".s:Get_FullName(g:debugger.original_bufname)
    for bfname in g:debugger.bufs
        exec ":sign unplace 100 file=".s:Get_FullName(bfname)
    endfor
    for item in g:debugger.break_points
        " break_points format: ['a.js|3','t/b.js|34']
        " break_points index is sign id
        if item == "None"
            continue
        endif
        let fname = split(item,"|")[0]
        let line  = split(item,"|")[1]
        let sid   = string(index(g:debugger.break_points, item) + 1)
        exec ":sign unplace ".sid." file=".s:Get_FullName(fname)
    endfor
    " clean all breakpoints after quit debug
    let g:debugger.break_points = []
    call s:Clear_HangUp_Sign()
endfunction " }}}

function! s:Show_Close_Msg() " {{{
    return s:Log_Msg(bufname('%')." ". get(g:debugger,'close_msg'))
endfunction " }}}

function! s:Debugger_Stop_Action(log) " {{{
    if !s:Term_Is_Running()
        return s:Log_Msg("Terminal is running.")
    endif
    let break_msg = s:Get_Term_Stop_Msg(a:log)

    " Runtime error, show msg and set hangup
    if has_key(g:language_setup, "GetErrorMsg") &&
                \ get(g:language_setup, "GetErrorMsg")(a:log) != ""
        let g:debugger.hangup = 1
        if exists("g:debugger._setup_terminal_style_timer")
            call timer_stop(g:debugger._setup_terminal_style_timer)
        endif
        let g:debugger._setup_terminal_style_timer =  timer_start(80,
                \ {-> s:Set_Hangup_Terminal_Style(0)},
                 \ {'repeat' : 1})
        let echo_msg = get(g:language_setup, "GetErrorMsg")(a:log)
        if type(break_msg) == type({})
            let echo_msg = pathshorten(break_msg.fname) . "(". string(break_msg.breakline) .") " . echo_msg
        else
            let echo_msg = echo_msg . " | Please quite or restart debug."
        endif
        return util#Echo_Msg(echo_msg, "ErrorMsg")
    endif

    call s:log('Debugger_Stop_Action '. string(a:log))

    let g:debugger.hangup = 0
    call s:HangUp_Sign()
    if type(break_msg) == type({})
        call s:log("有停驻信息")
        call s:Debugger_Stop(get(break_msg,'fname'), get(break_msg,'breakline'))
    elseif len(a:log) > 0 && trim(a:log[len(a:log) - 1]) =~ get(g:language_setup, "DebugPrompt") &&
                \ get(g:debugger, "stop_fname") != ""
        call s:Debugger_Stop(g:debugger.stop_fname, g:debugger.stop_line)
        call s:log("无停驻信息, 元命令执行完，等待输入指令")
    else
        call s:Empty_Stack_and_Localvars()
        call s:log("无停驻信息, 程序还在运行，持续挂起状态")
    endif
endfunction " }}}

" Handle logs in terminal (g:debugger.log) {{{
" Logs is nonsequence. (I don't know why)
function! s:Get_Term_Stop_Msg(log)
    if len(a:log) == 0
        return 0
    endif

    if !exists("g:language_setup")
        call easydebugger#Create_Lang_Setup()
    endif

    " here may be exeuted many many times
    " and may have some performance problems
    let break_line = 0
    let fname = ''
    let fn_regex = get(g:language_setup, "BreakFileNameRegex")
    let nr_regex = get(g:language_setup, "BreakLineNrRegex")

    for line in a:log
        " to prevent E363
        if len(line) > 200
            let line = line[0:200 - 1]
        endif
        let fn = matchstr(line, fn_regex)
        let nr = matchstr(line, nr_regex)
        if s:String_Trim(fn) != ''
            let fname = fn
        endif
        if s:String_Trim(nr) != ''
            let break_line = str2nr(nr)
        endif
    endfor

    if break_line != 0 && fname != ''
        return {"fname":fname, "breakline":break_line}
    else
        return 0
    endif
endfunction " }}}

function! s:String_Trim(str) " {{{
    return util#trim(a:str)
endfunction " }}}

function! s:Debugger_Stop(fname, line) " {{{
    let fname = s:Get_FullName(a:fname)
    let g:debugger.hangup = 0

    if !exists("g:language_setup")
        call easydebugger#Create_Lang_Setup()
    endif

    call g:Goto_Sourcecode_Window()
    let fname = s:Debugger_Get_FileBuf(fname)
    " Red Return or abort for some exception
    if (type(fname) == type(0) && fname == 0) || (type(fname) == type('string') && fname == '0')
        " TODO Nodejs 进入到internal代码时找不到 fname，就一直kill了
        call term_sendkeys(get(g:debugger,'debugger_window_name'),"kill\<CR>")
        call runtime#Reset_Editor('silently')
        return s:Show_Close_Msg()
    endif
    call execute('setlocal nocursorline','silent!')

    let shorten_filename = len(fname) > 40 ? pathshorten(fname) : fname
    call s:Log_Msg('Stop at '. shorten_filename .', line '.a:line. '.')
    " if stop line and file changed, re compute the call stack and localvars
    if has_key(g:language_setup, 'AfterStopScript')
        if fname == g:debugger.stop_fname && a:line == g:debugger.stop_line
            if g:debugger.hangup_term_style == 1
                call get(g:language_setup, 'AfterStopScript')(g:debugger.log)
            else
                call util#Do_Nothing()
            endif
        else
            call get(g:language_setup, 'AfterStopScript')(g:debugger.log)
        endif
    endif

    call s:Sign_Set_StopPoint(fname, a:line)
    call cursor(a:line,1)
    call execute('redraw','silent!')
    call execute('setl nomodifiable')

    if has_key(g:language_setup, "TerminalCursorSticky") &&
                \ g:language_setup.TerminalCursorSticky == 1
        call g:Goto_Terminal_Window()
    else
        call s:Cursor_Restore()
    endif

    let g:debugger.stop_fname = fname
    let g:debugger.stop_line = a:line
    let g:debugger.log = []
endfunction " }}}

function! s:Sign_Set_StopPoint(fname, line) " {{{
    call s:log('设置停驻标记')
    call s:Clean_Hangup_Terminal_Style()
    try
        " if file name changed
        if a:fname != g:debugger.stop_fname && g:debugger.stop_fname != ""
            exec ":sign unplace 100 file=".g:debugger.stop_fname
        endif
        exec ":sign place 9999 line=1 name=place_holder file=".s:Get_FullName(a:fname)
        exec ":sign unplace 100 file=".s:Get_FullName(a:fname)
        exec ":sign place 100 line=".string(a:line)." name=stop_point file=".s:Get_FullName(a:fname)
        exec ":sign unplace 9999 file=".s:Get_FullName(a:fname)
    catch
        call cursor(a:line,1)
    endtry
endfunction " }}}

" s:goto_win(winnr) {{{
function! s:Goto_Winnr(winnr) abort
    let cmd = type(a:winnr) == type(0) ? a:winnr . 'wincmd w'
                                     \ : 'wincmd ' . a:winnr
    noautocmd execute cmd
    call execute('redraw','silent!')
endfunction " }}}

function! g:Goto_Sourcecode_Window() " {{{
    call g:Goto_Window(g:debugger.original_winid)
endfunction " }}}

function! g:Goto_Terminal_Window() " {{{
    if s:Term_Is_Running()
        call g:Goto_Window(get(g:debugger,'term_winid'))
    endif
endfunction " }}}

function! s:Get_Cfg_List_Window_Wtatus_Cmd() " {{{
    " nowrite is a global config for all window, shoule reset it while quiting debug
    return "setl nomodifiable nolist nu noudf " .
                \ "winfixheight nowrap filetype=help buftype=nofile" " nowrite
endfunction " }}}

function! s:Add_Jump_Mapping() " {{{
    call execute("nnoremap <buffer> <CR> :call runtime#Stack_Jumpping()<CR>")
endfunction " }}}

function! runtime#Stack_Jumpping() " {{{
    let lnum = getbufinfo(bufnr(''))[0].lnum
    if exists("g:debugger.callback_stacks")
        let stacks = g:debugger.callback_stacks
        let obj = stacks[lnum - 1]
        if filereadable(obj.filename)
            call g:Goto_Sourcecode_Window()
            call execute("e " . obj.filename)
            call cursor(obj.linnr, 1) "TODO 定位到对应列
        else
            call util#Warning_Msg(obj.filename ." not exists!")
        endif
    else
        call util#Warning_Msg("g:debugger.callback_stacks is undefined!")
    endif
endfunction " }}}

function! s:Close_Varwindow() " {{{
    if runtime#Localvar_Window_Is_On()
        if !exists('g:language_setup')
            call easydebugger#Create_Lang_Setup()
        endif
        if has_key(g:language_setup,"ShowLocalVarsWindow") &&
                    \ get(g:language_setup, 'ShowLocalVarsWindow') == 1
            let current_winid = bufwinid(bufnr(""))
            call g:Goto_Window(g:debugger.localvars_winid)
            let bufnr = get(g:debugger,'localvars_bufinfo')[0].bufnr
            call setbufvar(bufnr, '&modifiable', 1)
            call util#deletebufline(bufnr, 1, len(getbufline(bufnr,0,'$')))
            call setbufvar(bufnr, '&modifiable', 0)
            call s:log(g:debugger.localvars_winid)
            call s:log(bufwinid(bufnr("")))
            call execute(':q!', 'silent!')
            call g:Goto_Window(current_winid)
        endif
        call execute('setl write', 'silent!')
    endif
endfunction " }}}

function! s:Create_Varwindow() " {{{
    if !(has_key(g:language_setup,"ShowLocalVarsWindow") &&
                \ get(g:language_setup, 'ShowLocalVarsWindow') == 1)
        return s:Log_Msg("This language dos not support localvars.")
    endif
    if !s:Term_Is_Running()
        return s:Log_Msg("Debugger is not running.")
    endif
    if runtime#Localvar_Window_Is_On()
        return s:Log_Msg("Localvar window is exists.")
    endif
    let current_winid = bufwinid(bufnr(""))
    if g:debugger.term_winid != current_winid
        call g:Goto_Terminal_Window()
    endif

    sil! exec "rightbelow 10new"
    call s:Set_Bottom_Window_Statusline("localvars")
    exec s:Get_Cfg_List_Window_Wtatus_Cmd()
    call execute('setlocal nonu')
    let g:debugger.localvars_winnr = winnr()
    let g:debugger.localvars_bufinfo = getbufinfo(bufnr(''))
    let g:debugger.localvars_winid = bufwinid(bufnr(""))
    let g:debugger.localvars_bufnr = bufnr("")

    call runtime#Render_Localvars_Window()
    call term_wait(get(g:debugger,'debugger_window_name'))
    call g:Goto_Window(current_winid)
endfunction " }}}

function! runtime#Create_VarWindow() " {{{
    call s:Create_Varwindow()
endfunction " }}}

function! runtime#Render_Localvars_Window() " {{{
    if !runtime#Localvar_Window_Is_On()
        return
    endif
    let bufnr = get(g:debugger,'localvars_bufinfo')[0].bufnr
    call s:Render_Buf(bufnr, g:debugger.localvars_content)
    let g:debugger.localvars_bufinfo = getbufinfo(bufnr)
endfunction " }}}

function! s:Close_StackWindow() " {{{
    if runtime#Stack_Window_Is_On()
        let current_winid = bufwinid(bufnr(""))
        call g:Goto_Window(g:debugger.stacks_winid)
        call execute("q!", "silent!")
        call execute('setl write', 'silent!')
        unlet g:debugger.stacks_winid
        call g:Goto_Window(current_winid)
    endif
endfunction " }}}

function! runtime#Stack_Window_Is_On() " {{{
    return exists('g:debugger.stacks_winid') && len(getwininfo(g:debugger.stacks_winid)) > 0
endfunction " }}}

function! runtime#Localvar_Window_Is_On() " {{{
    return exists('g:debugger.localvars_winid') && len(getwininfo(g:debugger.localvars_winid)) > 0
endfunction " }}}

function! runtime#Render_Stack_window() " {{{
    if !runtime#Stack_Window_Is_On()
        return
    endif
    let bufnr = get(g:debugger,'stacks_bufinfo')[0].bufnr
    call s:Render_Buf(bufnr, g:debugger.callstack_content)
    let g:debugger.stacks_bufinfo = getbufinfo(bufnr)
endfunction " }}}

function! s:Render_Buf(buf, content) " {{{
    let bufnr = a:buf
    let buf_oldlnum = len(getbufline(bufnr,0,'$'))
    call setbufvar(bufnr, '&modifiable', 1)
    let ix = 0
    for item in a:content
        let ix = ix + 1
        call setbufline(bufnr, ix, item)
    endfor
    if buf_oldlnum >= ix + 1
        call util#deletebufline(bufnr, ix + 1, buf_oldlnum)
    elseif ix == 0
        call util#deletebufline(bufnr, 1, len(getbufline(bufnr,0,'$')))
    endif
    call setbufvar(bufnr, '&modifiable', 0)
    call execute('redraw','silent!')
endfunction " }}}

function! s:Create_stackwindow() " {{{
    if runtime#Stack_Window_Is_On()
        return s:Log_Msg("Call stack window is exists")
    endif
    let current_winid = bufwinid(bufnr(""))
    if g:debugger.original_winid  != current_winid
        call g:Goto_Sourcecode_Window()
    endif
    sil! exec "bel 10new"
    call s:Set_Bottom_Window_Statusline("stack")
    let g:debugger.stacks_bufnr = bufnr("")
    let g:debugger.stacks_winid = bufwinid(bufnr(""))
    let g:debugger.stacks_winnr = winnr()
    let g:debugger.stacks_bufinfo = getbufinfo(bufnr(''))
    exec s:Get_Cfg_List_Window_Wtatus_Cmd()
    call s:Add_Jump_Mapping()
    call g:Goto_Window(current_winid)
    if s:Term_Is_Running()
        call runtime#Render_Stack_window()
    endif
endfunction " }}}

function! runtime#Create_StackWindow() " {{{
    call s:Create_stackwindow()
endfunction " }}}

" Goto Window {{{
function! g:Goto_Window(winid) abort
    if a:winid == bufwinid(bufnr(""))
        return
    endif
    for window in range(1, winnr('$'))
        call s:Goto_Winnr(window)
        if a:winid == bufwinid(bufnr(""))
            break
        endif
    endfor
endfunction " }}}

function! s:Debugger_Add_FileBuf(fname) " {{{
    exec ":badd ". a:fname
    exec ":b ". a:fname
    call add(g:debugger.bufs, a:fname)
endfunction " }}}

" del this added new buf when quit debug or reset editor{{{
function! s:Debugger_Del_TmpBuf()
    let tmp_bufs = deepcopy(g:debugger.bufs)
    for t_buf in tmp_bufs
        if t_buf != g:debugger.original_bufname &&
                    \ s:Get_FullName(g:debugger.original_bufname) != s:Get_FullName(t_buf)
            call execute('bdelete! '.t_buf,'silent!')
        endif
    endfor
    let g:debugger.bufs = []
    call add(g:debugger.bufs, s:Get_FullName(g:debugger.original_bufname))
endfunction " }}}

function! s:Debugger_Get_FileBuf(fname) " {{{
    " TODO js 里进入internal后没有给出绝对路径，需要计算
    " break in internal/modules/cjs/loader.js:704
    let fname = s:Get_FullName(a:fname)
    if !filereadable(fname)
        return 0
    endif
    if index(g:debugger.bufs , fname) < 0
        call s:Debugger_Add_FileBuf(fname)
    endif
    if fname != s:Get_FullName(bufname("%"))
        " call execute('redraw','silent!')
        try
            call execute('buffer '.a:fname)
        catch
            call util#Warning_Msg("File '" . a:fname . "' is opened in another shell. ".
                    \ " Close it first.")
        endtry
    endif
    return fname
endfunction " }}}

function! s:Get_FullName(fname) " {{{
    return fnameescape(fnamemodify(a:fname,':p'))
endfunction " }}}

" Close Terminal , Hack for NodeJS {{{
function! s:Close_Term()
    call term_sendkeys(get(g:debugger,'debugger_window_name'),"\<CR>\<C-C>\<C-C>")
    if exists('g:debugger') && g:debugger.original_winid != bufwinid(bufnr(""))
        call feedkeys("\<C-C>\<C-C>", 't')
        unlet g:debugger.term_winid
    endif
    call execute('redraw','silent!')
    call s:Log_Msg("Node Inspector terminated.")
endfunction " }}}

function! runtime#Close_Term() " {{{
    call s:Clean_Hangup_Terminal_Style()
    if !s:Term_Is_Running()
        return s:Log_Msg("Debugger is not running.")
    endif
    call term_sendkeys(get(g:debugger,'debugger_window_name'),"\<CR>exit\<CR>")
    call term_wait(get(g:debugger,'debugger_window_name'))
    if has_key(g:debugger, 'term_winid')
        unlet g:debugger.term_winid
    endif
    call execute('redraw','silent!')
    call s:Log_Msg("Debug terminated.")
endfunction " }}}

function! runtime#Mark_Cursor_Position() "{{{
    if s:Term_Is_Running()
        let g:debugger.cursor_original_winid = bufwinid(bufnr(""))
    endif
endfunction " }}}

function! s:Cursor_Restore() " {{{
    call runtime#Cursor_Restore()
endfunction " }}}

function! runtime#Cursor_Restore() " {{{
    if s:Term_Is_Running() &&
            \ g:debugger.cursor_original_winid != bufwinid(bufnr("")) &&
             \ g:debugger.cursor_original_winid != 0
        call g:Goto_Window(g:debugger.cursor_original_winid)
    endif
endfunction " }}}

function! s:Term_Is_Running() " {{{
    if exists("g:debugger") &&
            \ term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
        return 1
    else
        return 0
    endif
endfunction " }}}

function! runtime#Term_Is_Running() " {{{
    return s:Term_Is_Running()
endfunction " }}}

" Special cmd handler: for example, typein 'exit' to close terminal {{{
function! runtime#Special_Cmd_Handler()
    let cmd = getline('.')[0 : col('.')-1]
    " 'kill' is avaiable for nodejs，let NodeJS support 'exit' cmd, Heck for NodeJS
    let cmd = s:String_Trim(substitute(cmd,"^.*debug>\\s","","g"))
    if cmd == 'exit'
        call s:Close_Term()
    elseif cmd == 'restart'
        call s:Set_Debug_CursorLine()
    elseif cmd == 'run'
        call s:Set_Debug_CursorLine()
    endif
    call term_sendkeys(get(g:debugger,'debugger_window_name'),"\<CR>")
endfunction " }}}

function! s:Log_Msg(msg) " {{{
    return util#Log_Msg(a:msg)
endfunction " }}}

function! s:log(msg) " {{{
    return util#log(a:msg)
endfunction " }}}

" File:         util.vim
" Author:       @jayli
" Description:  常用函数

" debug log {{{
function! util#log(msg)
    if !exists("g:easydebugger_logging") || g:easydebugger_logging != 1
        return a:msg
    endif
    echohl Question
    echom '>>> '. a:msg
    echohl NONE
    return a:msg
endfunction " }}}

" 输出 LogMsg {{{
function! util#LogMsg(msg)
    echohl MoreMsg 
    echom '>>> '. a:msg
    echohl NONE
    return a:msg
endfunction "}}}

" 输出警告 LogMsg {{{
function! util#WarningMsg(msg)
    echohl WarningMsg 
    echom '>>> '. a:msg
    echohl NONE
    return a:msg
endfunction "}}}

" deletebufline {{{
function! util#deletebufline(bn, fl, ll)
    " version <= 801 deletebufline 不存在
    if 0 " exists("deletebufline")
        call deletebufline(a:bn, a:fl, a:ll)
    else
        let current_winid = bufwinid(bufnr(""))
        call g:Goto_window(bufwinid(a:bn))
        call execute(string(a:fl) . 'd ' . string(a:ll - a:fl), 'silent!')
        call g:Goto_window(current_winid)
    endif
endfunction " }}}

" 获得当前 CursorLine 样式 {{{
function! util#Get_CursorLine_bgColor()
    return util#Get_BgColor('CursorLine')
endfunction "}}}

" 获得某个颜色主题的背景色 {{{
function! util#Get_BgColor(name)
    return util#Get_HiColor(a:name, "bg")
endfunction "}}}

" 获得主题颜色 {{{
function! util#Get_HiColor(hiName, sufix)
    let sufix = empty(a:sufix) ? "bg" : a:sufix
    let hlString = util#Highlight_Args(a:hiName)
    if has("gui_running")
        " Gui color name
        let my_color = matchstr(hlString,"\\(\\sgui" . sufix . "=\\)\\@<=#\\w\\+")
        if my_color != ''
            return my_color
        endif
    else
        let my_color= matchstr(hlString,"\\(\\scterm" .sufix. "=\\)\\@<=\\w\\+")
        if my_color!= ''
            return my_color
        endif
    endif
    return 'none'
endfunction " }}}

" 设置主题色 {{{
function! util#hi(group, fg, bg, attr)
    let prefix = has("gui_running") ? "gui" : "cterm"
    if !empty(a:fg) && a:fg != -1
        call execute(join(['hi', a:group, prefix . "fg=" . a:fg ], " "))
    endif
    if !empty(a:bg) && a:bg != -1
        call execute(join(['hi', a:group, prefix . "bg=" . a:bg ], " "))
    endif
    if !empty(a:attr) && a:attr != ""
        call execute(join(['hi', a:group, prefix . "=" . a:attr ], " "))
    endif
endfunction " }}}

" 执行高亮 {{{
function! util#Highlight_Args(name)
    return 'hi ' . substitute(split(execute('hi ' . a:name), '\n')[0], '\<xxx\>', '', '')
endfunction "}}}

" 字符串的 ASCII 码输出，调试用 {{{
function! util#ascii(msg)
    let ta = []
    let cursor = 0
    while cursor < len(a:msg)
        call add(ta,char2nr(a:msg[cursor]))
        let cursor = cursor + 1
    endwhile
    return join(ta, " ")
endfunction " }}}

" 相当于 trim，去掉首尾的空字符 {{{
function! util#StringTrim(str)
    if !empty(a:str)
        let a1 = substitute(a:str, "^\\s\\+\\(.\\{\-}\\)$","\\1","g")
        let a1 = substitute(a:str, "^\\(.\\{\-}\\)\\s\\+$","\\1","g")
        return a1
    endif
    return ""
endfunction "}}}

" 从path中得到文件名 {{{
function! util#GetFileName(path)
    let path  = simplify(a:path)
    if len(split(path,"/")) == 1
        return path
    endif
    let fname = matchstr(path,"\\([\\/]\\)\\@<=[^\\/]\\+$")
    return fname
endfunction "}}}

" 从中得到目录名 {{{
function! util#GetDirName(path)
    let path  = simplify(a:path)
    let fname = matchstr(path,"^.\\+\\/\\([^\\/]\\{-}$\\)\\@=")
    return fname
endfunction "}}}

function! util#DoNothing(...) " {{{
endfunction " }}}

function! util#DelTermCallbackHijacking() " {{{
    unlet g:debugger.term_callback_hijacking
endfunction " }}}

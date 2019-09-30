" File:         lib/util.vim
" Author:       @jayli
" Description:  常用函数

" debug log {{{
function! lib#util#log(msg)
    if !exists("g:easydebugger_logging") || g:easydebugger_logging != 1
        return a:msg
    endif
    echohl Question
    echom '>>> '. a:msg
    echohl NONE
    return a:msg
endfunction " }}}

" 输出 LogMsg {{{
function! lib#util#LogMsg(msg)
    echohl MoreMsg 
    echom '>>> '. a:msg
    echohl NONE
    return a:msg
endfunction "}}}

" 输出警告 LogMsg {{{
function! lib#util#WarningMsg(msg)
    echohl WarningMsg 
    echom '>>> '. a:msg
    echohl NONE
    return a:msg
endfunction "}}}

" 获得当前 CursorLine 样式 {{{
function! lib#util#Get_CursorLine_bgColor()
    return lib#util#Get_BgColor('CursorLine')
endfunction "}}}

" 获得某个颜色主题的背景色 {{{
function! lib#util#Get_BgColor(name)
    if &t_Co > 255 && !has('gui_running')
        let hlString = lib#util#Highlight_Args(a:name)
        let bgColor = matchstr(hlString,"\\(\\sctermbg=\\)\\@<=\\d\\+")
        if bgColor != ''
            return str2nr(bgColor)
        endif
    endif
    return 'none'
endfunction "}}}

" 执行高亮 {{{
function! lib#util#Highlight_Args(name)
    return 'hi ' . substitute(split(execute('hi ' . a:name), '\n')[0], '\<xxx\>', '', '')
endfunction "}}}

" 相当于 trim，去掉首尾的空字符 {{{
function! lib#util#StringTrim(str)
    if !empty(a:str)
        let a1 = substitute(a:str, "^\\s\\+\\(.\\{\-}\\)$","\\1","g")
        let a1 = substitute(a:str, "^\\(.\\{\-}\\)\\s\\+$","\\1","g")
        return a1
    endif
    return ""
endfunction "}}}

" 从path中得到文件名 {{{
function! lib#util#GetFileName(path)
    let path  = simplify(a:path)
    if len(split(path,"/")) == 1
        return path
    endif
    let fname = matchstr(path,"\\([\\/]\\)\\@<=[^\\/]\\+$")
    return fname
endfunction "}}}

" 从中得到目录名 {{{
function! lib#util#GetDirName(path)
    let path  = simplify(a:path)
    let fname = matchstr(path,"^.\\+\\/\\([^\\/]\\{-}$\\)\\@=")
    return fname
endfunction "}}}

function! lib#util#DoNothing(...) " {{{
endfunction " }}}

function! lib#util#DelTermCallbackHijacking() " {{{
    unlet g:debugger.term_callback_hijacking
endfunction " }}}

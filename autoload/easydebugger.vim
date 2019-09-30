" File:         autoload/easydebugger.vim
" Author:       @jayli <http://jayli.github.io>
" Description:  vim-easydebugger 事件绑定和程序入口
"
" ╦  ╦┬┌┬┐  ╔═╗┌─┐┌─┐┬ ┬╔╦╗┌─┐┌┐ ┬ ┬┌─┐┌─┐┌─┐┬─┐
" ╚╗╔╝││││  ║╣ ├─┤└─┐└┬┘ ║║├┤ ├┴┐│ ││ ┬│ ┬├┤ ├┬┘
"  ╚╝ ┴┴ ┴  ╚═╝┴ ┴└─┘ ┴ ═╩╝└─┘└─┘└─┘└─┘└─┘└─┘┴└─

" 插件初始化入口 {{{
function! easydebugger#Enable()
    call s:Global_Setup()
    call s:Bind_Nor_Map_Keys()
    call s:Build_Command()
    call s:Bind_Term_Map_Keys()
endfunction " }}}

" 设置全局对象 {{{
function! s:Global_Setup()
    " g:debugger                Debugger 全局对象，运行 Term 时被初始化
    " g:language_setup          当前语言的 Debugger 配置，当支持当前语言的情况下随文件加载初始化
    "                           在debugger/[编程语言].vim中配置
    " g:Debug_Lang_Supported    当前支持的debug语言种类
    " g:None_Lang_Sp_Msg        当前代码不支持调试
    
    let g:Debug_Lang_Supported = ["javascript","go","python"]
    let g:None_Lang_Sp_Msg = "Not support current filetype, ".
                            \ "or move cursor to sourcecode/terminal window"
endfunction " }}}

" 每进入一个 Buffer 都重新绑定一下 Terminal 的映射命令 {{{
function! easydebugger#BindTermMapKeys()
    call s:Bind_Term_Map_Keys()
endfunction " }}}

" VIM 启动的时候绑定一次，非 Terminal 中的命令 {{{
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
    " 关闭debug
    nnoremap <silent> <Plug>EasyDebuggerExit :call easydebugger#InspectExit()<CR>
endfunction " }}}

" 每次进入一个新 Buffer 都要重新绑定一次 {{{
function! s:Bind_Term_Map_Keys()
    exec "tnoremap <silent> <Plug>EasyDebuggerContinue ".easydebugger#GetCtrlCmd('ctrl_cmd_continue')
    exec "tnoremap <silent> <Plug>EasyDebuggerNext ".easydebugger#GetCtrlCmd('ctrl_cmd_next')
    exec "tnoremap <silent> <Plug>EasyDebuggerStepIn ".easydebugger#GetCtrlCmd('ctrl_cmd_stepin')
    exec "tnoremap <silent> <Plug>EasyDebuggerStepOut ".easydebugger#GetCtrlCmd('ctrl_cmd_stepout')
    exec "tnoremap <silent> <Plug>EasyDebuggerPause ".easydebugger#GetCtrlCmd('ctrl_cmd_pause')
    exec "tnoremap <silent> <Plug>EasyDebuggerExit ".easydebugger#GetCtrlCmd('ctrl_cmd_exit')
endfunction " }}}

" 命令定义 {{{
function! s:Build_Command()
    command! -nargs=0 -complete=command -buffer InspectInit call easydebugger#InspectInit()
    command! -nargs=0 -complete=command -buffer WebInspectInit call easydebugger#WebInspectInit()
    command! -nargs=0 -complete=command InspectCont call easydebugger#InspectCont()
    command! -nargs=0 -complete=command InspectNext call easydebugger#InspectNext()
    command! -nargs=0 -complete=command InspectStep call easydebugger#InspectStep()
    command! -nargs=0 -complete=command InspectOut  call easydebugger#InspectOut()
    command! -nargs=0 -complete=command InspectPause call easydebugger#InspectPause()
    command! -nargs=0 -complete=command InspectExit call easydebugger#InspectExit()
endfunction " }}}

" 当打开新 Buffer 时根据文件类型做初始化 {{{
function! easydebugger#Create_Lang_Setup()
    call s:Create_Lang_Setup()
endfunction " }}}

" 同上 {{{
function! s:Create_Lang_Setup()
    " 初始化 g:language_setup 全局配置
    if !exists("g:Debug_Lang_Supported")
        call s:Global_Setup()
    endif

    if index(g:Debug_Lang_Supported, s:Get_Filetype()) >= 0
        " 如果当前文件类型满足条件
        call execute('let g:language_setup = debugger#'. s:Get_Filetype() .'#Setup()' )
        if exists("g:language_setup")
            let g:language_setup.language = s:Get_Filetype() 
        endif
    elseif exists("g:debugger") && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running' &&
                \ (g:debugger.localvars_winid == winnr() || g:debugger.stacks_winid == winnr())
        " 如果调试器在运行，且在stack或者localvar窗口中
        let ft = g:debugger.language
        call execute('let g:language_setup = debugger#'. ft .'#Setup()' )
        if exists("g:language_setup")
            let g:language_setup.language = ft
        endif
    else
        let g:language_setup = 0
        unlet g:language_setup 
    endif
endfunction "}}}

function! easydebugger#GetCtrlCmd(cmd) "{{{
    call s:Create_Lang_Setup()
    if !exists('g:language_setup') || !s:Language_supported(get(g:language_setup,"language")) 
        return "should_execute_nothing1"
    endif
    if has_key(g:language_setup, a:cmd)
        return get(g:language_setup, a:cmd) . "<CR>"
    else
        return "should_execute_nothing"
    endif
endfunction "}}}

function! easydebugger#InspectInit() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_supported() || !exists('g:language_setup')
        call lib#util#LogMsg(g:None_Lang_Sp_Msg)
        return ""
    endif
    call get(g:language_setup,'InspectInit')()
endfunction "}}}

function! easydebugger#WebInspectInit() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_supported() || !exists('g:language_setup')
        call lib#util#LogMsg(g:None_Lang_Sp_Msg)
        return ""
    endif
    call get(g:language_setup,'WebInspectInit')()
endfunction "}}}

function! easydebugger#InspectCont() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_supported() || !exists('g:language_setup')
        return lib#util#LogMsg(g:None_Lang_Sp_Msg)
    endif
    call lib#runtime#Mark_Cursor_Position()
    call get(g:language_setup,'InspectCont')()
endfunction "}}}

function! easydebugger#InspectNext() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_supported() || !exists('g:language_setup')
        return lib#util#LogMsg(g:None_Lang_Sp_Msg)
    endif
    call lib#runtime#Mark_Cursor_Position()
    call get(g:language_setup,'InspectNext')()
endfunction "}}}

function! easydebugger#InspectStep() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_supported() || !exists('g:language_setup')
        return lib#util#LogMsg(g:None_Lang_Sp_Msg)
    endif
    call lib#runtime#Mark_Cursor_Position()
    call get(g:language_setup,'InspectStep')()
endfunction "}}}

function! easydebugger#InspectOut() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_supported() || !exists('g:language_setup')
        return lib#util#LogMsg(g:None_Lang_Sp_Msg)
    endif
    call lib#runtime#Mark_Cursor_Position()
    call get(g:language_setup,'InspectOut')()
endfunction "}}}

function! easydebugger#InspectPause() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_supported() || !exists('g:language_setup')
        return lib#util#LogMsg(g:None_Lang_Sp_Msg)
    endif
    call lib#runtime#Mark_Cursor_Position()
    call get(g:language_setup,'InspectPause')()
endfunction "}}}

function! easydebugger#InspectSetBreakPoint() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_supported() || !exists('g:language_setup')
        return lib#util#LogMsg(g:None_Lang_Sp_Msg)
    endif
    call get(g:language_setup,'InspectSetBreakPoint')()
endfunction "}}}

function! easydebugger#InspectExit() " {{{
    call lib#runtime#Close_Term()
endfunction " }}}

" 判断语言是否被支持 {{{
function! s:Language_supported(...)
    " 如果是 quickfix window 和 tagbar 时忽略
    let ft = exists(a:0) ? a:0 : s:Get_Filetype() 
    return index(extend(deepcopy(g:Debug_Lang_Supported),['qf','tagbar']), ft) >= 0 ? 1 : 0
endfunction "}}}

function! s:Get_Filetype() "{{{
    return &filetype == "javascript.jsx" ? "javascript" : &filetype
endfunction "}}}

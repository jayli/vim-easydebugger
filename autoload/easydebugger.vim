" File:         autoload/easydebugger.vim
" Author:       @jayli <http://jayli.github.io>
" Description:  Event handler and plugin starting up
"
" ╦  ╦┬┌┬┐  ╔═╗┌─┐┌─┐┬ ┬╔╦╗┌─┐┌┐ ┬ ┬┌─┐┌─┐┌─┐┬─┐
" ╚╗╔╝││││  ║╣ ├─┤└─┐└┬┘ ║║├┤ ├┴┐│ ││ ┬│ ┬├┤ ├┬┘
"  ╚╝ ┴┴ ┴  ╚═╝┴ ┴└─┘ ┴ ═╩╝└─┘└─┘└─┘└─┘└─┘└─┘┴└─

" Launch plugin {{{
function! easydebugger#Enable()
    call s:Global_Setup()
    call s:Bind_Nor_Map_Keys()
    call s:Build_Command()
    call s:Bind_Term_Map_Keys()
endfunction " }}}

" Create global object for runtime {{{
function! s:Global_Setup()
    " g:debugger                Debugger global object, created with terminal
    "                           launched
    " g:language_setup          Current language configure, see
    "                           debugger/{language}.vim to get more infomation.
    " g:Debug_Lang_Supported    Language list supported by this plugin.
    " g:None_Lang_Sp_Msg        Non supported language warning message.

    let g:Debug_Lang_Supported = ["javascript","go","python"]
    let g:None_Lang_Sp_Msg = "Not support current filetype, ".
                            \ "or move cursor to sourcecode/terminal window"
endfunction " }}}

" Rebind terminal key-maps command after entering each buffer {{{
function! easydebugger#Bind_Term_MapKeys()
    call s:Bind_Term_Map_Keys()
endfunction " }}}

" Bind only once when vim_starting for normal mod {{{
function! s:Bind_Nor_Map_Keys()
    " Shortcut key defination
    " Launch debugger plugin
    nnoremap <silent> <Plug>EasyDebuggerInspect :call easydebugger#Inspect_Init()<CR>
    nnoremap <silent> <Plug>EasyDebuggerWebInspect :call easydebugger#WebInspect_Init()<CR>
    " Debuging key-maps
    nnoremap <silent> <Plug>EasyDebuggerContinue :call easydebugger#Inspect_Cont()<CR>
    nnoremap <silent> <Plug>EasyDebuggerNext :call easydebugger#Inspect_Next()<CR>
    nnoremap <silent> <Plug>EasyDebuggerStepIn :call easydebugger#Inspect_Step()<CR>
    nnoremap <silent> <Plug>EasyDebuggerStepOut :call easydebugger#Inspect_Out()<CR>
    nnoremap <silent> <Plug>EasyDebuggerPause :call easydebugger#Inspect_Pause()<CR>
    " Set break point
    nnoremap <silent> <Plug>EasyDebuggerSetBreakPoint :call easydebugger#Inspect_Set_BreakPoint()<CR>
    " Exit debuging
    nnoremap <silent> <Plug>EasyDebuggerExit :call easydebugger#Inspect_Exit()<CR>
    " Open local Variables window and call stack window
    nnoremap <silent> <Plug>EasyDebuggerLocalvarWindow :call runtime#Create_VarWindow()<CR>
    nnoremap <silent> <Plug>EasyDebuggerStackWindow :call runtime#Create_StackWindow()<CR>
endfunction " }}}

" Rebind key-maps after entering each buffer {{{
function! s:Bind_Term_Map_Keys()
    exec "tnoremap <silent> <Plug>EasyDebuggerContinue ".easydebugger#Get_CtrlCmd('ctrl_cmd_continue')
    exec "tnoremap <silent> <Plug>EasyDebuggerNext ".easydebugger#Get_CtrlCmd('ctrl_cmd_next')
    exec "tnoremap <silent> <Plug>EasyDebuggerStepIn ".easydebugger#Get_CtrlCmd('ctrl_cmd_stepin')
    exec "tnoremap <silent> <Plug>EasyDebuggerStepOut ".easydebugger#Get_CtrlCmd('ctrl_cmd_stepout')
    exec "tnoremap <silent> <Plug>EasyDebuggerPause ".easydebugger#Get_CtrlCmd('ctrl_cmd_pause')
    exec "tnoremap <silent> <Plug>EasyDebuggerExit ".easydebugger#Get_CtrlCmd('ctrl_cmd_exit')
endfunction " }}}

" Command defination {{{
function! s:Build_Command()
    command! -nargs=0 -complete=command Debugger       call easydebugger#Inspect_Init()
    command! -nargs=0 -complete=command InspectInit    call easydebugger#Inspect_Init()
    command! -nargs=0 -complete=command WebInspectInit call easydebugger#WebInspect_Init()
    command! -nargs=0 -complete=command InspectCont    call easydebugger#Inspect_Cont()
    command! -nargs=0 -complete=command InspectNext    call easydebugger#Inspect_Next()
    command! -nargs=0 -complete=command InspectStep    call easydebugger#Inspect_Step()
    command! -nargs=0 -complete=command InspectOut     call easydebugger#Inspect_Out()
    command! -nargs=0 -complete=command InspectPause   call easydebugger#Inspect_Pause()
    command! -nargs=0 -complete=command InspectExit    call easydebugger#Inspect_Exit()
    command! -nargs=0 -complete=command ExitDebugger   call easydebugger#Inspect_Exit()
    command! -nargs=0 -complete=command StackWindow    call runtime#Create_StackWindow()
    command! -nargs=0 -complete=command LocalvarWindow call runtime#Create_VarWindow()
    command! -nargs=0 -complete=command BreakPointSetting call easydebugger#Inspect_Set_BreakPoint()
endfunction " }}}

function! easydebugger#Exit_SourceCode() " {{{
    if runtime#Term_Is_Running() && g:debugger.original_winid  == bufwinid(bufnr(""))
        call easydebugger#Inspect_Exit()
        call execute("split " . expand("%:p"), "silent!")
    endif
endfunction " }}}

" Init language configuration according to filetype after entering a new buffer {{{
function! easydebugger#Create_Lang_Setup()
    call s:Create_Lang_Setup()
endfunction " }}}

" 同上 {{{
function! s:Create_Lang_Setup()
    " Init g:language_setup
    if !exists("g:Debug_Lang_Supported")
        call s:Global_Setup()
    endif

    if exists("g:debugger") && term_getstatus(get(g:debugger,'debugger_window_name')) == 'running'
        " If debugger is running or cursor is in stack window or localvar window
        let ft = g:debugger.language
        call execute('let g:language_setup = debugger#'. ft .'#Setup()' )
        if exists("g:language_setup")
            let g:language_setup.language = ft
        endif
    elseif index(g:Debug_Lang_Supported, s:Get_Filetype()) >= 0
        " If current filetype is supported
        call execute('let g:language_setup = debugger#'. s:Get_Filetype() .'#Setup()' )
        " call util#log(bufwinid(bufnr("")))
        if exists("g:language_setup")
            let g:language_setup.language = s:Get_Filetype()
        endif
    else
        let g:language_setup = 0
        unlet g:language_setup
    endif
endfunction "}}}

function! easydebugger#Get_CtrlCmd(cmd) "{{{
    call s:Create_Lang_Setup()
    if !exists('g:language_setup') || !s:Language_Supported(get(g:language_setup,"language")) 
        return "should_execute_nothing1"
    endif
    if has_key(g:language_setup, a:cmd)
        return get(g:language_setup, a:cmd) . "<CR>"
    else
        return "should_execute_nothing"
    endif
endfunction "}}}

function! easydebugger#Inspect_Init() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_Supported() || !exists('g:language_setup')
        return util#Log_Msg(g:None_Lang_Sp_Msg)
    endif
    call get(g:language_setup,'InspectInit')()
endfunction "}}}

function! easydebugger#WebInspect_Init() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_Supported() || !exists('g:language_setup')
        return util#Log_Msg(g:None_Lang_Sp_Msg)
    endif
    call get(g:language_setup,'WebInspectInit')()
endfunction "}}}

function! easydebugger#Inspect_Cont() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_Supported() || !exists('g:language_setup')
        return util#Log_Msg(g:None_Lang_Sp_Msg)
    endif
    call runtime#Mark_Cursor_Position()
    call get(g:language_setup,'InspectCont')()
endfunction "}}}

function! easydebugger#Inspect_Next() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_Supported() || !exists('g:language_setup')
        return util#Log_Msg(g:None_Lang_Sp_Msg)
    endif
    call runtime#Mark_Cursor_Position()
    call get(g:language_setup,'InspectNext')()
endfunction "}}}

function! easydebugger#Inspect_Step() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_Supported() || !exists('g:language_setup')
        return util#Log_Msg(g:None_Lang_Sp_Msg)
    endif
    call runtime#Mark_Cursor_Position()
    call get(g:language_setup,'InspectStep')()
endfunction "}}}

function! easydebugger#Inspect_Out() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_Supported() || !exists('g:language_setup')
        return util#Log_Msg(g:None_Lang_Sp_Msg)
    endif
    call runtime#Mark_Cursor_Position()
    call get(g:language_setup,'InspectOut')()
endfunction "}}}

function! easydebugger#Inspect_Pause() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_Supported() || !exists('g:language_setup')
        return util#Log_Msg(g:None_Lang_Sp_Msg)
    endif
    call runtime#Mark_Cursor_Position()
    call get(g:language_setup,'InspectPause')()
endfunction "}}}

function! easydebugger#Inspect_Set_BreakPoint() "{{{
    call s:Create_Lang_Setup()
    if !s:Language_Supported() || !exists('g:language_setup')
        return util#Log_Msg(g:None_Lang_Sp_Msg)
    endif
    call get(g:language_setup,'InspectSetBreakPoint')()
endfunction "}}}

function! easydebugger#Inspect_Exit() " {{{
    call runtime#Close_Term()
endfunction " }}}

" If current filetype is supported {{{
function! s:Language_Supported(...)
    " Exclude quickfix window and tagbar
    let ft = exists(a:0) ? a:0 : s:Get_Filetype()
    return index(extend(deepcopy(g:Debug_Lang_Supported),['qf','tagbar']), ft) >= 0 ? 1 : 0
endfunction "}}}

function! s:Get_Filetype() "{{{
    return &filetype == "javascript.jsx" ? "javascript" : &filetype
endfunction "}}}

function! s:Log_Msg(msg)
    call util#Log_Msg(a:msg)
endfunction

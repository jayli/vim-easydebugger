" File:         debugger/go.vim
" Author:       @jayli <http://jayli.github.io>
" Description:  Go 的实现

function! debugger#go#Setup()
    " Delve 不支持 Pause
    let setup_options = {
        \   'ctrl_cmd_continue':          "continue",
        \   'ctrl_cmd_next':              "next",
        \   'ctrl_cmd_stepin':            "step",
        \   'ctrl_cmd_stepout':           "stepout",
        \   'ctrl_cmd_pause':             "doNothing",
        \   'ctrl_cmd_exit':              "exit",
        \   'InspectInit':                function('runtime#Inspect_Init'),
        \   'WebInspectInit':             function('runtime#WebInspect_Init'),
        \   'InspectCont':                function('runtime#Inspect_Cont'),
        \   'InspectNext':                function('runtime#Inspect_Next'),
        \   'InspectStep':                function('runtime#Inspect_Step'),
        \   'InspectOut':                 function('runtime#Inspect_Out'),
        \   'InspectPause':               function('debugger#go#Inpect_Pause'),
        \   'InspectSetBreakPoint':       function('runtime#Inspect_Set_BreakPoint'),
        \   'DebuggerTester':             function('debugger#go#Command_Exists'),
        \   'ClearBreakPoint':            function("debugger#go#Clear_BreakPoint"),
        \   'SetBreakPoint':              function("debugger#go#Set_BreakPoint"),
        \   'TermSetupScript':            function('debugger#go#Term_SetupScript'),
        \   'AfterStopScript':            function('debugger#go#AfterStop_Script'),
        \   'GetErrorMsg':                function('debugger#go#Get_ErrorMsg'),
        \   'TermCallbackHandler':        function('debugger#go#Term_Callback_Handler'),
        \   'DebuggerNotInstalled':       '系统没有安装 Delve ！Please install Delve first.',
        \   'WebDebuggerCommandPrefix':   'dlv debug',
        \   'LocalDebuggerCommandPrefix': 'dlv debug',
        \   'LocalDebuggerCommandSufix':  '',
        \   'ShowLocalVarsWindow':        1,
        \   'TerminalCursorSticky':       0,
        \   'DebugPrompt':                "(dlv)",
        \   'ExecutionTerminatedMsg':     "\\(Process \\d\\{-} has exited with status\\|Process has exited with status\\)",
        \   'BreakFileNameRegex':         "\\(>\\s\\S\\+\\s\\)\\@<=\\S\\{-}.\\(go\\|s\\|c\\|cpp\\|h\\)\\(:\\d\\)\\@=",
        \   'BreakLineNrRegex':           "\\(>\\s\\S\\+\\s\\S\\{-}.\\(go\\|s\\|c\\|cpp\\|h\\):\\)\\@<=\\d\\{-}\\(\\s\\)\\@=",
        \ }
    return setup_options
endfunction


function! debugger#go#Get_ErrorMsg(line)
    " TODO
    return ""
endfunction

function! debugger#go#Term_Callback_Handler(msg)
    if type(a:msg) == type([]) &&
                \ len(a:msg) == 1 &&
                 \ a:msg[0] == "Can not debug non-main package"
        call timer_start(500,
                \ {-> s:Log_Msg(a:msg[0])},
                 \ {'repeat' : 1})
    endif
    " jayli 给 terminal 绑定Fx快捷键失败
    " call s:Fillup_Localist_window(a:msg)
    call s:Fillup_Stacks_window(a:msg)
endfunction

function! s:Fillup_Stacks_window(msg)
    let stacks = s:Get_Stack(a:msg)
    if len(stacks) == 0
        return
    endif
    call s:Set_stackslist(stacks)
    let g:debugger.log = []
    let g:debugger.callback_stacks = stacks
    let g:debugger.show_stack_log = 0

    call debugger#go#Show_LocalVar_Names()
endfunction

function! debugger#go#Show_LocalVar_Names()
    let g:debugger.term_callback_hijacking = function('debugger#go#Handle_Localvars')
    call term_sendkeys(get(g:debugger,'debugger_window_name'), "locals\<CR>")
    call timer_start(350,
            \ {-> util#Del_Term_Callback_Hijacking()},
            \ {'repeat' : 1})
endfunction

function! debugger#go#Handle_Localvars(channel, msg, full_log)
    call s:Fillup_Localvars_Window(a:full_log)
endfunction

function! s:Fillup_Localvars_Window(full_log)
    return util#Fillup_Localvars_Window(a:full_log,{ 
                \ "line_regex": "^\\w\\+\\s=\\s\\(\\s\\|\\S\\)\\{-}$", 
                \ "var_name_regex": "^\\w\\+\\s\\(=\\)\\@=", 
                \ "var_value_regex": "\\(=\\s\\)\\@<=\\(\\s\\|\\S\\)\\{-}$"
                \ })
endfunction

" function! s:Set_Localvarlist(localvars)
"     call util#Set_Localvarlist(a:localvars)
" endfunction

function! s:Set_stackslist(stacks)
    let bufnr = get(g:debugger,'stacks_bufinfo')[0].bufnr
    let buf_oldlnum = len(getbufline(bufnr,0,'$'))
    call setbufvar(bufnr, '&modifiable', 1)
    let ix = 0
    for item in a:stacks
        let ix = ix + 1
        let bufline_str = "*" . util#Get_FileName(item.filename) . "* : " .
                   \ "|" . item.linnr . "|" .
                    \ " → " . item.callstack . " [at] " . item.pointer
        call setbufline(bufnr, ix, bufline_str)
    endfor
    if buf_oldlnum >= ix + 1
        call util#deletebufline(bufnr, ix + 1, buf_oldlnum)
    elseif ix == 0
        call util#deletebufline(bufnr, 1, len(getbufline(bufnr,0,'$')))
    endif
    call setbufvar(bufnr, '&modifiable', 0)
    let g:debugger.stacks_bufinfo = getbufinfo(bufnr)
    call g:Goto_Window(get(g:debugger,'term_winid'))
    call execute('redraw','silent!')
endfunction

function! s:Get_Stack(msg)
    let stacks = []
    let go_stack_regx = "^\\d\\{-}\\s\\{-}0x\\w\\{-}\\s\\{-}in\\s\\{-}"
    let endline = len(a:msg) - 1
    let i = 0

    "stack 信息样例:
    "2  0x000000000105e7c1 in runtime.goexit
    "       at /usr/local/go/src/runtime/asm_amd64.s:1333
    while i <= endline
        if a:msg[i] =~ go_stack_regx
            let pointer = util#trim(matchstr(a:msg[i],"0x\\S\\+"))
            let callstack = util#trim(matchstr(a:msg[i],"\\(in\\s\\)\\@<=.\\+$"))
            if i == endline
                break
            endif
            let filename = util#trim(matchstr(a:msg[i+1],"\\(at\\s\\)\\@<=.\\{-}\\(:\\d\\{-}\\)\\@="))
            let linnr = util#trim(matchstr(a:msg[i+1],"\\(:\\)\\@<=\\d\\{-}$"))
            if filename == "" || linnr == "" || callstack == "" || pointer == ""
                let i = i + 1
                continue
            else
                call add(stacks, {
                    \      'filename': filename,
                     \     'linnr': linnr,
                      \    'callstack':callstack,
                       \   'pointer':pointer
                        \ })
                let i = i + 2
            endif
        else
            let i = i + 1
        endif
    endwhile

    return stacks
endfunction

function! debugger#go#Command_Exists()
    let result =    system("dlv version 2>/dev/null")
    return empty(result) ? 0 : 1
endfunction

" TermSetupScript
function! debugger#go#Term_SetupScript()
    call term_sendkeys(get(g:debugger,'debugger_window_name'),
                \ "break " .s:Get_Package(). ".main\<CR>")
    call term_wait(get(g:debugger,'debugger_window_name'))
    call g:Goto_Sourcecode_Window()
    " TODO 执行完成后光标仍然停留在term中，要停留在sourcecode里
    " call term_sendkeys(get(g:debugger,'debugger_window_name'), "continue\<CR>")
    call easydebugger#Inspect_Cont()
endfunction

function! debugger#go#AfterStop_Script(msg)
    call term_sendkeys(get(g:debugger,'debugger_window_name'), "stack\<CR>")
endfunction

function! debugger#go#Inpect_Pause()
    call util#LogMsg("Delve 不支持 Pause，'Pause' is not supported by Delve")
endfunction

function! debugger#go#Clear_BreakPoint(fname,line)
    return "clearall ".a:fname.":".a:line."\<CR>"
endfunction

function! debugger#go#Set_BreakPoint(fname,line)
    return "break ".a:fname.":".a:line."\<CR>"
endfunction

function! s:Get_Package()
    let lines = getbufline(g:debugger.original_bnr,1,'$')
    let pkg = ""
    for line in lines
        if line =~ "^\\s\\{-}package\\s\\{-}\\w\\{1,}"
            let pkg = matchstr(line,"\\(^\\s\\{-}package\\s\\{-}\\)\\@<=\\w\\{1,}")
            break
        endif
    endfor
    return pkg
endfunction

" 输出 LogMsg
function! s:Log_Msg(msg)
    call util#Log_Msg(a:msg)
endfunction

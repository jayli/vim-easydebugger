" File:         debugger/javascript.vim
" Author:       @jayli <http://jayli.github.io>
" Description:  Javascript 的实现

" 语言全局配置
function! debugger#javascript#Setup()
    let setup_options = {
        \   'ctrl_cmd_continue':          "cont",
        \   'ctrl_cmd_next':              "next",
        \   'ctrl_cmd_stepin':            "step",
        \   'ctrl_cmd_stepout':           "out",
        \   'ctrl_cmd_pause':             "pause",
        \   'ctrl_cmd_exit':              "kill",
        \   'InspectInit':                function('runtime#Inspect_Init'),
        \   'WebInspectInit':             function('runtime#WebInspect_Init'),
        \   'InspectCont':                function('runtime#Inspect_Cont'),
        \   'InspectNext':                function('runtime#Inspect_Next'),
        \   'InspectStep':                function('runtime#Inspect_Step'),
        \   'InspectOut':                 function('runtime#Inspect_Out'),
        \   'InspectPause':               function('runtime#Inspect_Pause'),
        \   'InspectSetBreakPoint':       function('runtime#Inspect_Set_BreakPoint'),
        \   'DebuggerTester':             function('debugger#javascript#Command_Exists'),
        \   'ClearBreakPoint':            function("debugger#javascript#Clear_BreakPoint"),
        \   'SetBreakPoint':              function("debugger#javascript#Set_BreakPoint"),
        \   'TermSetupScript':            function('debugger#javascript#Term_SetupScript'),
        \   'AfterStopScript':            function('debugger#javascript#After_StopScript'),
        \   'GetErrorMsg':                function('debugger#javascript#Get_ErrorMsg'),
        \   'TermCallbackHandler':        function('debugger#javascript#Term_Callback_Handler'),
        \   'DebuggerNotInstalled':       '系统没有安装 Node！Please install node first.',
        \   'WebDebuggerCommandPrefix':   'node --inspect-brk',
        \   'LocalDebuggerCommandPrefix': 'node inspect',
        \   'ShowLocalVarsWindow':        0,
        \   'TerminalCursorSticky':       0,
        \   'DebugPrompt':                'debug>',
        \   'LocalDebuggerCommandSufix':  '2>/dev/null',
        \   'ExecutionTerminatedMsg':     'Waiting for the debugger to disconnect',
        \   'BreakFileNameRegex':         "\\(^\\(break in\\|Break on start in\\)\\s.\\{-}:\\/\\/\\)\\@<=.\\{-}\\(:\\)\\@=",
        \   'BreakLineNrRegex':           "\\(^>\\s\\|^>\\)\\@<=\\(\\d\\{1,10000}\\)\\(\\s\\)\\@=",
        \ }
    return setup_options
endfunction

function! debugger#javascript#Get_ErrorMsg(line)
    return ""
endfunction

function! debugger#javascript#Command_Exists()
    let result =  system("node -v 2>/dev/null")
    return len(matchstr(result,"^v\\d\\{1,}")) >=1 ? 1 : 0
endfunction

function! debugger#javascript#Clear_BreakPoint(fname,line)
    return "clearBreakpoint('".a:fname."', ".a:line.")\<CR>"
endfunction

function! debugger#javascript#Set_BreakPoint(fname,line)
    return "setBreakpoint('".a:fname."', ".a:line.");list(1)\<CR>"
endfunction

function! debugger#javascript#Term_Callback_Handler(msg)
    call s:Fillup_Stacks_window(a:msg)
endfunction

function! s:Fillup_Stacks_window(msg)
    if len(a:msg) < 2
        return
    endif
    let stacks = reverse(s:Get_Stack(a:msg))
    if len(stacks) == 0
        return
    endif
    call s:Set_stackslist(stacks)
    let g:debugger.log = []
    let g:debugger.callback_stacks = stacks
    let g:debugger.show_stack_log = 0
endfunction

function! s:Set_stackslist(stacks)
    let bufnr = get(g:debugger,'stacks_bufinfo')[0].bufnr
    let buf_oldlnum = len(getbufline(bufnr,0,'$'))
    call setbufvar(bufnr, '&modifiable', 1)
    let ix = 0
    for item in a:stacks
        let ix = ix + 1
        let bufline_str = "*" . util#Get_FileName(item.filename) . "* : " .
                    \ "|" . item.linnr . "|" .
                    \ " → " . item.callstack . " [at] " . item.filename
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
    let js_stack_regx = "#\\d\\{-}\\s.\\+:\\d\\{-}:\\d\\{-}"
    let msg = reverse(a:msg)
    let endline = len(a:msg) - 1
    let i = 0

    "stack 信息样例:
    "#7 startup bootstrap_node.js:191:15
    while i <= endline
        if msg[i] =~ js_stack_regx
            let filename = util#trim(matchstr(msg[i],"\\(\\s\\)\\@<=\\S\\{-}\\(:\\d\\)\\@="))
            let linnr = util#trim(matchstr(msg[i],"\\(js:\\)\\@<=\\d\\{-}\\(:\\d\\)\\@="))
            let callstack = util#trim(matchstr(msg[i],"\\(#\\d\\{-}\\s\\)\\@<=\\S\\{-}\\(\\s\\)\\@="))
            let pointer = util#trim(matchstr(msg[i],"\\(#\\)\\@<=\\d\\{-}\\(\\s\\)\\@="))
            call add(stacks, {
                \   'filename': substitute(filename, "^file:\\/\\/","","g"),
                \   'linnr': linnr,
                \   'callstack':callstack,
                \   'pointer':pointer
                \ })
        endif
        let i = i + 1
    endwhile

    return stacks
endfunction

function! debugger#javascript#Term_SetupScript()
    " Do Nothing
endfunction

function! debugger#javascript#Handle_Stack_And_Localvars(channel, msg, full_log)
    call debugger#javascript#Term_Callback_Handler(a:full_log)
endfunction

function! debugger#javascript#After_StopScript(msg)
    call runtime#Terminal_Do_Nothing_But("debugger#javascript#Handle_Stack_And_Localvars")
    call debugger#javascript#Show_Stacks()
    " TODO Show Local Vars
endfunction

function! debugger#javascript#Show_Stacks()
    call term_sendkeys(get(g:debugger,'debugger_window_name'), "backtrace\<CR>")
endfunction

" 输出 LogMsg
function! s:Log_Msg(msg)
    call util#Log_Msg(a:msg)
endfunction

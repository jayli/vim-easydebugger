" File:         debugger/python.vim
" Author:       @jayli <http://jayli.github.io>
" Description:  Python 的实现

function! debugger#python#Setup()
    " Delve 不支持 Pause
    let setup_options = {
        \   'ctrl_cmd_continue':          "continue",
        \   'ctrl_cmd_next':              "next",
        \   'ctrl_cmd_stepin':            "step",
        \   'ctrl_cmd_stepout':           "up",
        \   'ctrl_cmd_exit':              "exit",
        \   'ctrl_cmd_pause':             "doNothing",
        \   'InspectInit':                function('runtime#Inspect_Init'),
        \   'WebInspectInit':             function('runtime#WebInspect_Init'),
        \   'InspectCont':                function('runtime#Inspect_Cont'),
        \   'InspectNext':                function('runtime#Inspect_Next'),
        \   'InspectStep':                function('runtime#Inspect_Step'),
        \   'InspectOut':                 function('runtime#Inspect_Out'),
        \   'InspectPause':               function('debugger#python#Inpect_Pause'),
        \   'InspectSetBreakPoint':       function('runtime#Inspect_Set_BreakPoint'),
        \   'DebuggerTester':             function('debugger#python#Command_Exists'),
        \   'ClearBreakPoint':            function("debugger#python#Clear_BreakPoint"),
        \   'SetBreakPoint':              function("debugger#python#Set_BreakPoint"),
        \   'TermSetupScript':            function('debugger#python#Term_SetupScript'),
        \   'AfterStopScript':            function('debugger#python#AfterStop_Script'),
        \   'GetErrorMsg':                function('debugger#python#Get_ErrorMsg'),
        \   'TermCallbackHandler':        function('debugger#python#Term_Callback_Handler'),
        \   'DebuggerNotInstalled':       'pdb not installed ！Please install pdb first.',
        \   'WebDebuggerCommandPrefix':   'python3 -m pdb',
        \   'LocalDebuggerCommandPrefix': 'python3 -m pdb',
        \   'ShowLocalVarsWindow':        1,
        \   'TerminalCursorSticky':       0,
        \   'DebugPrompt':                '(PDB)',
        \   'LocalDebuggerCommandSufix':  '',
        \   'ExecutionTerminatedMsg':     "\\(Process \\d\\{-} has exited with status\\|Process has exited with status\\)",
        \   'BreakFileNameRegex':         "\\(>\\s\\+\\)\\@<=\\S\\{-}\\.py\\(\\S\\+\\)\\@=",
        \   'BreakLineNrRegex':           "\\(>.\\{-}\\.py(\\)\\@<=\\d\\+\\(\\S\\)\\@=",
        \ }
    return setup_options
endfunction

function! debugger#python#Get_ErrorMsg(line)
    let flag = ""
    let ErrorTypes = [
                \ "ZeroDivisionError",
                \ "ValueError",
                \ "AssertionError",
                \ "StopIteration",
                \ "IndexError",
                \ "IndentationError",
                \ "OSError",
                \ "ImportError",
                \ "NameError",
                \ "AttributeError",
                \ "GeneratorExit",
                \ "TypeError",
                \ "KeyboardInterrupt",
                \ "OverflowError",
                \ "FloatingPointError",
                \ "BaseException",
                \ "SystemExit",
                \ "Exception",
                \ "StandardError",
                \ "ArithmeticError",
                \ "EOFError",
                \ "EnvironmentError",
                \ "WindowsError",
                \ "LookupError",
                \ "KeyError",
                \ "MemoryError",
                \ "UnboundLocalError",
                \ "ReferenceError",
                \ "RuntimeError",
                \ "NotImplementedError",
                \ "SyntaxError",
                \ "TabError",
                \ "SystemError",
                \ "UnicodeError",
                \ "UnicodeDecodeError",
                \ "UnicodeEncodeError",
                \ "UnicodeTranslateError",
                \ ]
    for line in a:line
        if line =~ "^\\(". join(ErrorTypes, "\\|") ."\\):\\s"
            let flag = line
            break
        endif
    endfor
    return flag
endfunction

function! debugger#python#Term_Callback_Handler(full_log)
    " 刷新函数调用堆栈
    if exists('g:debugger.show_stack_log') && g:debugger.show_stack_log == 1
        " 确保只在应该刷新stack时执行
        let g:debugger.show_stack_log = 0
        " 为了确保show_stack 和 show_localvars 的处理时序基本不乱，这个条件里
        " 只做term的命令输出，在show_localvars 时统一做渲染，可能会有一定的冗
        " 余，比如Fillup_Stacks_window的操作可能会有多次，但始终会保证最后
        " 一次parse是正确的
        call debugger#python#Show_LocalVar_Names()
    endif

    " 刷新本地变量列表
    if exists('g:debugger.show_localvars') && g:debugger.show_localvars == 1
        let localvars =  s:Fillup_Localvars_Window(a:full_log)
        call s:Fillup_Stacks_window(a:full_log)
        if len(localvars) != 0
            let g:debugger.show_localvars = 0
        endif
    endif
endfunction

function! s:Fillup_Localvars_Window(full_log)
    let localvars = s:Get_Localvars(a:full_log)
    call s:Set_Localvarlist(localvars)

    let g:debugger.log = []
    let g:debugger.localvars = localvars
    return localvars
endfunction

function! s:Get_Localvars(full_log)
    let vars = []
    let var_names = []
    let longest_nr = 0
    for item in a:full_log
        if item =~ "^$\\s\\S\\{-}"
            let var_name = matchstr(item,"\\(^$\\s\\)\\@<=.\\+\\(\\s=\\)\\@=")
            let var_value = matchstr(item,"\\(^$\\s\\S\\+\\s=\\s\\)\\@<=.\\+")
            if index(var_names, var_name) == -1 && var_name != '__localvars__'
                call add(vars, {"var_name": "*" . var_name . "*", "var_value": var_value})
                call add(var_names, var_name)
                if len(var_name) > longest_nr
                    let longest_nr = len(var_name)
                endif
            endif
        endif
    endfor
    " 使 vars 对齐
    let longest_nr = longest_nr + 2
    for item in vars
        if len(item['var_name']) < longest_nr
            let cursor = len(item['var_name'])
            while cursor < longest_nr
                let item['var_name'] = item['var_name'] . " "
                let cursor = cursor + 1
            endwhile
        endif
    endfor
    return vars
endfunction

function! s:Fillup_Stacks_window(full_log)
    let stacks = s:Get_Stack(a:full_log)
    if len(stacks) == 0
        return
    endif
    call s:Set_Stackslist(stacks)
    let g:debugger.log = []
    let g:debugger.callback_stacks = stacks
    let g:debugger.show_stack_log = 0
endfunction

function! s:Set_Stackslist(stacks)
    let stacks_content = []
    let ix = 0
    for item in a:stacks
        let ix = ix + 1
        let bufline_str = "*" . util#Get_FileName(item.filename) . "* : " .
                    \ "|" . item.linnr . "|" .
                    \ " → " . item.callstack
        call add(stacks_content, bufline_str)
    endfor
    let g:debugger.callstack_content = stacks_content
    call runtime#Render_Stack_window()
endfunction

function! s:Set_Localvarlist(localvars)
    let vars_content = []
    let ix = 0
    for item in a:localvars
        let ix = ix + 1
        let bufline_str = "" . item.var_name . " " . item.var_value
        " call setbufline(bufnr, ix, bufline_str)
        call add(vars_content, bufline_str)
    endfor
    let g:debugger.localvars_content = vars_content
    call runtime#Render_Localvars_Window()
endfunction

function! s:Get_Stack(full_log)
    let stacks = []
    let go_stack_regx = "^->\\s\\+\\S\\{-}"

    " 如果是键盘输入了单个字符
    if len(a:full_log) == 1
        return []
    endif

    let endline = len(a:full_log) - 1
    let i = 0

    "stack 信息提取，备注：这个循环执行的是很快的
    while i <= endline
        if a:full_log[i] =~ go_stack_regx
            let pointer = " "
            let callstack = util#trim(matchstr(a:full_log[i],"\\(->\\s\\+\\)\\@<=.\\+"))
            " if i == endline 
            "   break
            " endif
            let filename = util#trim(matchstr(a:full_log[i-1],"\\(\\s\\+\\)\\@<=\\S.\\+\\.py\\((\\d\\)\\@="))
            let linnr = util#trim(matchstr(a:full_log[i-1],"\\(\\S\\.py(\\)\\@<=\\d\\+\\()\\)\\@="))
            if filename == "" || linnr == "" || callstack == ""
                let i = i + 1
                continue
            else
                call add(stacks, {
                    \   'filename': filename,
                    \   'linnr': linnr,
                    \   'callstack':callstack,
                    \   'pointer':pointer . linnr
                    \ })
                let i = i + 1 
            endif
        else
            let i = i + 1
        endif
    endwhile

    return stacks
endfunction

function! debugger#python#Command_Exists()
    let result =    system("python3 --version 2>/dev/null")
    return empty(result) ? 0 : 1
endfunction

function! debugger#python#Term_SetupScript()
    call s:Set_Python_Localvars_Cmd()
    " call runtime#Mark_Cursor_Position()
endfunction

function! s:Set_Python_Localvars_Cmd()
    call term_sendkeys(get(g:debugger,'debugger_window_name'),
        \ "alias pi for __localvars__ in dir(): print('$ '+__localvars__+' =',str(eval(__localvars__))[0:80])\<CR>")
endfunction

function! debugger#python#AfterStop_Script(msg)
    let g:debugger.term_callback_hijacking = function('debugger#python#Handle_Stack_And_Localvars')
    call debugger#python#Show_Stacks()
    call s:Set_Python_Localvars_Cmd()
    call timer_start(350,
            \ {-> util#Del_Term_Callback_Hijacking()},
            \ {'repeat' : 1})
endfunction

function! debugger#python#Handle_Stack_And_Localvars(channel, msg, full_log)
    call debugger#python#Term_Callback_Handler(a:full_log)
endfunction

function s:Set_Stacks_Flag(flag)
    let g:debugger.show_stack_log = a:flag
endfunction

function! debugger#python#Show_Stacks()
    let g:debugger.show_stack_log = 1
    call term_sendkeys(get(g:debugger,'debugger_window_name'), "w\<CR>")
endfunction

function s:Set_Localvars_Flag(flag)
    let g:debugger.show_localvars = a:flag
endfunction

function! debugger#python#Show_LocalVar_Names()
    let g:debugger.show_localvars = 1
    call term_sendkeys(get(g:debugger,'debugger_window_name'), "pi\<CR>")
endfunction

function! debugger#python#Inpect_Pause()
    call util#Log_Msg("PDB 不支持 Pause，'Pause' is not supported by PDB")
endfunction

function! debugger#python#Clear_BreakPoint(fname,line)
    return "clear ".a:fname.":".a:line."\<CR>"
endfunction

function! debugger#python#Set_BreakPoint(fname,line)
    return "break ".a:fname.":".a:line."\<CR>"
endfunction

" 输出 LogMsg
function! s:Log_Msg(msg)
    call util#Log_Msg(a:msg)
endfunction

" 输出 debug log {{{
function! s:log(msg)
    return util#log(a:msg)
endfunction " }}}

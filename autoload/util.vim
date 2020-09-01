" File:         util.vim
" Author:       @jayli
" Description:  util tools and functions

" Debug logging {{{
function! util#log(msg)
    if !exists("g:easydebugger_logging") || g:easydebugger_logging != 1
        return a:msg
    endif
    return util#Echo_Msg(a:msg, "Question")
endfunction " }}}

" print log msg {{{
function! util#Log_Msg(msg)
    return util#Echo_Msg(a:msg, "MoreMsg")
endfunction "}}}

" print warning msg {{{
function! util#Warning_Msg(msg)
    return util#Echo_Msg(a:msg, "WarningMsg")
endfunction "}}}

" EchoMsg {{{
function! util#Echo_Msg(msg, style_group)
    exec "echohl " . a:style_group
    echom '>>> '. a:msg
    echohl NONE
    return a:msg
endfunction " }}}

function! util#Get_FileType()
    return &filetype == "javascript.jsx" ? "javascript" : &filetype
endfunction

" deletebufline {{{
function! util#deletebufline(bn, fl, ll)
    " version <= 801 deletebufline dos not exists
    if exists("deletebufline")
        call deletebufline(a:bn, a:fl, a:ll)
    else
        let current_winid = bufwinid(bufnr(""))
        call g:Goto_Window(bufwinid(a:bn))
        call execute(string(a:fl) . 'd ' . string(a:ll - a:fl), 'silent!')
        call g:Goto_Window(current_winid)
    endif
endfunction " }}}

" Get CursorLine back ground color {{{
function! util#Get_CursorLine_bgColor()
    return util#Get_BgColor('CursorLine')
endfunction "}}}

" Get back ground color form a GroupName {{{
function! util#Get_BgColor(name)
    return util#Get_HiColor(a:name, "bg")
endfunction "}}}

" Get color from a scheme group {{{
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

" Set color {{{
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

" Hilight {{{
function! util#Highlight_Args(name)
    return 'hi ' . substitute(split(execute('hi ' . a:name), '\n')[0], '\<xxx\>', '', '')
endfunction "}}}

" Get ASCII code {{{
function! util#ascii(msg)
    let taa = []
    let cursor = 0
    while cursor < len(a:msg)
        call add(taa,char2nr(a:msg[cursor]))
        let cursor = cursor + 1
    endwhile
    return taa
endfunction " }}}

" A more robust trim function {{{
function! util#trim(str)
    if !empty(a:str)
        let a1 = substitute(a:str, "^\\s\\+\\(.\\{\-}\\)$","\\1","g")
        let a1 = substitute(a:str, "^\\(.\\{\-}\\)\\s\\+$","\\1","g")
        return a1
    endif
    return ""
endfunction "}}}

" Get file name from a path {{{
function! util#Get_FileName(path)
    let path  = simplify(a:path)
    if len(split(path,"/")) == 1
        return path
    endif
    let fname = matchstr(path,"\\([\\/]\\)\\@<=[^\\/]\\+$")
    return fname
endfunction "}}}

" Get directory name from a path {{{
function! util#Get_DirName(path)
    let path  = simplify(a:path)
    let fname = matchstr(path,"^.\\+\\/\\([^\\/]\\{-}$\\)\\@=")
    return fname
endfunction "}}}

function! util#Do_Nothing(...) " {{{
endfunction " }}}

function! util#Del_Term_Callback_Hijacking() " {{{
    if exists("g:debugger.term_callback_hijacking")
        unlet g:debugger.term_callback_hijacking
    endif
endfunction " }}}

function! util#Fillup_Localvars_Window(full_log, config) " {{{
    let localvars = util#Get_Localvars(a:full_log, a:config)
    call util#Set_Localvarlist(localvars)

    let g:debugger.log = []
    let g:debugger.localvars = localvars
    return localvars
endfunction " }}}

function! util#Set_Localvarlist(localvars) " {{{
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
endfunction " }}}

function! util#Get_Localvars(full_log, config) " {{{
    let vars = []
    let var_names = []
    let longest_nr = 0
    for item in a:full_log
        if item =~ a:config.line_regex
            let var_name = util#trim(matchstr(item, a:config.var_name_regex))
            let var_value = util#trim(matchstr(item, a:config.var_value_regex))
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
endfunction " }}}

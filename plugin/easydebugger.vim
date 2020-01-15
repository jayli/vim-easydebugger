" File:         easydebugger.vim
" Author:       @jayli <http://jayli.github.io>
" Description:  init file
"
"               more infomation: <https://github.com/jayli/vim-easydebugger>
"
" ╦  ╦┬┌┬┐  ╔═╗┌─┐┌─┐┬ ┬╔╦╗┌─┐┌┐ ┬ ┬┌─┐┌─┐┌─┐┬─┐
" ╚╗╔╝││││  ║╣ ├─┤└─┐└┬┘ ║║├┤ ├┴┐│ ││ ┬│ ┬├┤ ├┬┘
"  ╚╝ ┴┴ ┴  ╚═╝┴ ┴└─┘ ┴ ═╩╝└─┘└─┘└─┘└─┘└─┘└─┘┴└─

let g:easydebugger_logging = 1

if version < 800
    finish
endif

if !has('terminal')
    finish
endif

if has( 'vim_starting' )
    augroup EasyDebuggerStart " EasyDebuggerStart {{{
        autocmd!
        autocmd VimEnter * call easydebugger#Enable()
        autocmd BufRead,BufNewFile * call easydebugger#Bind_Term_MapKeys()
        autocmd WinEnter * call runtime#Mark_Cursor_Position()
        autocmd QuitPre * call easydebugger#Exit_SourceCode()
    augroup END "}}}
endif

" File:         easydebugger.vim
" Author:       @jayli <http://jayli.github.io>
" Description:  vim-easydebugger 插件的启动文件，
"               EasyDebugger 行在 VIM 8.1 上
"
"               更多信息请访问 <https://github.com/jayli/vim-easydebugger>
"
" ╦  ╦┬┌┬┐  ╔═╗┌─┐┌─┐┬ ┬╔╦╗┌─┐┌┐ ┬ ┬┌─┐┌─┐┌─┐┬─┐
" ╚╗╔╝││││  ║╣ ├─┤└─┐└┬┘ ║║├┤ ├┴┐│ ││ ┬│ ┬├┤ ├┬┘
"  ╚╝ ┴┴ ┴  ╚═╝┴ ┴└─┘ ┴ ═╩╝└─┘└─┘└─┘└─┘└─┘└─┘┴└─

" 是否输出调试 Log 信息
let g:easydebugger_logging = 0

if version < 800
    finish
endif

if !has('terminal')
    finish
endif

if has( 'vim_starting' ) " vim 启动时加载
    augroup EasyDebuggerStart " EasyDebuggerStart {{{
        autocmd!
        autocmd VimEnter * call easydebugger#Enable()
        autocmd BufRead,BufNewFile * call easydebugger#BindTermMapKeys()
        autocmd WinEnter * call lib#runtime#Mark_Cursor_Position()
    augroup END "}}}
else " 通过 :packadd 手动加载
    call easydebugger#Enable()
    call easydebugger#BindTermMapKeys()
endif

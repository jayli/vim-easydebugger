" https://github.com/jayli/vim-easydebugger
" @author : Jayli
" @inro	: http://jayli.github.io/
if has( 'vim_starting' ) " vim 启动时加载
	augroup EasyDebuggerStart
		autocmd!
		autocmd VimEnter * call easydebugger#Enable()
	augroup END
else " 通过 :packadd 手动加载
	call easydebugger#Enable()
endif

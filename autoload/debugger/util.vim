
" 输出 LogMsg
function! debugger#util#LogMsg(msg)
	echohl MoreMsg 
	echom '>>> '. a:msg
	echohl NONE
endfunction

" 获得当前 CursorLine 样式
function! debugger#util#Get_CursorLine_bgColor()
	return debugger#util#Get_BgColor('CursorLine')
endfunction

" 获得某个颜色主题的背景色
function! debugger#util#Get_BgColor(name)
	if &t_Co > 255 && !has('gui_running')
		let hlString = debugger#util#Highlight_Args(a:name)
		let bgColor = matchstr(hlString,"\\(\\sctermbg=\\)\\@<=\\d\\{\-}\\(\\s\\)\\@=")
		if bgColor != ''
			return str2nr(bgColor)
		endif
	endif
	return 'none'
endfunction

" 执行高亮
function! debugger#util#Highlight_Args(name)
	return 'hi ' . substitute(split(execute('hi ' . a:name), '\n')[0], '\<xxx\>', '', '')
endfunction

" 相当于 trim，去掉首尾的空字符
function! debugger#util#StringTrim(str)
	if !empty(a:str)
		return substitute(a:str, "^\\s\\+\\(.\\{\-}\\)\\s\\+$","\\1","g")
	endif
	return ""
endfunction

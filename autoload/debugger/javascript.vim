

function! debugger#javascript#Init()

endfunction

function! debugger#javascript#Command_Exists()
	let result =  system("node -v 2>/dev/null")
	return len(matchstr(result,"^v\\d\\{1,}")) >=1 ? 1 : 0
endfunction


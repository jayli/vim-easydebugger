

function Action(){
	console.log(999);
	debugger;
	for(i = 1;i < 30;i++){
		var line = '*';
		for(j = 1;j <=i;j++){
			line += '**';
			line = (' ' + line);
		}
		console.log(line);
	}
}



(function(){
	new Action();
})();

const http = require('http');
const net  = require('net');
const util = require('util');

http.createServer(function(req,res){
    res.writeHead(200,{'Content-Type':'text/plain'})
    res.write("we are is content");
    debugger
    res.end(new Date().getTime().toString());
}).listen(3000);

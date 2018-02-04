'use strict';
var http = require('http');
var port = 8080;

var server = http.createServer(function (request, response) {
  if (request.url === '/') {
    response.setHeader('Content-Type', 'text/plain');
    response.end('Hello, World from Node.js!\r\n');
  }
});

server.listen(port, function () {
  console.log('I\'m listening on port ' + port + '. Try http://localhost:8080/');
});

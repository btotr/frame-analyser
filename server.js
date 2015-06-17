var express = require('express');
var app = express();
var exec = require('child_process').exec

app.use(express.static(__dirname + "/src/"));
app.listen(process.env.PORT || 8081);
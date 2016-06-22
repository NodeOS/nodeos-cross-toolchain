#!/usr/bin/env node

const fs    = require('fs')
const path  = require('path')
const spawn = require('child_process').spawn


var PATH    = process.env.PATH.split(':')
var command = process.argv[1]
var argv    = process.argv.slice(2)

var index = PATH.indexOf(path.dirname(command))
if(index >= 0) PATH = PATH.slice(index+1)

command = path.basename(command)

function onExit(code, signal)
{
  process.exit(code || signal)
}

for(var index in PATH)
{
  var fullCommand = path.join(PATH[index], command)

  try
  {
    fs.accessSync(fullCommand, fs.X_OK)

    return spawn(fullCommand, argv, {stdio: 'inherit'}).on('exit', onExit)
  }
  catch(e)
  {}
}


process.exit(127)

#!/usr/bin/env node

const path  = require('path')
const spawn = require('child_process').spawn


var PATH    = process.env.PATH.split(':')
var command = process.argv[1]
var argv    = process.argv.slice(2)

var index = PATH.indexOf(path.dirname(command))
if(index >= 0)
{
  PATH = PATH.slice(index+1)
  process.env.PATH = PATH
}


spawn(path.basename(command), argv, {stdio: 'inherit'})
.on('exit', function(code, signal)
{
  process.exit(code || signal)
})
.on('error', function(error)
{
  if(error.code === 'ENOENT') return process.exit(127)

  throw error
})

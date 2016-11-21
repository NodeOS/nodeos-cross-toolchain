#!/usr/bin/env node

// Simply move to the next command available on the `$PATH`. This is needed
// during `npm` install process


const path  = require('path')
const spawn = require('child_process').spawn


var command = process.argv[1]
var argv    = process.argv.slice(2)

// Remove us from the `$PATH` and try to find the system one again
var PATH = process.env.PATH.split(':')
var index = PATH.indexOf(path.dirname(command))
if(index >= 0)
  process.env.PATH = PATH.slice(index+1).join(':')


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

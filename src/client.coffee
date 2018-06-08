waiting = {}
fbID = 0
global.process.on "message", (o) ->
  if (key = o.key)?
    waiting[key]?(o)
    delete waiting[key]

module.exports = (snapy) ->

  Promise = snapy.Promise
  message = (type, o) -> new Promise (resolve) ->
    waiting[o.key] = resolve
    obj = {}
    obj[type] = o
    global.process.send obj 

  snapy.fs = require "fs-extra"
  snapy.chalk = require "chalk"
  snapy.getCache.hookIn (o) ->
    message "getCache", key:o.key
    .then ({cache}) -> o.oldState = cache

  snapy.setCache.hookIn (o) ->
    if o.saveState?
      message "setCache", key: o.key, value: o.saveState

  snapy.ask.hookIn (o) -> 
    message "ask", o
    .then ({success,stderr}) -> 
      o.success = success
      o.stderr = stderr
        
  snapy.report.hookIn (o) -> global.process.send report: o
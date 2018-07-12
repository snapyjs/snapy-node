requireStr = require("require-from-string")

sourceMap = require "source-map"

concat = (arr1,arr2) => Array::push.apply(arr1, arr2); return arr1
global.process = process
canceled = false

process.on "uncaughtException", (e) => console.error e
process.on "unhandledRejection", (e) => console.error e
process.on "message", (o) =>
  if o.cancel
    canceled = true
    process.send cancel: true
    global.snapy?.cancel()

lines = {}
stds = ["stdout","stderr"]
stds.forEach (stdname) =>
  lines[stdname] = []
  std = process[stdname]
  std.setEncoding("utf8")
  oldWrite = std.write
  std.write = (string, encoding, fd) =>
    l = lines[stdname]
    concat l, string.split("\n")
    l.pop() if l[l.length-1] == ""
    oldWrite.call(std, string, encoding, fd)

oldStackTrace = Error.prepareStackTrace
getNewStackTrace = (piece) =>
  smc = await new sourceMap.SourceMapConsumer(piece.map)
  return (error, stackTrace) =>
    errLines = stackTrace.map (callSite) =>
      source = callSite.getFileName()
      line = callSite.getLineNumber()
      column = callSite.getColumnNumber()
      if source == piece.name
        org = smc.originalPositionFor line: line, column: column
      else
        org = source: source, line: line, column: column
      return "    at " + (callSite.getFunctionName() or "(anonymous)") + " (#{org.source}:#{org.line}:#{org.column})"
    desc = oldStackTrace(error, stackTrace)
    errLines.unshift desc.slice 0, desc.indexOf("\n")
    return errLines.join("\n")

module.exports = (piece, current) =>
  if piece.content
    newStackTrace = await getNewStackTrace(piece)
    
    listen = (o) =>
      for stdname,i in stds
        lines[stdname] = []
      Error.prepareStackTrace = newStackTrace
      return => 
        Error.prepareStackTrace = oldStackTrace
        for stdname,i in stds
          if (l = lines[stdname])?.length > 0
            o[stdname] = l
            process.send report: o
            o[stdname] = null
    stopListen = listen origin: piece.entry
    unless canceled
      try
        requireStr piece.content, piece.name
      catch e
        console.error e
      stopListen()
      {callTest, getTestObject, cleanUp, makeTimeout} = global.snapy
      piece._tests.reduce(((acc, curr, i) =>
        acc.then =>
          unless canceled
            stopListen = listen getTestObject(curr)
            global.snapy.testID = current + i
            callTest(curr, piece.name)
            .then stopListen
        ), Promise.resolve()
      ).then =>
        if cleanUp?
          stopListen = listen origin: piece.entry
          Promise.race [
            (timeout = makeTimeout("cleanup of #{piece.entry}"))
            cleanUp.call({timeout:timeout})
          ]
          .catch (e) => console.error e
          .then stopListen
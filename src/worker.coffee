requireStr = require("require-from-string")
offsetLines = require "offset-sourcemap-lines"
sourceMapSupport = require.resolve "source-map-support"
headerGen = (name) => """
  require('#{sourceMapSupport}').install({
    retrieveSourceMap: function(source) {
      if (map = global.sourceMap["#{name}"]) {
        return {
          url: '#{name}',
          map: JSON.stringify(map)
        };
      }
      return null;
    }
  });
  """


global.process = process
listening = null
stoppedListening = null
canceled = false
process.on "message", (o) ->
  if o.listening
    listening?()
  else if o.stoppedListening
    stoppedListening?()
  else if o.cancel
    canceled = true
    process.send cancel: true
    global.snapy?.cancel()
module.exports = (piece, current) =>
  if piece.content
    maps = global.sourceMap ?= {}
    if piece.map?.version
      header = headerGen(piece.name)
      maps[piece.name] = offsetLines(piece.map,header.match(/\n/g).length)
      src = header+piece.content
    else
      src = piece.content
    listen = (file, line, source) => new Promise (resolve) =>
      origin = file + if line then ":"+line else ""
      try
        process.send listen: {origin: origin, testSource: source, testLine: line}
      listening = => 
        resolve => new Promise (resolve) => 
          stoppedListening = => resolve()
          try
            process.send stopListen: true
    listen(piece.entry)
    .then (stopListen) =>
      unless canceled
        try
          requireStr src, piece.name
        catch e
          console.error e
        stopListen()
        {callTest, getTestLine, getTestSource, getTestFile, cleanUp} = global.snapy
        piece._tests.reduce ((acc, curr, i) =>
          acc
          .then =>
            unless canceled
              listen(getTestFile(curr), getTestLine(curr), getTestSource(curr))
          .then (stopListen) =>
            unless canceled
              global.snapy.testID = current + i
              callTest(curr, piece)
              .then stopListen
          ), Promise.resolve()
    .then =>
      if (cleanUp = global.snapy?.cleanUp)?
        listen(piece.entry)
        .then (stopListen) =>
          Promise.race [
            (timeout = global.snapy.makeTimeout("cleanup of #{piece.entry}"))
            cleanUp.call({timeout:timeout})
          ]
          .catch (e) => console.error e
          .then stopListen
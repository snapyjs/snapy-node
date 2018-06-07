handleThat = require "handle-that"

module.exports =
  client: "./client"
  server: (snapy) =>
    {
    run,
    cache
    success,
    fail,
    std,
    status,
    print,
    config,
    cancel,
    path,
    util,
    ask
    } = snapy
    concat = util.concat

    webpackConfig = config.webpack
    webpackConfig.node = Object.assign {
      __dirname: false
      __filename: false
    }, webpackConfig.node or {}
    webpackConfig.externals ?= []
    entries = null
    isValid = (request) =>
      unless entries?
        {entry} = snapy.webpackConfig
        entry = await entry() if util.isFunction(entry)
        if util.isString(entry)
          entries = [entry]
        else if util.isArray(entry)
          entries = entry
        else
          entries = []
          for k,v of entry
            entries.push v
      if request.startsWith("./") or
          request.startsWith("../") or
          ~entries.indexOf(request) or 
          request == "snapy" or
          ~request.indexOf("snapy-client") or  
          ~request.indexOf("util-client")
        return true 
      return false
    webpackConfig.externals.push (context, request, cb) =>
      if request.startsWith("!")
        cb null, "commonjs "+request.replace("!","")
      else if await isValid request
        cb()
      else
        cb null, "commonjs "+request

    run.hookIn ({changedChunks, tests}, snapy) -> 
      unless snapy.isCanceled
        print "starting up worker threads", 2
        workers = []
        cancel.hookIn =>
          for worker in workers
            if worker.connected
              worker.send cancel: true
        return handleThat changedChunks, 
          worker: path.resolve(__dirname, "./worker")
          object: "tests"
          flatten: false 
          onText: if config.directOutput then (lines) => print lines.join("\n"), 0 else null
          silent: true
          onProgress: (remaining) => status "#{remaining} test chunks remaining..."
          onFork: (worker) =>
            workers.push worker
            listen = (o) => 
              closeAll = ["stdout","stderr"].map (stdname) =>
                lines = []
                stdpipe = worker[stdname]
                stdpipe.setEncoding("utf8")
                listener = (data) =>
                  concat lines, data.split("\n")
                  lines.pop() if lines[lines.length-1] == ""
                stdpipe.on "data", listener
                return [stdname, =>
                  stdpipe.removeListener "data", listener
                  return lines if lines.length > 0
                  return null
                ]
              return => 
                result = closeAll.reduce ((acc,[name,close]) =>
                  acc[name] = lines if lines = close()
                  return acc
                  ), o
                return result if result.stdout or result.stderr
            stopListen = null
            worker.on "message", (o) =>
              if o.getCache
                cache.get(o.getCache).then worker.send.bind(worker)
                .catch =>
              else if o.setCache 
                cache.set(o.setCache).then worker.send.bind(worker)
                .catch =>
              else if o.ask
                ask(o.ask).then worker.send.bind(worker)
                .catch =>
              else if o.success
                success(o.success)
              else if o.fail
                fail(o.fail)
              else if o.listen
                stopListen = listen(o.listen)
                worker.send listening: true 
              else if o.stopListen
                output = stopListen()
                std(output) if output
                worker.send stoppedListening: true
      
module.exports.configSchema =
  webpack$target:
    type: String
    default: "node"
    desc: "build target for webpack"
  directOutput: 
    type: Boolean
    default: false
    desc: "Pipes all output to terminal during testing. Usefull when developing snapy plugins"
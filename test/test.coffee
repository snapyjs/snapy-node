{test} = require "snapy"

test (snap) =>
  throw new Error "inside"
throw new Error "outside"
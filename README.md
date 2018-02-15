# snapy-node

Plugin of [snapy](https://github.com/snapyjs/snapy).

Test runner for node.

## snapy.config

```js
// ./test/snapy.config.js
module.exports = {

  // …

  // Pipes all output to terminal during testing. Usefull when developing snapy plugins
  directOutput: false, // Boolean

  // build target for webpack
  webpack.target: "node", // String

  // …

}
```

## caveats

the test files will be bundled, thus `__filename` and `__dirname` won't work as expected.
The same is true for all relatively required files:

```js
// test/test.js
require("../lib/file.js")
// lib/file.js
console.log(__dirname) // will output . instead of lib/
```

You can disable bundling by prefixing a `!`.
This will also exclude it from the change detection.
```js
// test/test.js
require("!../lib/file.js")
```

## License
Copyright (c) 2017 Paul Pflugradt
Licensed under the MIT license.

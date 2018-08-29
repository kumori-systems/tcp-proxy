(function() {
  var BASE, Parser, debug;

  debug = require('debug');

  BASE = 'tcp-proxy';

  Parser = (function() {
    function Parser() {}

    Parser.prototype.encode = function(text) {
      return JSON.stringify(text);
    };

    Parser.prototype.decode = function(text) {
      return JSON.parse(text);
    };

    return Parser;

  })();

  module.exports.getDefaultParser = function() {
    return new Parser();
  };

  module.exports.getLogger = function() {
    return {
      error: debug(BASE + ":error"),
      warn: debug(BASE + ":warn"),
      info: debug(BASE + ":info"),
      debug: debug(BASE + ":debug"),
      silly: debug(BASE + ":silly")
    };
  };

}).call(this);
//# sourceMappingURL=util.js.map
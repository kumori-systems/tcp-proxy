debug = require 'debug'

BASE = 'tcp-proxy'

class Parser

  encode: (text) ->
    return JSON.stringify text

  decode: (text) ->
    return JSON.parse text

module.exports.getDefaultParser = () ->
  return new Parser()

module.exports.getLogger = ->
  return {
    error: debug("#{BASE}:error")
    warn: debug("#{BASE}:warn")
    info: debug("#{BASE}:info")
    debug: debug("#{BASE}:debug")
    silly: debug("#{BASE}:silly")
  }

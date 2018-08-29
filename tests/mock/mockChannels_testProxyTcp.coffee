_ = require 'lodash'
q = require 'q'
EventEmitter = require('events').EventEmitter
util = require '../../lib/util'


ChanTypes =
  DUPLEX:   'slap://slapdomain/endpoints/duplex'
  REQUEST:  'slap://slapdomain/endpoints/request'
  REPLY:    'slap://slapdomain/endpoints/reply'
  RECEIVE:  'slap://slapdomain/endpoints/receive'
  SEND:     'slap://slapdomain/endpoints/send'


class Channel extends EventEmitter
  constructor: (@name, @iid) ->
    @logger ?= util.getLogger()
    @parser ?= util.getDefaultParser()

class Send extends Channel
  constructor: (@name, @iid) ->
    @logger ?= util.getLogger()
    @parser ?= util.getDefaultParser()

class Receive extends Channel
  constructor: (@name, @iid) ->
    @logger ?= util.getLogger()
    @parser ?= util.getDefaultParser()

class Request extends Channel
  constructor: (@name, @iid) ->
    @logger ?= util.getLogger()
    @parser ?= util.getDefaultParser()

class Reply extends Channel
  constructor: (@name, @iid) ->
    @logger ?= util.getLogger()
    @parser ?= util.getDefaultParser()

class Duplex extends Channel
  constructor: (@name, @iid) ->
    @logger ?= util.getLogger()
    @parser ?= util.getDefaultParser()
    @members = [@iid]
  getMembership: () ->
    return q(@members)

module.exports.Send = Send
module.exports.Receive = Receive
module.exports.Request = Request
module.exports.Reply = Reply
module.exports.Duplex = Duplex
module.exports.ChanTypes = ChanTypes
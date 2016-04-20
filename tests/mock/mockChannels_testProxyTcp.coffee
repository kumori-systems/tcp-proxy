_ = require 'lodash'
q = require 'q'
EventEmitter = require('events').EventEmitter
slaputils = require 'slaputils'


ChanTypes =
  DUPLEX:   'slap://slapdomain/endpoints/duplex'
  REQUEST:  'slap://slapdomain/endpoints/request'
  REPLY:    'slap://slapdomain/endpoints/reply'
  RECEIVE:  'slap://slapdomain/endpoints/receive'
  SEND:     'slap://slapdomain/endpoints/send'


class Channel extends EventEmitter
  constructor: (@name, @iid) ->

class Send extends Channel
  constructor: (@name, @iid) ->

class Receive extends Channel
  constructor: (@name, @iid) ->

class Request extends Channel
  constructor: (@name, @iid) ->

class Reply extends Channel
  constructor: (@name, @iid) ->

class Duplex extends Channel
  constructor: (@name, @iid) ->
    @members = [@iid]
  getMembership: () ->
    return q(@members)


slaputils.setLogger [Send, Receive, Request, Reply, Duplex]
slaputils.setParser [Send, Receive, Request, Reply, Duplex]

module.exports.Send = Send
module.exports.Receive = Receive
module.exports.Request = Request
module.exports.Reply = Reply
module.exports.Duplex = Duplex
module.exports.ChanTypes = ChanTypes
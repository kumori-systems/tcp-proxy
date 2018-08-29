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
  @dynCount = 0
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

class Duplex extends Channel
  constructor: (@name, @iid) ->
    @logger ?= util.getLogger()
    @parser ?= util.getDefaultParser()
    @members = [@iid]
  getMembership: () ->
    return q(@members)

class Request extends Channel

  constructor: (@name, @iid) ->
    @logger ?= util.getLogger()
    @parser ?= util.getDefaultParser()
    @runtimeAgent =
      createChannel: () => return new Reply("#{@name}_#{Channel.dynCount++}", \
                                            @iid)
    @lastMessageSended = null
    @connections = {}
    @parent = null

  getLastMessageSended: () ->
    return @lastMessageSended

  sendRequest: (message, channels) ->
    @logger.debug "MOCK Request #{@name} SendRequest #{message[0]}"
    return q.promise (resolve, reject) =>
      header = @parser.decode(message[0])
      switch header.type

        when 'data'
          @lastMessageSended = message[1]
          resolve [ [{status: 'OK'}, null] ]

        when 'disconnected'
          resolve [ [{status: 'OK'}, null] ]

        else
          throw new Error "Unexpected sendRequest.header.type: #{header.type}"


class Reply extends Channel

  constructor: (@name, @iid) ->
    @logger ?= util.getLogger()
    @parser ?= util.getDefaultParser()
    @runtimeAgent =
      createChannel: () => return new Reply("#{@name}_#{Channel.dynCount++}", \
                                            @iid)
  handleRequest: () ->

module.exports.Send = Send
module.exports.Receive = Receive
module.exports.Request = Request
module.exports.Reply = Reply
module.exports.Duplex = Duplex
module.exports.ChanTypes = ChanTypes
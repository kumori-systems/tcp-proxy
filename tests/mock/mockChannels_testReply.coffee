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
  @dynCount = 0
  constructor: (@name, @iid) ->

class Send extends Channel
  constructor: (@name, @iid) ->

class Receive extends Channel
  constructor: (@name, @iid) ->

class Duplex extends Channel
  constructor: (@name, @iid) ->
    @members = [@iid]
  getMembership: () ->
    return q(@members)

class Request extends Channel

  constructor: (@name, @iid) ->
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
          resolve()

        else
          throw new Error "Unexpected sendRequest.header.type: #{header.type}"


class Reply extends Channel

  constructor: (@name, @iid) ->
    @runtimeAgent =
      createChannel: () => return new Reply("#{@name}_#{Channel.dynCount++}", \
                                            @iid)
  handleRequest: () ->


slaputils.setLogger [Send, Receive, Request, Reply, Duplex]
slaputils.setParser [Send, Receive, Request, Reply, Duplex]

module.exports.Send = Send
module.exports.Receive = Receive
module.exports.Request = Request
module.exports.Reply = Reply
module.exports.Duplex = Duplex
module.exports.ChanTypes = ChanTypes
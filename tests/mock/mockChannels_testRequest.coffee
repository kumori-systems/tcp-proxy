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
    @messageReply = null
    @connections = {}
    @parent = null

  setExpectedReply: (message) ->
    @messageReply = message

  sendRequest: (message, channels) ->
    @logger.debug "MOCK Request #{@name} SendRequest #{message[0]}"
    return q.promise (resolve, reject) =>
      header = @parser.decode(message[0])
      switch header.type

        when 'connect'
          @logger.debug "MOCK Request #{@name} connect received"

          dynRepChannel = channels[0]
          dynRepChannel.parent = @

          dynReqChannel = new Request("#{@name}_#{Channel.dynCount++}", \
                                      header.fromInstance)
          dynReqChannel.parent = @

          @connections[header.connectPort] = {
            dynReqChannel: dynReqChannel
            dynRepChannel: dynRepChannel
          }

          reply = [[{status: 'OK'}]].concat([[dynReqChannel]])
          resolve reply

        when 'data'
          data = message[1]
          messageReply = @parent.messageReply
          @logger.debug "MOCK Request #{@name} data received: #{data}"

          if (messageReply is null)
            reject new Error(@parser.encode({status:'Abort', \
                                            reason:'Timed out'}))
          else
            resolve [[ {status: 'OK'}, [] ]]
            dynRepChannel = \
              @parent.connections[header.connectPort].dynRepChannel

            dynRepChannel.handleRequest [
              @parser.encode({
                type: 'data'
                connectPort: header.connectPort
              }),
              messageReply
            ]

        when 'disconnected'
          @logger.debug "MOCK Request #{@name} disconnect received"
          reply = [[{status: 'OK'}]]
          resolve reply

        else
          throw new Error "Unexpected sendRequest.header.type: #{header.type}"


class Reply extends Channel

  constructor: (@name, @iid) ->
    @logger ?= util.getLogger()
    @parser ?= util.getDefaultParser()

module.exports.Send = Send
module.exports.Receive = Receive
module.exports.Request = Request
module.exports.Reply = Reply
module.exports.Duplex = Duplex
module.exports.ChanTypes = ChanTypes
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
    @members = []
    @handleRequest = null

  getMembership: () ->
    return q(@members)

  addMember: (iid) ->
    if not @members[iid]?
      @members.push { iid: iid, endpoint: 'x', service: 'x' }
      @emit 'changeMembership', @members

  deleteMember: (iid) ->
    pos = @members.findIndex (m, i) -> return (m.iid is iid)
    if (pos > -1) then @members.splice pos, 1
    @emit 'changeMembership', @members

  deliverMessage: ([message, data]) ->
    @logger.debug "MOCK Duplex channel deliver #{message}"
    @emit('message', [message, data])

  send: (segments, target) ->
    # Instead of sends through slap, simulates a response
    message = @parser.decode segments[0]
    @logger.debug "MOCK Duplex channel send target:#{target} \
                   message:#{JSON.stringify message}"
    switch message.type
      when 'bindOnConnect'
        @logger.debug "MOCK Duplex channel processing bindOnConnect"
      when 'bindOnData'
        data = segments[1]
        @logger.debug "MOCK Duplex channel processing bindOnData data:#{data}"
        message2 = @parser.encode {
          type: 'connectOnData'
          fromInstance: message.toInstance
          toInstance: message.fromInstance
          bindPort: message.bindPort
          connectPort: message.connectPort
        }
        data2 = @parser.encode { result: 'ok' }
        @emit('message', [message2, data2])
      when 'bindOnDisconnect'
        @logger.debug "MOCK Duplex channel processing bindOnDisconnect"
      when "connectOnData"
        @logger.debug "MOCK Duplex channel processing connectOnData"
        data = segments[1]
        @emit 'connectOnData', data
      when "connectOnDisconnect"
        @logger.debug "MOCK Duplex channel processing connectOnDisconnect"
        data = segments[1] ? null
        @emit 'connectOnDisconnect', data
      else
        throw new Error "Duplex channel unknown message type #{message.type}"


slaputils.setLogger [Send, Receive, Request, Reply, Duplex]
slaputils.setParser [Send, Receive, Request, Reply, Duplex]

module.exports.Send = Send
module.exports.Receive = Receive
module.exports.Request = Request
module.exports.Reply = Reply
module.exports.Duplex = Duplex
module.exports.ChanTypes = ChanTypes
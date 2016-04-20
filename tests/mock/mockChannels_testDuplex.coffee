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
    @handleRequest = null

  getMembership: () ->
    return q(@members)

  addMember: (iid) ->
    if @members.indexOf(iid) is -1
      @members.push iid
      @emit 'changeMembership', @members

  deleteMember: (iid) ->
    _.pull @members, [iid]
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
      when 'getrolerequest'
        role = message.data.slice(0,1)
        if role is 'T'
          @logger.warn 'MOCK getrole simulated timeout'
        else
          setTimeout () =>
            if role is 'Z'
              @logger.warn 'MOCK getrole simulated error'
              message.err = 'getrole simulated error'
            else
              message.result = role
            message.type = 'getroleresponse'
            @emit('message', [@parser.encode message])
          , 500
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
        data2 = @parser.encode {result: 'ok'}
        @emit('message', [message2, data2])
      when 'bindOnDisconnect'
        @logger.debug "MOCK Duplex channel processing bindOnDisconnect"
      when "connectOnData"
        @logger.debug "MOCK Duplex channel processing connectOnData"
        data = segments[1]
        @emit 'connectOnData', data
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
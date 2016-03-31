_ = require 'lodash'
q = require 'q'
EventEmitter = require('events').EventEmitter
slaputils = require 'slaputils'
ProxyTcp  = require('../../src/index').ProxyTcp

ChanTypes =
  DUPLEX:   'slap://slapdomain/endpoints/duplex'
  REQUEST:  'slap://slapdomain/endpoints/request'
  REPLY:    'slap://slapdomain/endpoints/reply'
  RECEIVE:  'slap://slapdomain/endpoints/receive'
  SEND:     'slap://slapdomain/endpoints/send'

# ------------------------------------------------------------------------------
class Channel extends EventEmitter

  constructor: (@name, @iid) ->

# ------------------------------------------------------------------------------
class Send extends Channel

  constructor: (@name, @iid) ->

# ------------------------------------------------------------------------------
class Receive extends Channel

  constructor: (@name, @iid) ->

# ------------------------------------------------------------------------------
class DynamicRequest extends Channel

  constructor: (@name, @iid) ->

# ------------------------------------------------------------------------------
class Request extends Channel

  constructor: (@name, @iid) ->
    @messageReply = null
    @dynChannels = {}

  sendRequest: (message) ->
    @logger.debug "MOCK Request #{@name} SendRequest #{message}"
    return q.promise (resolve, reject) =>
      header = JSON.parse message[0]
      data = message[1]
      switch header.type
        when 'connect'
          @logger.debug "MOCK Request #{@name} connect received"
          if @dynChannels[header.fromInstance]?
            dynChannel = @dynChannels[header.fromInstance]
          else
            dynChannel = new Request("#{@name}_#{header.fromInstance}", @iid)
            dynChannel.messageReply = @messageReply
            @dynChannels[header.fromInstance] = dynChannel
          @logger.debug "MOCK Request #{@name} return #{dynChannel.name}"
          reply = [[@parser.encode({result: 'ok'})]].concat([[dynChannel]])
          resolve reply
        when 'disconnect'
          @logger.debug "MOCK Request #{@name} disconnect received"
          reply = @parser.encode {result: 'ok'}
          resolve [reply]
        when 'data'
          @logger.debug "MOCK Request #{@name} data received: #{data}"
          if @messageReply?
            resolve [[
              @parser.encode({result: 'ok'}),
              @parser.encode(@messageReply)
            ]]
            @messageReply = null
          else
            @messageReply = null
            reject new Error JSON.stringify({status:'Abort', \
                                            reason:'Timed out'})

  setExpectedReply: (message) ->
    @messageReply = message
    d.setExpectedReply(message) for k, d of @dynChannels

# ------------------------------------------------------------------------------
class Reply extends Channel

  constructor: (@name, @iid) ->
    @dyncount = 0
    @runtimeAgent =
      createChannel: () => return new Reply("#{@name}_#{@dyncount++}", @iid)

  deliverMessage: (message) ->
    @logger.debug "MOCK Reply Receive deliver #{message}"
    @handleRequest message

# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
class MockComponent extends EventEmitter

  constructor: (@iid, @role, @parameters, provided, required) ->
    @offerings = {}
    @dependencies = {}
    @offerings[name] = @_createChannel(name, data) for name, data of provided
    @dependencies[name] = @_createChannel(name, data) for name, data of required

  run: () -> # for tests, returns a promise
    [server, legconfig, channels] = @_computeServerParametersAndChannels()
    @proxy = new ProxyTcp @iid, @role, channels
    @proxy.on 'ready', (bindIp) =>
      @_startLegacyServer server, bindIp, legconfig
    @proxy.on 'error', (err) =>
      @_processProxyError err
    @proxy.on 'change', (data) =>
      @_reconfigLegacyServer server, bindIp, legconfig, data
    @proxy.on 'close', () =>
      @_stopLegacyServer server, legconfig

  shutdown: () -> # for tests, returns a promise
    @proxy.shutdown()

  _computeServerParametersAndChannels: () ->
    server = null
    config = null
    channels = JSON.parse(@parameters.proxyTcp)
    for name, config of channels
      config.channel = @_getChannel(name)
    return [server, config, channels]

  _startLegacyServer: (server, bindIp, legconfig) =>
    @emit 'ready', bindIp

  _reconfigLegacyServer: (server, bindIp, legconfig, data) =>

  _stopLegacyServer: (server, legconfig) =>
    @emit 'close'

  _processProxyError: (err) =>
    throw err

  _createChannel: (name, data) ->
    switch data.channel_type
      when ChanTypes.DUPLEX then return new Duplex(name, @iid)
      when ChanTypes.REQUEST then return new Request(name, @iid)
      when ChanTypes.REPLY then return new Reply(name, @iid)
      when ChanTypes.SEND then return new Send(name, @iid)
      when ChanTypes.RECEIVE then return new Receive(name, @iid)
      else throw new Error "Channel type doesnt exists: #{data.channel_type}"

  _getChannel: (name) ->
    if @offerings[name] then return @offerings[name]
    else if @dependencies[name] then return @dependencies[name]
    else throw new Error "Channel not found: #{name}"

# ------------------------------------------------------------------------------

slaputils.setLogger [Send, Receive, Request, Reply, Duplex, MockComponent]
slaputils.setParser [Send, Receive, Request, Reply, Duplex, MockComponent]

module.exports.Channel = Channel
module.exports.Duplex = Duplex
module.exports.MockComponent = MockComponent
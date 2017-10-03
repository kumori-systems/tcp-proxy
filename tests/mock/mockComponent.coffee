_ = require 'lodash'
q = require 'q'
EventEmitter = require('events').EventEmitter
slaputils = require 'slaputils'
ProxyTcp  = require('../../src/index').ProxyTcp


class MockComponent extends EventEmitter

  # static properties
  @Send: null
  @Receive: null
  @Request: null
  @Reply: null
  @Duplex: null
  @ChanTypes: null

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
      @_reconfigLegacyServer data
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

  _reconfigLegacyServer: (server, bindIp, legconfig, data) ->

  _stopLegacyServer: (server, legconfig) =>
    @emit 'close'

  _processProxyError: (err) ->
    throw err

  _createChannel: (name, data) ->
    switch data.channel_type
      when MockComponent.ChanTypes.DUPLEX
        return new MockComponent.Duplex(name, @iid)
      when MockComponent.ChanTypes.REQUEST
        return new MockComponent.Request(name, @iid)
      when MockComponent.ChanTypes.REPLY
        return new MockComponent.Reply(name, @iid)
      when MockComponent.ChanTypes.SEND
        return new MockComponent.Send(name, @iid)
      when MockComponent.ChanTypes.RECEIVE
        return new MockComponent.Receive(name, @iid)
      else
        throw new Error "Channel type doesnt exists: #{data.channel_type}"

  _getChannel: (name) ->
    if @offerings[name] then return @offerings[name]
    else if @dependencies[name] then return @dependencies[name]
    else throw new Error "Channel not found: #{name}"

  @useThisChannels: (mockChannelsFile) ->
    MockChannels = require('./' + mockChannelsFile)
    MockComponent.Send = MockChannels.Send
    MockComponent.Receive = MockChannels.Receive
    MockComponent.Request = MockChannels.Request
    MockComponent.Reply = MockChannels.Reply
    MockComponent.Duplex = MockChannels.Duplex
    MockComponent.ChanTypes = MockChannels.ChanTypes


slaputils.setLogger [MockComponent, ProxyTcp]
slaputils.setParser [MockComponent]

module.exports = MockComponent

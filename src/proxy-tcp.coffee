q                   = require 'q'
_                   = require 'lodash'
ipUtils             = require './ip-utils'
ProxyDuplexBind     = require './proxy-duplex-bind'
ProxyDuplexConnect  = require './proxy-duplex-connect'
ProxyRequest        = require './proxy-request'
ProxyReply          = require './proxy-reply'
ProxySend           = require './proxy-send'
ProxyReceive        = require './proxy-receive'
DuplexBindPort      = require './duplex-bind-port'
DuplexConnectPort   = require './duplex-connect-port'

class ProxyTcp


  constructor: (@iid, @role, @config, offerings, dependencies) ->
    method = 'ProxyTcp.constructor'
    @logger.info "#{method}"
    try
      if typeof(@config.legacyScript) is 'function'
        @legacyScript = @config.legacyScript
      else
        @legacyScript = require @config.legacyScript
    catch e
      @logger.error "#{method} #{e.stack}"
      throw e
    @channels = {} # each item contains slap-channel and its proxy
    @_createProxyChannels(offerings, @config)
    @_createProxyChannels(dependencies, @config)


  init: () ->
    method = 'ProxyTcp.init'
    @logger.info "#{method}"
    return q.promise (resolve, reject) =>
      promises = []
      promises.push channel.proxy.init() for name, channel of @channels
      q.all promises
      .then () => @legacy 'run', {bindIp: ipUtils.getIpFromIid(@iid)}
      .then () -> resolve()
      .fail (err) -> reject err


  terminate: () ->
    method = 'ProxyTcp.terminate'
    @logger.info "#{method}"
    return q.promise (resolve, reject) =>
      promises = []
      promises.push channel.proxy.terminate() for name, channel of @channels
      q.all promises
      .then () =>
        @legacy 'shutdown'
      .then () -> resolve()
      .fail (err) -> reject err


  _createProxyChannels: (source, config) ->
    method = 'ProxyTcp._createProxyChannels'
    for name, channel of source
      if config.channels[name]? # It's a proxy-channel
        @logger.info "#{method} Processing #{name} channel"
        @channels[name] =
          channel: channel
          proxy: @_createProxy(channel, config.channels[name])
        @logger.info "#{method} Add #{@channels[name].proxy.constructor.name} \
                      to #{name} channel"


  _createProxy: (channel, config) ->
    type = channel.constructor.name
    mode = config.mode
    Proxy = null
    switch type
      when 'Duplex'
        if mode is 'connect'
          Proxy = ProxyDuplexBind
          config.DuplexBindPort = DuplexBindPort
        else if mode is 'bind'
          Proxy = ProxyDuplexConnect
          config.DuplexConnectPort = DuplexConnectPort
        else throw new Error "Proxy for #{channel.name}: invalid mode #{mode}"
      when 'Request'
        Proxy = ProxyRequest
      when 'Reply'
        Proxy = ProxyReply
      when 'Send'
        Proxy = ProxySend
      when 'Receive'
        Proxy = ProxyReceive
      else throw new Error "Proxy for #{channel.name}: invalid type #{type}"
    return new Proxy(@, @role, @iid, channel, config)


  legacy: (op, params) ->
    method = 'ProxyTcp.legacy'
    @logger.info "#{method} op=#{op}"
    return q.promise (resolve, reject) =>
      try
        channels = _.cloneDeep @config.channels
        @legacyScript(op, @iid, @role, channels, params)
        .then () =>
          @logger.info "#{method} done"
          resolve()
        .fail (err) =>
          @logger.error "#{method} #{err.stack}"
          reject err
      catch err
        @logger.error "#{method} #{err.stack}"
        reject err


module.exports = ProxyTcp
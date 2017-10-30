EventEmitter        = require('events').EventEmitter
q                   = require 'q'
slaputils           = require 'slaputils'
ipUtils             = require './ip-utils'
ProxyDuplexBind     = require './proxy-duplex-bind'
ProxyDuplexConnect  = require './proxy-duplex-connect'
ProxyRequest        = require './proxy-request'
ProxyReply          = require './proxy-reply'
ProxySend           = require './proxy-send'
ProxyReceive        = require './proxy-receive'


class ProxyTcp extends EventEmitter


  # ProxyTcp contains all proxy objects needed for an instance.
  #
  # Parameters:
  # @iid: owner instance iid
  # @role: owner instance role
  # @channels: dictionary of channels to be proxied and its config.
  #            Example:
  #            {
  #              'dup1': {
  #                channel: dup1, --> slap channel object
  #                port: 9100,
  #                mode: 'bind' --> only when duplex channel (bind/connect)
  #              },
  #              'req1': {
  #                channel: req1,
  #                port: 9300
  #              }
  #            }
  #            When init() method is invoked, proxy objects are added to this
  #            dictionary.
  #
  constructor: (@iid, @role, @channels) ->
    method = 'ProxyTcp.constructor'
    if not @logger? # If logger hasn't been injected from outside
      slaputils.setLogger [ProxyTcp]
    @logger.info "#{method}"
    @_createProxyChannels()
    promises = []
    promises.push channel.proxy.init() for name, channel of @channels
    q.all promises
    .then () =>
      @emit 'ready', ipUtils.getIpFromIid(@iid)
    .fail (err) => @emit 'error', err


  shutdown: () ->
    method = 'ProxyTcp.shutdown'
    @logger.info "#{method}"
    promises = []
    promises.push channel.proxy.terminate() for name, channel of @channels
    q.all promises
    .then () =>
      @logger.info "#{method} emit close event"
      @emit 'close'
    .fail (err) =>
      @emit 'error', err


  _createProxyChannels: () ->
    method = 'ProxyTcp._createProxyChannels'
    for name, config of @channels
      @logger.info "#{method} Processing #{name} channel"
      channel = config.channel
      type = channel.constructor.name
      ports = @_getProxyPorts config
      mode = config.mode
      Proxy = null
      switch type
        when 'Duplex'
          if mode is 'bind' then Proxy = ProxyDuplexBind
          else if mode is 'connect' then Proxy = ProxyDuplexConnect
          else throw new Error "Proxy for #{name}: invalid mode #{mode}"
        when 'Request' then Proxy = ProxyRequest
        when 'Reply' then Proxy = ProxyReply
        when 'Send' then Proxy = ProxySend
        when 'Receive' then Proxy = ProxyReceive
        else throw new Error "Proxy for #{name}: invalid type #{type}"
      config.proxy = new Proxy(@, @role, @iid, channel, ports)
      @logger.info "#{method} Add #{config.proxy.constructor.name} \
                    to #{name} channel"

  _getProxyPorts: (config) ->
    ports = []
    try
      if config?.ports?
        ports = config.ports
      else if config?.port?
        ports = [config.port]
      else if config?.minPort? and config?.maxPort?
        min = Number.parseInt config.minPort
        max = Number.parseInt config.maxPort
        if min <= max
          ports = [min..max]
        else
          @logger.error "ProxyTcp.getProxyPorts. Invalid proxy configuration \
          #{config}: minPort #{min} > maxPort #{max}"
    catch error
      message = if error?.stack? then error.stack else error
      @logger.error "ProxyTcp.getProxyPorts. Invalid proxy configuration \
      #{config}: #{message}"
    return ports


  # This is a method class used to inject a logger to all dependent classes.
  # This method is used by slaputils/index.coffee/setLogger
  #
  @_loggerDependencies: () ->
    return [ProxyDuplexBind, ProxyDuplexConnect, ProxyRequest, ProxyReply, \
            ProxySend, ProxyReceive]


module.exports = ProxyTcp
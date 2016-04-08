EventEmitter        = require('events').EventEmitter
q                   = require 'q'
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
      port = config.port
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
      config.proxy = new Proxy(@, @role, @iid, channel, port)
      @logger.info "#{method} Add #{config.proxy.constructor.name} \
                    to #{name} channel"


module.exports = ProxyTcp
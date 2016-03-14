net = require 'net'
q = require 'q'
ipUtils = require './ip-utils'


# 'Proxyfication' using LB connector (reply side)
#
# ProxyReply is a (reply side) 'fake' of a legacy request-reply protocol
# implemented under tcp-protocol.
#
class ProxyReply


  # Constructor
  # - owner: ProxyTcp object that contains ProxyReply (and other proxys)
  # - role and iid of instance
  # - channel: reply channel used in "proxyfication"
  # - config: port
  #
  constructor: (@owner, @role, @iid, @channel, @config) ->
    @bindPort = @config.port
    @bindIp = ipUtils.getIpFromPool() # selects a local IP (127.1.x.x)
    @connectOptions = {host: @bindIp, port: @bindPort}
    method = 'ProxyReply.constructor'
    @name = "#{@role}/#{@iid}/#{@channel.name}/#{@bindIp}:#{@bindPort}"
    @logger.info "#{method} #{@name}"

    # Current TCP-connections structure.
    # Example (A_X = instances, 500X = connect (ephimeral) remote ports)
    #   {
    #     'A_1': {
    #       connections: {
    #         '5001': tcpClient_x
    #         '5002': tcpClient_y
    #       },
    #       dynChannel: dynChannel_z
    #     },
    #     'A_2': {
    #       connections: {
    #         '5002': socket_v
    #       },
    #       dynChannel: tcpClient_w
    #     }
    #   }
    @stickyState = {}

    @channel.handleRequest = @_handleRequest


  # Returns a promise always solved
  #
  init: () ->
    method = "ProxyReply.init #{@name}"
    @logger.info "#{method}"
    q()


  # Close current connections
  # Returns a promise always solved
  #
  terminate: () ->
    method = "ProxyReply.terminate #{@name}"
    @logger.info "#{method}"
    for iid, instance of @stickyState
      for connectPort, socket of instance
        socket.end()
    q()


  # Process requests received through reply-channel.
  # Request object:
  #   - type: must be connect
  #   - fromInstance (IID)
  #   - connectPort
  # Only "connect" requests will be receive via reply channel.
  # "Data" and "Disconnect" requests will be receive via dynamic channel.
  #
  # To process a "connect-request":
  # - Creates a new tcp-connection.
  # - Gets/creates a dynamic channel for this connection (if several connections
  #   belongs to the same instance, then uses the same dynamic channel).
  # - Returns a promise, solved when dynamic channel is created
  #
  _handleRequest: (request) =>
    method = "ProxyReply._handleRequest #{@name}"
    @logger.debug "#{method}"

    return q.promise (resolve, reject) =>
      try
        header = @parser.decode(request[0])
        if header.type isnt 'connect'
          reject new Error("Unexpected request type=#{header.type}")
        else
          iid = header.fromInstance
          connectPort = header.connectPort

          if @stickyState[iid]?.connections[connectPort]?
            throw new Error "Port #{iid}/#{connectPort} already exists"

          if @stickyState[iid]?
            dynChannel = @stickyState[iid].dynChannel
          else
            dynChannel = @channel.runtimeAgent.createChannel()
            dynChannel.handleRequest = @_handleDynamicRequest
            @stickyState[iid] =
              connections: {}
              dynChannel: dynChannel

          onConnectError = (err) -> reject err
          tcpClient = net.connect @connectOptions
          tcpClient.once 'error', onConnectError
          tcpClient.once 'connect', () =>
            @stickyState[iid].connections[connectPort] = tcpClient
            tcpClient.removeListener 'error', onConnectError
            resolve [[{}], [dynChannel]]
            tcpClient.on 'end', () =>
              @logger.debug "#{method} port:#{connectPort} event:onEnd"
            tcpClient.on 'error', () =>
              @logger.error "#{method} port:#{connectPort} event:onError \
                             #{err.stack}"
              tcpClient.end()
            tcpClient.on 'timeout', () =>
              @logger.debug "#{method} port:#{connectPort} event:onTimeout"
              tcpClient.end()
            tcpClient.on 'close', () =>
              @logger.debug "#{method} port:#{connectPort} event:onClose"
      catch err
        @logger.error "#{method} catch error: #{err.stack}"
        reject err


  # Process requests received through dynamic channel.
  # Request object:
  #   - type: data / disconnect
  #   - fromInstance (IID)
  #   - connectPort
  # Only "Data" and "Disconnect" requests will be received via dynamic channel.
  # "Connect" requests will be received via reply channel.
  #
  _handleDynamicRequest: (request) =>
    method = "ProxyReply._handleDynamicRequest #{@name}"
    @logger.debug "#{method}"
    header = @parser.decode(request[0])
    if header.type is 'disconnected'
      @_handleDisconnected(header)
    else if header.type is 'data'
      data = request[1]
      @_handleData(header, data)
    else
      q new Error "Unexpected request type=#{header.type}, sticky=#{@sticky}"


  # Process a "disconnect-request".
  #
  _handleDisconnected: (header) ->
    method = "ProxyReply._handleDisconnected #{@name}"
    @logger.debug "#{method}"
    try
      iid = request.fromInstance
      connectPort = request.connectPort
      tcpClient = @stickyState[iid]?.connections[connectPort]
      if tcpClient?
        tcpClient.end()
        delete instance.connections[connectPort]
        # To improve: remove dynamic channels if an instance doesnt have
        # connections for long time
      else
        @logger.warn "#{method} stickyState doesnt contains iid=#{iid}, \
                       connectPort=#{connectPort}"
    catch err
      @logger.error "#{method} catch error: #{err.stack}"


  # Process a "data-request"
  #
  _handleData: (header, data) ->
    method = "ProxyReply._handleData #{@name}"
    @logger.info "#{method}"
    return q.promise (resolve, reject) =>
      try
        iid = header.fromInstance
        connectPort = header.connectPort
        tcpClient = @stickyState[iid]?.connections[connectPort]
        tcpClient.write data
        tcpClient.once 'data', (reply) =>
          @logger.debug "#{method} onData"
          resolve [reply]
      catch err
        @logger.error "#{method} catch error: #{err.stack}"
        reject err


module.exports = ProxyReply
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
  # Parameters:
  # @owner: proxytcp container (permits issue events)
  # @iid: owner instance iid
  # @role: owner instance role
  # @channel: reply channel to be proxified
  # @port: legacy tcp port
  #
  constructor: (@owner, @role, @iid, @channel, @bindPort) ->
    method = 'ProxyReply.constructor'
    @bindIp = ipUtils.getIpFromPool() # selects a local IP (127.1.x.x)
    @connectOptions = {host: @bindIp, port: @bindPort}
    @name = "#{@role}/#{@iid}/#{@channel.name}/#{@bindIp}:#{@bindPort}"
    @logger.info "#{method} #{@name}"

    # Current TCP-connections dictionary.
    # Example (A_X = instances, 500X = connect (ephimeral) remote ports)
    #   {
    #     'A_1': {
    #       '5001': {
    #         socket: socket_x
    #         dynRequest: dynRequest_x
    #         dynReply: dynReply_x
    #       },
    #       '5002': {
    #         socket: socket_y
    #         dynRequest: dynRequest_y
    #         dynReply: dynReply_y
    #       },
    #     },
    #     'A_2': {
    #       '5003': {
    #         socket: socket_z
    #         dynRequest: dynRequest_z
    #         dynReply: dynReply_z
    #       }
    #     }
    #   }
    @connections = {}
    @connectionsBySocket = {}

    @channel.handleRequest = @_handleRequest


  # Returns a promise, always solved (nothing to do)
  # (promise is an interface requirement)
  #
  init: () ->
    method = "ProxyReply.init #{@name}"
    @logger.info "#{method}"
    q()


  # Close current connections.
  # Returns a promise, always solved.
  #
  terminate: () ->
    method = "ProxyReply.terminate #{@name}"
    @logger.info "#{method}"
    for iid, instance of @connections
      for port, connection of instance
        connection.socket.end()
    q()


  # Process a connection request received through reply-channel.
  # Request object:
  #   - type: must be "connect"
  #   - fromInstance (IID)
  #   - connectPort
  #   - dynRequest channel
  # Only "connect" requests will be receive via reply channel.
  # "Data" and "Disconnect" requests will be receive via dynamic channel.
  #
  # To process a "connect-request":
  # - Creates a new tcp-connection.
  # - Creates a dynReply channel, used with dynRequest channel received, for
  #   exchange data
  #
  _handleRequest: ([header], [dynRequest]) =>
    method = "ProxyReply._handleRequest #{@name}"
    @logger.debug "#{method}"

    return q.promise (resolve, reject) =>
      try
        header = @parser.decode(header)
        if header.type isnt 'connect'
          reject new Error("Unexpected request type=#{header.type}")
        else
          iid = header.fromInstance
          connectPort = header.connectPort

          if @connections[iid]?[connectPort]?
            throw new Error "Port #{iid}/#{connectPort} already exists"

          onConnectError = (err) -> reject err
          socket = net.connect @connectOptions
          socket.once 'error', onConnectError
          socket.once 'connect', () =>
            method = "#{method} port:#{connectPort}"
            socket.removeListener 'error', onConnectError
            dynReply = @channel.runtimeAgent.createChannel()

            if not @connections[iid]? then @connections[iid] = {}
            @connections[iid][connectPort] = {
              iid: iid
              connectPort: connectPort
              socket: socket
              dynRequest: dynRequest
              dynReply: dynReply
            }
            @connectionsBySocket[socket.localPort] = @connections[iid][connectPort]

            # Tcp events
            socket.on 'data', (data) => @_onTcpData(data, connectPort, socket)
            socket.on 'end', () => @_onTcpEnd(connectPort, socket)
            socket.on 'error', (err) =>
              @logger.error "#{method} event:onError #{err.stack}"
              socket.end()
            socket.on 'timeout', () =>
              @logger.error "#{method} event:onTimeout"
              socket.end()
            socket.on 'close', () =>
              @logger.debug "#{method} event:onClose"

            # Channel events
            parent = @
            dynReply.handleRequest = ([header, data]) ->
              header = @parser.decode(header)
              if header.type is 'data'
                parent._onChannelData(header, data)
              else if header.type is 'disconnected'
                parent._onChannelEnd(header)
              else
                err = new Error("Unexpected request type=#{header.type}")
                @logger.error "#{method} err:#{err.message}"
                q(err)

            resolve [[{}], [dynReply]]

      catch err
        @logger.error "#{method} catch error: #{err.stack}"
        reject err


  # Tcp-connection receives new data.
  # Data must be sended through dynamic request channel.
  #
  _onTcpData: (data, connectPort, socket) =>
    method = "ProxyReply._onTcpData #{@name}"
    @logger.debug "#{method} port:#{connectPort}"
    console.log "JJJ1 ------------------------------------ #{socket.localPort}"
    @_getCurrentDynRequest(socket)
    .then (dynRequest) =>
      console.log "JJJ3 ------------------------------------"
      dynRequest.sendRequest [
        @parser.encode(@_createMessageHeader('data', connectPort)),
        data
      ]
    .then (reply) =>
      console.log "JJJ4 ------------------------------------ #{reply}"
      # It's just an ACK response
      status = @parser.decode(reply[0][0])
      if status.result isnt 'ok'
        @logger.error "#{method} status: #{status.result}"
        socket.end()
    .fail (err) =>
      console.log "JJJ5 ------------------------------------"
      @logger.error "#{method} err: #{err.stack}"
      socket.end()


  # Dynamic channel receives new data.
  # Data must be sended through tcp-connection.
  #
  _onChannelData: (header, data, socket) ->
    method = "ProxyReply._onChannelData #{@name}"
    @logger.debug "#{method}"
    return q.promise (resolve, reject) =>
      try
        iid = header.fromInstance
        connectPort = header.connectPort
        @connections[iid][connectPort].socket.write(data)
        resolve [{}] # Its just an ACK
      catch err
        @logger.error "#{method} catch error: #{err.stack}"
        reject err


  # Tcp-connection receives a disconnect.
  # Disconnect must be sended through dynamic request channel.
  #
  _onTcpEnd: (connectPort, socket) =>
    method = "ProxyReply._onTcpEnd #{@name} port:#{connectPort}"
    @logger.debug "#{method}"
    @_getCurrentDynRequest(socket)
    .then (dynRequest) =>
      dynRequest.sendRequest [
        @parser.encode @_createMessageHeader('disconnect', connectPort)
      ]
    .then (reply) =>
      # It's just an ACK response
      status = @parser.decode(reply[0][0])
      if status.result isnt 'ok'
        @logger.error "#{method} status: #{status.result}"
    .fail (err) =>
      @logger.error "#{method} #{err.stack}"
    .done () =>
      conn = @connectionsBySocket[socket.localPort]
      delete @connections[conn.iid][conn.connectPort]
      delete @connectionsBySocket[socket.localPort]


  # Dynamic channel receives a disconnect.
  # Tcp-connection must be disconnected too.
  #
  _onChannelEnd: (header, connectPort) ->
    method = "ProxyReply._onChannelEnd #{@name} port:#{connectPort}"
    @logger.debug "#{method}"
    return q.promise (resolve, reject) =>
      try
        @connections[header.connectPort]?.socket?.end()
        resolve [{}] # Its just an ACK
      catch err
        @logger.error "#{method} catch error: #{err.stack}"
        reject err


  # Returns the dynRequest channel that must be used for this connection.
  #
  _getCurrentDynRequest: (socket) ->
    console.log "JJJ2 ------------------------------------"
    return q.promise (resolve, reject) =>
      console.log "JJJ2b ------------------------------------ #{socket.localPort}"
      # dynRequestPromise ensures that dynRequest is ready for use
      conn = @connectionsBySocket[socket.localPort]
      console.log "JJJ2c ------------------------------------"
      if not conn?
        console.log "JJJ2d ------------------------------------"
        reject new Error "Connection not found"
      console.log "JJJ2e ------------------------------------"
      resolve conn.dynRequest


  _createMessageHeader: (type, connectPort) ->
    return {
      type: type
      fromInstance: @iid
      connectPort: connectPort
    }


module.exports = ProxyReply

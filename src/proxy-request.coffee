net = require 'net'
q = require 'q'
ipUtils = require './ip-utils'


# 'Proxyfication' using LB connector (request side)
#
# ProxyRequest is a (request side) 'fake' of a legacy request-reply protocol
# implemented under tcp-protocol.
#
class ProxyRequest


  # Constructor
  # Parameters:
  # @owner: proxytcp container (permits issue events)
  # @iid: owner instance iid
  # @role: owner instance role
  # @channel: request channel to be proxified
  # @bindPorts: legacy tcp ports. Right now, is an array with a single port
  #
  constructor: (@owner, @role, @iid, @channel, @bindPorts) ->
    method = 'ProxyRequest.constructor'
    if (not Array.isArray(@bindPorts)) or (@bindPorts.length > 1)
      throw new Error "#{method}. Last parameter should be an array with a \
      single port"
    @bindIp = ipUtils.getIpFromPool() # selects a local IP (127.1.x.x)
    @name = "#{@role}/#{@iid}/#{@channel.name}/#{@bindIp}:#{@bindPorts}"
    @bindPort = @bindPorts[0]
    @logger.info "#{method} #{@name}"

    @tcpServer = null

    # Current TCP-connections table.
    # For each connection, saves:
    # - socket
    # - dynReply: dynamic channel used to receive data.
    # - dynRequest: dynamic channel used to send data.
    # - dynRequestPromise: promise solved when dynRequestChannel is created
    # dynRequest and dynReply are used to exchange tcp data (equivalent to a
    # dynamic duplex channel).
    @connections = {}


  # Returns a promise, solved when TCPServer is listening.
  #
  init: () ->
    method = "ProxyRequest.init #{@name}"
    @logger.info "#{method}"
    return q.promise (resolve, reject) =>
      binded = false
      @tcpServer = net.createServer().listen(@bindPort, @bindIp)

      @tcpServer.on 'listening', () =>
        @logger.info "#{method} tcpserver onListen (#{@bindIp}:#{@bindPort})"
        binded = true
        @owner.emit 'change', {
          channel: @channel.name,
          listening: true,
          ip: @bindIp,
          port: @bindPort
        }
        resolve()

      @tcpServer.on 'error', (err) =>
        @logger.error "#{method} tcpserver onError #{err.stack}"
        if not binded
          reject err
        else
          connection.socket.end() for key, connection of @connections
          @tcpServer.close()

      @tcpServer.on 'close', () =>
        @logger.info "#{method} tcpserver onClose"
        @tcpServer = null
        @owner.emit 'change', {
          channel: @channel.name,
          listening: false,
          ip: @bindIp,
          port: @bindPort
        }

      @tcpServer.on 'connection', (socket) =>
        @logger.info "#{method} tcpserver onConnection"
        @_processConnection socket


  # Returns a promise, solved when TCPServer and connections are closed
  # (promise is an interface requirement)
  # Informs legacy element about it.
  #
  terminate: () ->
    method = "ProxyRequest.terminate #{@name}"
    @logger.info "#{method}"
    connection.socket.end() for key, connection of @connections
    if @tcpServer? then @tcpServer.close()
    return q()


  # A new tcp-connection has been established.
  #
  _processConnection: (socket) =>
    method = "ProxyRequest._processConnection #{@name}"
    connectPort = socket.remotePort
    @logger.debug "#{method} port:#{connectPort}"

    # Create a dynRequest and dynReply for this connection
    dynReply = @channel.runtimeAgent.createChannel()
    dynReply.handleRequest = (request) =>
      header = @parser.decode(request[0])
      if header.type is 'data'
        @_onChannelData(header, request[1], connectPort)
      else if header.type is 'disconnected'
        @_onChannelEnd(header, connectPort)
      else
        err = new Error("Unexpected request type=#{header.type}")
        @logger.error "#{method} err:#{err.message}"
        q(err)
    dynRequestPromise = @_sendConnect(connectPort, dynReply)
    @connections[connectPort] =
      socket: socket
      dynReply: dynReply
      dynRequest: null # fill pending (dynRequestPromise)
      dynRequestPromise: dynRequestPromise

    # Tcp events for this connection
    socket.on 'data', (data) => @_onTcpData(data, connectPort)
    socket.on 'end', () => @_onTcpEnd(connectPort)
    socket.on 'error', (err) =>
      @logger.error "#{method} event:onError #{err.stack}"
      socket.end()
    socket.on 'timeout', () =>
      @logger.error "#{method} event:onTimeout"
      socket.end()
    socket.on 'close', () =>
      @logger.debug "#{method} event:onClose"


  # Tcp-connection receives new data.
  # Data must be sended through dynamic request channel.
  #
  _onTcpData: (data, connectPort) =>
    method = "ProxyRequest._onTcpData #{@name} port:#{connectPort}"
    @logger.debug "#{method}"
    if not @connections[connectPort]?
      @logger.error "#{method} connection not found"
    else
      @_getCurrentDynRequest(connectPort)
      .then (dynRequest) =>
        dynRequest.sendRequest [
          @parser.encode(@_createMessageHeader('data', connectPort)),
          data
        ]
      .then (reply) =>
        # It's just an ACK response
        status = reply[0][0]
        if status.status isnt 'OK'
          @logger.error "#{method} status: #{status.status}"
          @connections[connectPort]?.socket?.end()
      .fail (err) =>
        @logger.error "#{method} err: #{err.stack}"
        @connections[connectPort]?.socket?.end()


  # Dynamic channel receives new data.
  # Data must be sended through tcp-connection.
  #
  _onChannelData: (header, data, connectPort) ->
    method = "ProxyRequest._onChannelData #{@name} port:#{connectPort}"
    @logger.debug "#{method}"
    return q.promise (resolve, reject) =>
      try
        @connections[connectPort].socket.write(data)
        resolve ['ACK'] # Its just an ACK
      catch err
        @logger.error "#{method} catch error: #{err.stack}"
        reject err


  # Tcp-connection receives a disconnect.
  # Disconnect must be sended through dynamic request channel.
  #
  _onTcpEnd: (connectPort) =>
    method = "ProxyRequest._onTcpEnd #{@name} port:#{connectPort}"
    @logger.debug "#{method}"
    if @connections[connectPort]?
      @_getCurrentDynRequest(connectPort)
      .then (dynRequest) =>
        dynRequest.sendRequest [
          @parser.encode @_createMessageHeader('disconnected', connectPort)
        ]
      .then (reply) =>
        # It's just an ACK response
        status = reply[0][0]
        if status.status isnt 'OK'
          @logger.error "#{method} status: #{status.status}"
      .fail (err) =>
        @logger.error "#{method} #{err.stack}"
      .done () =>
        delete @connections[connectPort]


  # Dynamic channel receives a disconnect.
  # Tcp-connection must be disconnected too.
  #
  _onChannelEnd: (header, connectPort) ->
    method = "ProxyRequest._onChannelEnd #{@name} port:#{connectPort}"
    @logger.debug "#{method}"
    return q.promise (resolve, reject) =>
      try
        @connections[header.connectPort]?.socket?.end()
        resolve ['ACK'] # Its just an ACK
      catch err
        @logger.error "#{method} catch error: #{err.stack}"
        reject err


  # Sends dynReply to its proxy-pair.
  # Returns a promise, solved when a dynRequest is received from its proxy-pair
  #
  _sendConnect: (connectPort, dynReply) ->
    method = "ProxyRequest._sendConnect #{@name} port:#{connectPort}"
    return q.promise (resolve, reject) =>
      @logger.debug "#{method}"
      header = @parser.encode @_createMessageHeader('connect', connectPort)
      @channel.sendRequest [header], [dynReply]
      .then (reply) =>
        status = reply[0][0]
        if status.status is 'OK'
          if reply.length > 1 and reply[1]?.length > 0
            @logger.debug "#{method} resolved"
            dynRequest = reply[1][0]
            @connections[connectPort].dynRequest = dynRequest
            resolve()
          else
            err = new Error "DynRequest not returned"
            @logger.error "#{method} #{err.stack}"
            reject err
        else
          @logger.error "#{method} status=#{status.status}"
          reject err
      .fail (err) =>
        @logger.error "#{method} #{err.stack}"
        reject err


  # Returns the dynRequest channel that must be used for this connection.
  #
  _getCurrentDynRequest: (connectPort) ->
    return q.promise (resolve, reject) =>
      # dynRequestPromise ensures that dynRequest is ready for use
      @connections[connectPort].dynRequestPromise
      .then () => resolve @connections[connectPort].dynRequest
      .fail (err) -> reject err


  _createMessageHeader: (type, connectPort) ->
    return {
      type: type
      fromInstance: @iid
      connectPort: connectPort
    }


module.exports = ProxyRequest


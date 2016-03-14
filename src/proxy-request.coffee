net = require 'net'
q = require 'q'
_ = require 'lodash'
slaputils = require 'slaputils'
ipUtils = require './ip-utils'


# 'Proxyfication' using LB connector (request side)
#
# ProxyRequest is a (request side) 'fake' of a legacy request-reply protocol
# implemented under tcp-protocol.
#
class ProxyRequest


  # Constructor
  # - owner: ProxyTcp object that contains ProxyRequest (and other proxys)
  # - role and iid of instance
  # - channel: request channel used in "proxyfication"
  # - config: port
  #
  constructor: (@owner, @role, @iid, @channel, @config) ->
    @bindPort = @config.port
    @bindIp = ipUtils.getIpFromPool() # selects a local IP (127.1.x.x)

    method = 'ProxyRequest.constructor'
    @name = "#{@role}/#{@iid}/#{@channel.name}/#{@bindIp}:#{@bindPort}"
    @logger.info "#{method} #{@name}"

    @tcpServer = null

    # Current TCP-connections table.
    # For each connection, saves:
    # - socket
    # - dynRequest: dynamic channel used to send requests.
    # - dynRequestPromise: promise solved when dynamic channel
    #   is created
    @connections = {}


  # Returns a promise, solved when TCPServer is listening and legacy element
  # is informed about its configuration.
  #
  init: () ->
    method = "ProxyRequest.init #{@name}"
    @logger.info "#{method}"
    return q.promise (resolve, reject) =>
      binded = false
      @tcpServer = net.createServer().listen(@bindPort, @bindIp)

      @tcpServer.on 'listening', () =>
        @logger.info "#{method} tcpserver event onListen (#{@bindIp}:#{@bindPort})"
        binded = true
        @owner.legacy 'request', {
          listening: true,
          channel: @channel.name,
          bindIp: @bindIp,
          bindPort: @bindPort
        }
        .then () -> resolve()
        .fail (err) -> reject err

      @tcpServer.on 'error', (err) =>
        @logger.error "#{method} tcpserver event onError #{err.stack}"
        if not binded
          reject err
        else
          connection.socket.end() for key, connection of @connections
          @tcpServer.close()

      @tcpServer.on 'close', () =>
        @logger.info "#{method} tcpserver event onClose"
        @tcpServer = null
        @owner.legacy 'request', {
          listening: false,
          channel: @channel.name,
          bindIp: @bindIp,
          bindPort: @bindPort
        }
        .fail (err) => @logger.error "#{method} onClose err=#{err.message}"

      @tcpServer.on 'connection', (socket) =>
        @logger.info "#{method} tcpserver event onConnection"
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
    @connections[connectPort] =
      socket: socket
      dynRequest: null
      dynRequestPromise: @_getDynRequest(connectPort)
    socket.on 'data', (data) =>
      @_onData data, connectPort
    socket.on 'end', () =>
      @logger.debug "#{method} #{@name} port:#{connectPort} event:onEnd"
      @_closeConnection(connectPort)
    socket.on 'error', (err) =>
      @logger.error "#{method} #{@name} port:#{connectPort} event:onError \
                     #{err.stack}"
      socket.end()
    socket.on 'timeout', () =>
      @logger.error "#{method} #{@name} port:#{connectPort} event:onTimeout"
      socket.end()
    socket.on 'close', () =>
      @logger.debug "#{method} #{@name} port:#{connectPort} event:onClose"


  # Tcp-connection receives new (request) data.
  # Data must be sended through dynamic request channel, wait a reply, and return it
  # through tcp-connection.
  #
  _onData: (data, connectPort) =>
    method = "ProxyRequest._onData #{@name}"
    @logger.debug "#{method} #{connectPort}"
    if not @tcpServer
      @logger.error "#{method} #{connectPort} tcpServer is null"
    else if not @connections[connectPort]?
      @logger.error "#{method} #{connectPort} connection not found"
    else
      socket = @connections[connectPort].socket
      @_getCurrentChannel(connectPort)
      .then (channel) =>
        channel.sendRequest [
          @parser.encode(@_createMessageHeader('data', connectPort)),
          data
        ]
      .then (reply) =>
        status = @parser.decode(reply[0][0])
        if status.result is 'ok'
          socket.write reply[0][1]
        else
          @logger.error "#{method} #{connectPort} status: #{status.result}"
          socket.end()
      .fail (err) =>
        @logger.error "#{method} #{connectPort} err: #{err.stack}"
        socket.end()


  # Close connection (tcp connection and proxy connection)
  #
  _closeConnection: (connectPort) =>
    method = "ProxyRequest._closeConnection #{@name}"
    @logger.debug "#{method} #{connectPort}"
    if @connections[connectPort]?
      @_getCurrentChannel(connectPort)
      .then (channel) =>
        channel.sendRequest [
          @parser.encode @_createMessageHeader('disconnect', connectPort)
        ]
      .fail (err) => @logger.error "#{method} #{connectPort} #{err.stack}"
      .done () => delete @connections[connectPort]
    else
      @logger.error "#{method} #{connectPort} connection not found"


  # Returns a promise, solved when a dynamic request channel is received
  #
  _getDynRequest: (connectPort) ->
    method = "ProxyRequest._getDynRequest #{@name}"
    return q.promise (resolve, reject) =>
      @logger.debug "#{method} #{connectPort}"
      @channel.sendRequest [
        @parser.encode @_createMessageHeader('connect', connectPort)
      ]
      .then (reply) =>
        status = @parser.decode(reply[0][0])
        if status.result is 'ok'
          if reply.length > 1 and reply[1]?.length > 0
            @logger.debug "#{method} #{connectPort} resolved"
            dynRequest = reply[1][0]
            @connections[connectPort].dynRequest = dynRequest
            resolve()
          else
            err = new Error "DynRequest not returned"
            @logger.error "#{method} #{connectPort} #{err.stack}"
            reject err
        else
          @logger.error "#{method} #{connectPort} status=#{status.result}"
          reject err
      .fail (err) =>
        @logger.error "#{method} #{connectPort} #{err.stack}"
        reject err


  # Returns the channel that must be used for this connection.
  #
  _getCurrentChannel: (connectPort) ->
    return q.promise (resolve, reject) =>
      # dynRequestPromise ensures that dynChannel is ready for use
      @connections[connectPort].dynRequestPromise
      .then () =>
        resolve @connections[connectPort].dynRequest
      .fail (err) ->
        reject err


  _createMessageHeader: (type, connectPort) ->
    return {
      type: type
      fromInstance: @iid
      connectPort: connectPort
    }


module.exports = ProxyRequest
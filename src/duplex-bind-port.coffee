net = require 'net'
EventEmitter = require('events').EventEmitter
q = require 'q'
ipUtils = require './ip-utils'


class DuplexBindPort extends EventEmitter


  constructor: (@iid, @remoteIid, @port) ->
    method = 'DuplexBindPort.constructor'
    @ip = ipUtils.getIpFromIid @remoteIid
    @name = "#{@iid}/#{@remoteIid}:#{@ip}:#{@port}"
    @logger.info "#{method} #{@name}"
    @tcpServer = null
    @connections = {}


  init: () ->
    method = 'DuplexBindPort.init'
    @logger.info "#{method} #{@name}"
    return q.promise (resolve, reject) =>
      binded = false
      @tcpServer = net.createServer @_onConnection
      @tcpServer.on 'error', (err) =>
        @logger.error "#{method} #{@name} #{err.message}"
        if not binded then reject err
      @tcpServer.listen @port, @ip, () =>
        @logger.info "#{method} #{@name} listening"
        binded = true
        resolve()


  terminate: () ->
    method = 'DuplexBindPort.terminate'
    @logger.info "#{method} #{@name}"
    return q.promise (resolve, reject) =>
      if @tcpServer?
        @tcpServer.close()
        @tcpServer = null
      resolve()


  send: (message, connectPort) ->
    method = 'DuplexBindPort.send'
    buf = new Buffer message
    @logger.debug "#{method} #{@name}"
    if @connections[connectPort]?
      @connections[connectPort].write buf
    else
      @logger.error "#{method} #{@name} connection #{connectPort} not found"


  deleteConnection: (connectPort) ->
    method = 'DuplexBindPort.deleteConnection'
    @logger.debug "#{method} #{@name} #{connectPort}"
    if @connections[connectPort]?
      @connections[connectPort].end()
      delete @connections[connectPort]


  _onConnection: (socket) =>
    method = 'DuplexBindPort._onConnection'
    connectPort = socket.remotePort
    @logger.debug "#{method} #{@name} #{connectPort}"
    @connections[connectPort] = socket
    @emit 'bindOnConnect', {
      remoteIid: @remoteIid,
      bindPort: @port,
      connectPort: connectPort,
      data: null
    }
    socket.on 'data', (data) =>  @_onData data, connectPort
    socket.on 'end', () =>  @_onDisconnect connectPort
    socket.on 'error', (err) =>  @_onError err, connectPort
    socket.on 'close', () =>  @_onClose connectPort
    socket.on 'timeout', () =>   @_onTimeout connectPort


  _onData: (data, connectPort) =>
    method = 'DuplexBindPort._onData'
    @logger.debug "#{method} #{@name} #{connectPort}"
    @emit 'bindOnData', {
      remoteIid: @remoteIid,
      bindPort: @port,
      connectPort: connectPort,
      data: data
    }


  _onDisconnect: (connectPort) =>
    method = 'DuplexBindPort._onDisconnect'
    @logger.debug "#{method} #{@name} #{connectPort}"
    @deleteConnection connectPort
    @emit 'bindOnDisconnect', {
      remoteIid: @remoteIid,
      bindPort: @port,
      connectPort: connectPort,
      data: null
    }


  _onError: (err, connectPort) =>
    # should we do something?
    method = 'DuplexBindPort._onError'
    @logger.error "#{method} #{@name} #{connectPort} #{err.message}"


  _onClose: (connectPort) =>
    # should we do something?
    method = 'DuplexBindPort._onClose'
    @logger.debug "#{method} #{@name} #{connectPort}"


  _onTimeout: (connectPort) =>
    # should we do something?
    method = 'DuplexBindPort._onTimeout'
    @logger.error "#{method} #{@name} #{connectPort} #{err.message}"


module.exports = DuplexBindPort
net = require 'net'
EventEmitter = require('events').EventEmitter
q = require 'q'


class DuplexConnectPort extends EventEmitter


  constructor: (@iid, @remoteIid, @bindIp, @bindPort, @connectPort) ->
    method = 'DuplexConnectPort.constructor'
    @name = "#{@iid}/#{@remoteIid}:#{@bindIp}:#{@bindPort}:#{@connectPort}"
    @logger.info "#{method} #{@name}"
    @tcpClient = null


  init: () ->
    method = 'DuplexConnectPort.init'
    @logger.info "#{method} #{@name}"
    @_connect()


  terminate: () ->
    method = 'DuplexConnectPort.terminate'
    @logger.info "#{method} #{@name}"
    return q.promise (resolve, reject) =>
      if @tcpClient?
        @tcpClient.removeListener 'end', @_onEnd
        @tcpClient.end()
        @tcpClient = null
      resolve()


  send: (data) ->
    method = 'DuplexConnectPort.terminate'
    @logger.debug "#{method} #{@name}"
    if @tcpClient? then @tcpClient.write data
    else @logger.error "#{method} #{@name} error: tcpclient is null"


  _connect: () ->
    method = 'DuplexConnectPort._connect'
    @logger.info "#{method} #{@name}"
    return q.promise (resolve, reject) =>
      connected = false
      options = {host: @bindIp, port: @bindPort}
      @tcpClient = net.connect options, () =>
        @logger.info "#{method} #{@name} connected #{JSON.stringify options}"
        connected = true
        resolve()
      @tcpClient.on 'data', @_onData
      @tcpClient.on 'end', @_onEnd
      @tcpClient.on 'error', (err) =>
        @logger.error "#{method} #{@name} onError: #{err.message}"
        if connected is false then reject err
        # else... should we reconnect?
      @tcpClient.on 'close', () =>
        @logger.info "#{method} #{@name} onClose"
        if connected is false then  reject new Error 'onClose event'
      @tcpClient.on 'timeout', () =>
        @logger.info "#{method} #{@name} onTimeout"
        if connected is false then  reject new Error 'onTimeout event'


  _onData: (data) => # We need "flat arrow"
    method = 'DuplexConnectPort._onData'
    @logger.debug "#{method} #{@name}"
    @emit 'connectOnData', {
      remoteIid: @remoteIid,
      bindPort: @bindPort,
      connectPort: @connectPort,
      data: data
    }


  _onEnd: (remotePort) =>
    method = 'DuplexConnectPort._onEnd'
    @logger.debug "#{method} #{@name}"
    @emit 'connectOnDisconnect', {
      remoteIid: @remoteIid,
      bindPort: @bindPort,
      connectPort: @connectPort,
      data: null
    }


module.exports = DuplexConnectPort

net = require 'net'
EventEmitter = require('events').EventEmitter
q = require 'q'


class DuplexConnectPort extends EventEmitter


  constructor: (@iid, @remoteIid, @bindIp, @bindPort, @connectPort) ->
    method = 'DuplexConnectPort.constructor'
    @name = "#{@iid}/#{@remoteIid}:#{@bindIp}:#{@bindPort}:#{@connectPort}"
    @logger.info "#{method} #{@name}"
    @_tcpClient = null
    @_creatingPromise = null


  init: () ->
    method = 'DuplexConnectPort.init'
    @logger.info "#{method} #{@name}"
    @_creatingPromise = @_connect()
    return @_creatingPromise


  terminate: () ->
    method = 'DuplexConnectPort.terminate'
    @logger.info "#{method} #{@name}"
    return q.promise (resolve, reject) =>
      if @_tcpClient?
        @_creatingPromise
        .then () =>
          @_tcpClient.removeListener 'end', @_onEnd
          @_tcpClient.end()
          @_tcpClient = null
      resolve()


  send: (data) ->
    method = 'DuplexConnectPort.send'
    @logger.debug "#{method} #{@name}"
    @_creatingPromise.then () =>
      if @_tcpClient? then @_tcpClient.write data
      else @logger.error "#{method} #{@name} error: tcpclient is null"


  _connect: () ->
    method = 'DuplexConnectPort._connect'
    @logger.info "#{method} #{@name}"
    return q.promise (resolve, reject) =>
      connected = false
      options = { host: @bindIp, port: @bindPort }
      @_tcpClient = net.connect options, () =>
        @logger.info "#{method} #{@name} connected #{JSON.stringify options}"
        connected = true
        resolve()
      @_tcpClient.on 'data', @_onData
      @_tcpClient.on 'end', @_onEnd
      @_tcpClient.on 'error', (err) =>
        @logger.error "#{method} #{@name} onError: #{err.message}"
        if connected is false then reject err
        # else... should we reconnect?
      @_tcpClient.on 'close', () =>
        @logger.info "#{method} #{@name} onClose"
        if connected is false then  reject new Error 'onClose event'
      @_tcpClient.on 'timeout', () =>
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

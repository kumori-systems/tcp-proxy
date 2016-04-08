q = require 'q'


class ProxyReply


  constructor: (@owner, @role, @iid, @channel) ->
    method = 'ProxyReply.constructor'
    @logger.info "#{method} role=#{@role},iid=#{@iid},\
                  channel=#{@channel.name}"


  init: () ->
    method = 'ProxyReply.init'
    @logger.info "#{method}"
    return q.promise (resolve, reject) -> resolve()


  terminate: () ->
    method = 'ProxyReply.terminate'
    @logger.info "#{method}"
    return q.promise (resolve, reject) -> resolve()


module.exports = ProxyReply


###

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

          if @connections[iid]?[connectPort]?
            throw new Error "Port #{iid}/#{connectPort} already exists"

          onConnectError = (err) -> reject err
          socket = net.connect @connectOptions
          socket.once 'error', onConnectError
          socket.once 'connect', () =>
            method = "#{method} port:#{connectPort}"
            socket.removeListener 'error', onConnectError

            dynRequest = request[1]
            dynReply = @channel.runtimeAgent.createChannel()

            if not @connections[iid]? then @connections[iid] = {}
            @connections[iid][connectPort] = {
              socket: socket
              dynRequest: dynRequest
              dynReply: dynReply
            }

            # Tcp events
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

            # Channel events
            dynReply.handleRequest = (request) =>
              header = @parser.decode(request[0])
              if header.type is 'data'
                @_onChannelData(header, request[1])
              else if header.type is 'disconnected'
                @_onChannelEnd(header)
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
  _onTcpData: (data, connectPort) =>
    method = "ProxyReply._onTcpData #{@name}"
    @logger.debug "#{method} port:#{connectPort}"
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
        status = @parser.decode(reply[0][0])
        if status.result isnt 'ok'
          @logger.error "#{method} status: #{status.result}"
          @connections[connectPort]?.socket?.end()
      .fail (err) =>
        @logger.error "#{method} err: #{err.stack}"
        @connections[connectPort]?.socket?.end()


  # Dynamic channel receives new data.
  # Data must be sended through tcp-connection.
  #
  _onChannelData: (header, data) ->
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


  # Process a "disconnect-request".
  #
  _handleDisconnected: (header) ->
    method = "ProxyReply._handleDisconnected #{@name}"
    @logger.debug "#{method}"
    try
      iid = request.fromInstance
      connectPort = request.connectPort
      tcpClient = @connections[iid]?.connections[connectPort]
      if tcpClient?
        tcpClient.end()
        delete instance.connections[connectPort]
        # To improve: remove dynamic channels if an instance doesnt have
        # connections for long time
      else
        @logger.warn "#{method} connections doesnt contains iid=#{iid}, \
                       connectPort=#{connectPort}"
    catch err
      @logger.error "#{method} catch error: #{err.stack}"



module.exports = ProxyReply

###
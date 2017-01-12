q = require 'q'
_ = require 'lodash'
ipUtils = require './ip-utils'
DuplexConnectPort   = require './duplex-connect-port'


# Proxy for duplex 'connect' channels
#
class ProxyDuplexConnect


  # Parameters:
  # @owner: proxytcp container (permits issue events)
  # @iid: owner instance iid
  # @role: owner instance role
  # @channel: duplex channel
  #
  constructor: (@owner, @role, @iid, @channel) ->
    @name = "#{@role}/#{@iid}/#{@channel.name}"
    method = "ProxyDuplexConnect.constructor #{@name}"
    @logger.info method
    @bindIp = ipUtils.getIpFromIid(@iid)
    @connectPorts = {}
    @currentMembership = {}


  init: () ->
    method = "ProxyDuplexConnect.init #{@name}"
    @logger.info method
    return q.promise (resolve, reject) =>
      @channel.on 'changeMembership', @_onChangeMembership
      @channel.on 'message', @_onMessage
      @channel.getMembership()
      .then (members) =>
        resolve()
        process.nextTick () => @_onChangeMembership(members)
      .fail (err) ->
        reject err


  terminate: () ->
    method = "ProxyDuplexConnect.terminate #{@name}"
    @logger.info method
    return q.promise (resolve, reject) =>
      promises = []
      promises.push port.terminate() for key, port of @connectPorts
      q.all(promises).then () -> resolve()


  _onChangeMembership: (newMembership) =>
    method = "ProxyDuplexConnect._onChangeMembership #{@name}"
    newIds = @_getIdFromMembership newMembership
    @logger.info "#{method} newMembership=#{newIds}"
    @currentMembership = _.cloneDeep newMembership


  _onMessage: (segments) =>
    method = "ProxyDuplexConnect._onMessage #{@name}"
    msg = @parser.decode segments[0]
    id = "#{msg.fromInstance}:#{msg.bindPort}:#{msg.connectPort}"
    @logger.debug "#{method} type=#{msg.type} id=#{id}"
    switch msg.type
      when 'bindOnConnect'
        @_createConnectPort(id, msg)
        .fail (err) =>
          @logger.error "#{method} #{msg.type} error = #{err.message}"
          message = @_createMessageSegment('connectOnDisconnect', {
            remoteMember: msg.fromInstance
            bindPort: msg.bindPort
            connectPort: msg.connectPort
          })
          @_send message, null, msg.fromInstance
      when 'bindOnData'
        data = segments[1]
        connectPort = @connectPorts[id]
        if connectPort?
          @logger.debug "#{method} #{msg.type} send msg"
          connectPort.send new Buffer data
        else @logger.error "#{method} #{msg.type} error = connectPort \
                            doesnt exists}"
      when 'bindOnDisconnect'
        @_deleteConnectPort id
      else @logger.warn "#{method} Unexpected msg type #{msg.type}"


  _onConnectData: (event) =>
    message = @_createMessageSegment('connectOnData', event)
    @_send message, event.data, event.remoteIid


  _onConnectDisconnect: (event) =>
    id = "#{@event.remoteIid}:#{@bindIp}:\
          #{@event.bindPort}:#{@event.connectPort}"
    @_deleteConnectPort id
    message = @_createMessageSegment('connectOnDisconnect', event)
    @_send message, null, event.remoteIid


  _createConnectPort: (id, msg) ->
    return q.promise (resolve, reject) =>
      if @connectPorts[id]? then resolve @connectPorts[id]
      else
        port = new DuplexConnectPort(@iid, msg.fromInstance, @bindIp,\
                                     msg.bindPort, msg.connectPort)
        @connectPorts[id] = port
        port.init()
        .then () =>
          port.on 'connectOnData', @_onConnectData
          port.on 'connectOnDisconnect', @_onConnectDisconnect
          @connectPorts[id] = port
          resolve port
        .fail (err) =>
          delete @connectPorts[id]
          reject err


  _deleteConnectPort: (id) ->
    if @connectPorts[id]?
      @connectPorts[id].terminate()
      delete @connectPorts[id]


  _createMessageSegment: (type, event) ->
    return {
      type: type
      fromInstance: @iid
      toInstance: event.remoteIid
      bindPort: event.bindPort
      connectPort: event.connectPort
    }


  _send: (message, data, remoteIid) ->
    target = @currentMembership.find (m) -> return (m.iid is remoteIid)
    if target?
      aux = [@parser.encode(message)]
      if data? then aux.push data
      @channel.send aux, target
    else
      @logger.error "ProxyDuplexConnect._send #{@name} \
                     remoteMember not found for #{remoteIid}"


  _getIdFromMembership: (membership) ->
    list = []
    list.push member.iid for member in membership
    return list


module.exports = ProxyDuplexConnect
q = require 'q'
_ = require 'lodash'
DuplexBindPort = require './duplex-bind-port'
slaputils = require 'slaputils'
Semaphore = slaputils.Semaphore


# Proxy for duplex 'bind' channels
#
class ProxyDuplexBind


  # Constructor
  # Parameters:
  # @owner: proxytcp container (permits issue events)
  # @iid: owner instance iid
  # @role: owner instance role
  # @channel: duplex channel
  # @port: legacy bind tcp port
  #
  constructor: (@owner, @role, @iid, @channel, @port) ->
    @name = "#{@role}/#{@iid}/#{@channel.name}/#{@port}"
    method = "ProxyDuplexBind.constructor #{@name}"
    @logger.info method
    @bindPorts = {}
    @currentMembership = []
    @changeMemberSemaphore = new Semaphore()


  init: () ->
    method = "ProxyDuplexBind.init #{@name}"
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
    method = "ProxyDuplexBind.terminate #{@name}"
    @logger.info method
    return q.promise (resolve, reject) =>
      promises = []
      promises.push port.terminate() for iid, port of @bindPorts
      q.all promises
      .then () -> resolve()
      .fail (err) -> reject err


  _onChangeMembership: (newMembership) =>
    method = "ProxyDuplexBind._onChangeMembership #{@name}"
    newIds = @_getIdFromMembership newMembership
    @logger.info "#{method} newMembership=#{newIds}"
    @changeMemberSemaphore.enter method, @, () ->
      currentIds = @_getIdFromMembership @currentMembership
      createMembers = _.difference newIds, currentIds
      deleteMembers = _.difference currentIds, newIds
      @currentMembership = _.cloneDeep newMembership
      result = q()
      createMembers.forEach (iid) =>
        result = result.then () => @_createMember(iid)
      deleteMembers.forEach (iid) =>
        result = result.then () => @_deleteMember(iid)
      result.then () =>
        params =
          channel: @channel.name
          members: []
        for iid, bindPort of @bindPorts
          params.members.push {iid:iid, port:bindPort.port, ip:bindPort.ip}
        @owner.emit 'change', params
      .fail (err) =>
        @logger.error "#{method} #{err.stack}"


  _createMember: (iid) ->
    method = "ProxyDuplexBind._createMember #{@name} iid=#{iid}"
    @logger.info method
    return q.promise (resolve, reject) =>
      bindPort = new DuplexBindPort(@iid, iid, @port)
      @bindPorts[iid] = bindPort
      @bindPorts[iid].init()
      .then (res, err) =>
        if err?
          @logger.error "#{method} #{e.stack}"
          if @bindPorts[iid]?
            delete @bindPorts[iid]
        else
          bindPort.on 'bindOnConnect', @_bindOnConnect
          bindPort.on 'bindOnData', @_bindOnData
          bindPort.on 'bindOnDisconnect', @_bindOnDisconnect
        resolve()


  _deleteMember: (iid) ->
    method = "ProxyDuplexBind._deleteMember #{@name} iid=#{iid}"
    @logger.info method
    return q.promise (resolve, reject) =>
      @bindPorts[iid].terminate()
      .then (res, err) =>
        if err? then @logger.error "#{method} #{e.stack}"
        delete @bindPorts[iid]
        resolve()


  _onMessage: (segments) =>
    method = "ProxyDuplexBind._onMessage #{@name}"
    @logger.debug method
    message = @parser.decode segments[0]
    switch message.type
      when 'connectOnData'
        data = segments[1]
        @_connectOnData message, data
      when 'connectOnDisconnect'
        @_connectOnDisconnect message
      else @logger.warn "#{method} Unexpected message type #{message.type}"


  _bindOnConnect: (event) =>
    message = @_createMessageSegment('bindOnConnect', event)
    @_send message, null, event.remoteIid


  _bindOnData: (event) =>
    message = @_createMessageSegment('bindOnData', event)
    @_send message, event.data, event.remoteIid


  _bindOnDisconnect: (event) =>
    message = @_createMessageSegment('bindOnDisconnect', event)
    @_send message, null, event.remoteIid


  _connectOnData: (message, data) ->
    method = "ProxyDuplexBind._connectOnData #{@name}"
    @logger.debug method
    bindPort = @bindPorts[message.fromInstance]
    if bindPort?
      bindPort.send data, message.connectPort
    else
      @logger.error "#{method} bindport #{message.fromInstance} not found"


  _connectOnDisconnect: (message) ->
    method = "ProxyDuplexBind._connectOnDisconnect #{@name}"
    @logger.debug method
    bindPort = @bindPorts[message.fromInstance]
    if bindPort?
      bindPort.deleteConnection message.connectPort
    else
      @logger.error "#{method} bindport #{message.fromInstance} not found"


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
      @logger.error "ProxyDuplexBind._send #{@name} \
                     remoteMember not found for #{remoteIid}"


  _getIdFromMembership: (membership) ->
    list = []
    list.push member.iid for member in membership
    return list


module.exports = ProxyDuplexBind
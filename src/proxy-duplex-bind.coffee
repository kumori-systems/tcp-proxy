q = require 'q'
_ = require 'lodash'
DuplexBindPort = require './duplex-bind-port'
slaputils = require 'slaputils'
Semaphore = require './semaphore'


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
    @logger.info "#{method}"
    @bindPorts = {}
    @currentMembership = [] # List of IID
    @changeMemberSemaphore = new Semaphore()


  init: () ->
    method = 'ProxyDuplexBind.init'
    @logger.info "#{method} #{@name}"
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
    method = 'ProxyDuplexBind.terminate'
    @logger.info "#{method} #{@name}"
    return q.promise (resolve, reject) =>
      promises = []
      promises.push port.terminate() for iid, port of @bindPorts
      q.all promises
      .then () -> resolve()
      .fail (err) -> reject err


  _onChangeMembership: (newMembership) =>
    method = 'ProxyDuplexBind._onChangeMembership'
    @logger.info "#{method} #{@name} newMembership=#{newMembership}"
    @changeMemberSemaphore.enter method, @, () ->
      createMembers = _.difference newMembership, @currentMembership
      deleteMembers = _.difference @currentMembership, newMembership
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


  _createMember: (iid) ->
    method = 'ProxyDuplexBind._createMember'
    @logger.info "#{method} #{@name} iid=#{iid}"
    return q.promise (resolve, reject) =>
      if iid is @iid
        resolve()
      else if iid in @currentMembership
        @logger.warn "#{method} member=#{iid} already exists"
        resolve()
      else
        bindPort = new DuplexBindPort(@iid, iid, @port)
        @bindPorts[iid] = bindPort
        @bindPorts[iid].init()
        .then (res, err) =>
          if err?
            @logger.error "#{method} member=#{iid} #{e.stack}"
            if @bindPorts[iid]?
              delete @bindPorts[iid]
          else
            @currentMembership.push iid
            bindPort.on 'bindOnConnect', @_bindOnConnect
            bindPort.on 'bindOnData', @_bindOnData
            bindPort.on 'bindOnDisconnect', @_bindOnDisconnect
          resolve()


  _deleteMember: (iid) ->
    method = 'ProxyDuplexBind._deleteMember'
    @logger.info "#{method} #{@name} iid=#{iid}"
    return q.promise (resolve, reject) =>
      if iid not in @currentMembership
        @logger.warn "#{method} member=#{iid} not exists"
        resolve()
      else
        _.pull @currentMembership, iid
        @bindPorts[iid].terminate()
        .then (res, err) =>
          if err? then @logger.error "#{method} member=#{iid} #{e.stack}"
          delete @bindPorts[iid]
          resolve()


  _onMessage: (segments) =>
    method = 'ProxyDuplexBind._onMessage'
    @logger.debug "#{method} #{@name}"
    message = @parser.decode segments[0]
    switch message.type
      when 'connectOnData'
        data = segments[1]
        @_connectOnData message, data
      when 'connectOnDisconnect'
        @_connectOnDisconnect message
      else @logger.warn "#{method} #{@name} Unexpected message type \
                         #{message.type}"


  _bindOnConnect: (event) =>
    message = @_createMessageSegment('bindOnConnect', event)
    @channel.send [@parser.encode(message)], event.remoteIid


  _bindOnData: (event) =>
    message = @_createMessageSegment('bindOnData', event)
    @channel.send [@parser.encode(message), event.data], event.remoteIid


  _bindOnDisconnect: (event) =>
    message = @_createMessageSegment('bindOnDisconnect', event)
    @channel.send [@parser.encode(message)], event.remoteIid


  _connectOnData: (message, data) ->
    method = 'ProxyDuplexBind._connectOnData'
    @logger.debug "#{method} #{@name}"
    bindPort = @bindPorts[message.fromInstance]
    if bindPort?
      bindPort.send data, message.connectPort
    else
      @logger.error "#{method} #{@name} error = bindport \
                     #{message.fromInstance} not found"


  _connectOnDisconnect: (message) ->
    method = 'ProxyDuplexBind._connectOnDisconnect'
    @logger.debug "#{method} #{@name}"
    bindPort = @bindPorts[message.fromInstance]
    if bindPort?
      bindPort.deleteConnection message.connectPort
    else
      @logger.error "#{method} #{@name} error = bindport \
                     #{message.fromInstance} not found"


  _createMessageSegment: (type, event) ->
    return {
      type: type
      fromInstance: @iid
      toInstance: event.remoteIid
      bindPort: event.bindPort
      connectPort: event.connectPort
    }


module.exports = ProxyDuplexBind
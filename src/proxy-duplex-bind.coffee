q = require 'q'
_ = require 'lodash'
slaputils = require 'slaputils'
Semaphore = require './semaphore'


GETROLE_TIMEOUT = 10000


class ProxyDuplexBind


  constructor: (@owner, @role, @iid, @channel, @config) ->
    @name = "#{@role}/#{@iid}/#{@channel.name}"
    method = 'ProxyDuplexBind.constructor'
    @logger.info "#{method} #{@name}"
    @bindPorts = {}
    @currentMembership = [] # List of IID
    @changeMemberSemaphore = new Semaphore()
    @getRolePromises = {}


  init: () ->
    method = 'ProxyDuplexBind.init'
    @logger.info "#{method} #{@name}"
    return q.promise (resolve, reject) =>
      @channel.on 'changeMembership', @_onChangeMembership
      @channel.on 'message', @_onMessage
      @channel.getMembership()
      .then (members) => @_onChangeMembership(members)
      .then () -> resolve()
      .fail (err) -> reject err


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
        @owner.legacy 'duplex', params


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
        @_getRole(iid)
        .then (role) =>
          @logger.info "#{method} getRole = #{role}"
          if role is @role
            @currentMembership.push iid
            resolve() # do nothing
          else
            bindPort = new @config.DuplexBindPort(@iid, iid, @config.port)
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
        .fail (err) =>
          @logger.error "#{method} member=#{iid} #{err.message}"
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


  _getRole: (iid) ->
    method = 'ProxyDuplexBind._getRole'
    @logger.info "#{method} #{@name} iid=#{iid}"
    return q.promise (resolve, reject) =>
      message = {
        type: 'getrolerequest'
        id: slaputils.generateId()
        data: iid
        sender: @iid
      }

      # Solución temporal -- ver ticket 445
      # Reenvío la petición cada segundo, porque puede ocurrir que la instancia
      # destino no exista (y no tengo manera de saberlo). Esto puede ocurrir
      # en tanto que el evento onChangeMembership no está ligada a la
      # real de la instancia.
      idInterval = setInterval () =>
        @channel.send [@parser.encode message], iid
      , 1000

      idTimeout = setTimeout () =>
        if @getRolePromises[message.id]? then reject(new Error 'Timeout')
      , GETROLE_TIMEOUT

      @getRolePromises[message.id] =
        message: message
        resolve: resolve
        reject: reject
        idInterval: idInterval
        idTimeout: idTimeout
      @channel.send [@parser.encode message], iid


  _onMessage: (segments) =>
    method = 'ProxyDuplexBind._onMessage'
    @logger.debug "#{method} #{@name}"
    message = @parser.decode segments[0]
    switch message.type
      when 'getrolerequest'
        message.result = @role
        @channel.send [@parser.encode message], message.sender
      when 'getroleresponse'
        rolePromise = @getRolePromises[message.id]
        if rolePromise?
          clearTimeout rolePromise.idTimeout
          clearInterval rolePromise.idInterval
          if message.err? then rolePromise.reject message.err
          else rolePromise.resolve message.result
        else
          @logger.warn "#{method} #{@name} Unexpected getrole message \
                        #{message.type} - ¿timeout?"
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
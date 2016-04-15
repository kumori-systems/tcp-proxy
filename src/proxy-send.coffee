q = require 'q'


class ProxySend


  constructor: (@owner, @role, @iid, @channel) ->
    method = 'ProxySend.constructor'
    @logger.info "#{method} role=#{@role},iid=#{@iid},\
                  channel=#{@channel.name}"


  init: () ->
    method = 'ProxySend.init'
    @logger.info "#{method}"
    return q.promise (resolve, reject) ->
      resolve()


  terminate: () ->
    method = 'ProxySend.terminate'
    @logger.info "#{method}"
    return q.promise (resolve, reject) -> resolve()


module.exports = ProxySend
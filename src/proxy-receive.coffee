q = require 'q'


class ProxyReceive


  constructor: (@owner, @role, @iid, @channel, @config) ->
    method = 'ProxyReceive.constructor'
    @logger.info "#{method} role=#{@role},iid=#{@iid},channel=#{@channel.name}"


  init: () ->
    method = 'ProxyReceive.init'
    @logger.info "#{method}"
    return q.promise (resolve, reject) -> resolve()


  terminate: () ->
    method = 'ProxyReceive.terminate'
    @logger.info "#{method}"
    return q.promise (resolve, reject) -> resolve()


module.exports = ProxyReceive
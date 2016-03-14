q = require 'q'


class ProxyRequest


  constructor: (@owner, @role, @iid, @channel, @config) ->
    method = 'ProxyRequest.constructor'
    @logger.info "#{method} role=#{@role},iid=#{@iid},channel=#{@channel.name}"


  init: () ->
    method = 'ProxyRequest.init'
    @logger.info "#{method}"
    return q.promise (resolve, reject) -> resolve()


  terminate: () ->
    method = 'ProxyRequest.terminate'
    @logger.info "#{method}"
    return q.promise (resolve, reject) -> resolve()


module.exports = ProxyRequest


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
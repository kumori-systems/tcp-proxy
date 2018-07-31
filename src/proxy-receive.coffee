q = require 'q'
util = require './util'


class ProxyReceive


  constructor: (@owner, @role, @iid, @channel, @ports, @parser) ->
    method = 'ProxyReceive.constructor'
    @logger ?= util.getLogger()
    @logger.info "#{method} role=#{@role},iid=#{@iid},\
                  channel=#{@channel.name}"


  init: () ->
    method = 'ProxyReceive.init'
    @logger.info "#{method}"
    return q.promise (resolve, reject) -> resolve()


  terminate: () ->
    method = 'ProxyReceive.terminate'
    @logger.info "#{method}"
    return q.promise (resolve, reject) -> resolve()


module.exports = ProxyReceive
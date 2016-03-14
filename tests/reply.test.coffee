net = require 'net'
slaputils = require 'slaputils'
q = require 'q'
should = require 'should'
index = require('../src/index')
IpUtils = require '../src/ip-utils'
MockComponent = require('./mock/mock').MockComponent
manifestB = require './manifests/B.json'
ProxyReply = index.ProxyReply


describe.skip 'ProxyReply Tests', ->


  parser = new slaputils.JsonParser()
  MESSAGEREQUEST = {value: 'this is the request'}
  MESSAGEREPLY = {value: 'this is the reply'}
  logger = null
  mockComponentB = null

  proxyReply1 = null
  rep1 = null



  before (done) ->
    slaputils.setLoggerOwner 'ProxyReplyTest'
    logger = slaputils.getLogger 'ProxyReplyTest'
    logger.configure {
      'console-log' : false
      'console-level' : 'debug'
      'colorize': true
      'file-log' : true
      'file-level': 'debug'
      'file-filename' : 'slap.log'
      'http-log' : false
      'vm' : ''
      'auto-method': false
    }
    IpUtils.__unitTestUtil__ 0
    mockComponentB = new MockComponent 'B_2', 'B', manifestB.configuration, \
                                       manifestB.provided, manifestB.required
    mockComponentB.run()
    .then () ->
      proxyReply1 = mockComponentB.proxyTcp.channels['rep1'].proxy
      rep1 = mockComponentB.proxyTcp.channels['rep1'].channel
      done()
    .fail (err) -> done err


  after (done) ->
    done()
    #mockComponentB.shutdown()
    #.then () -> done()
    #.fail (err) -> done err


  it 'Sends a request and receive reply', (done) ->
    tcpServer = net.createServer (socket) ->
      socket.on 'data', (data) ->
        logger.info "TEST socket.on data #{data}"
        parser.decode(data).should.be.eql MESSAGEREQUEST
        socket.write(parser.encode(MESSAGEREPLY))
      socket.on 'end', () ->
        logger.info "TEST socket.on end"
      socket.on 'error', (err) ->
        logger.error "TEST socket.on error = #{err.message}"
      socket.on 'close', () ->
        logger.warn "TEST socket.on close"
      socket.on 'timeout', () ->
        logger.warn "TEST ocket.on timeout"

    tcpServer.listen proxyReply1.bindPort, proxyReply1.bindIp, () ->
      logger.info "TEST send request connect"
      dynChannel = null
      requestConnect = [
        parser.encode({type: 'connect', fromInstance: 'A_1', connectPort: 5001})
      ]
      rep1.deliverMessage(requestConnect)
      .then (reply) ->
        dynChannel = reply[1][0]
        logger.info "TEST send request data (dynchan=#{dynChannel.name})"
        requestData = [
          parser.encode({type: 'data', fromInstance: 'A_1', connectPort: 5001}),
          parser.encode(MESSAGEREQUEST)
        ]
        dynChannel.deliverMessage(requestData)
      .then (reply) ->
        logger.info "TEST reply received: #{reply}"
        parser.decode(reply).should.be.eql MESSAGEREPLY
      .then () ->
        logger.info "TEST send request disconnected"
        requestDisconnect = [
          parser.encode({type: 'requestDisconnect', fromInstance: 'A_1', \
                        connectPort: 5001}),
        ]
        dynChannel.deliverMessage(requestDisconnect)
      .then () ->
        done()
      .fail (err) ->
        logger.error "TEST fail #{err.message}"
        done err

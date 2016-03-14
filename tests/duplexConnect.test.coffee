net = require 'net'
slaputils = require 'slaputils'
q = require 'q'
should = require 'should'
index = require('../src/index')
ProxyDuplexConnect = index.ProxyDuplexConnect
MockComponent = require('./mock/mock').MockComponent
manifestB = require './manifests/B.json'


describe 'ProxyDuplexConnect Tests', ->


  parser = new slaputils.JsonParser()
  mockComponentB = null
  proxyDuplexConnect = null
  dup2 = null
  logger = null


  before (done) ->
    slaputils.setLoggerOwner 'ProxyDuplexConnectTest'
    logger = slaputils.getLogger 'ProxyDuplexConnectTest'
    logger.configure {
      'console-log' : false
      'console-level' : 'debug'
      'colorize': true
      'file-log' : false
      'http-log' : false
      'vm' : ''
      'auto-method': true
    }
    mockComponentB = new MockComponent 'B_2', 'B', manifestB.configuration, \
                                       manifestB.provided, manifestB.required
    mockComponentB.run()
    .then () ->
      proxyDuplexConnect = mockComponentB.proxyTcp.channels['dup2'].proxy
      dup2 = mockComponentB.proxyTcp.channels['dup2'].channel
      done()
    .fail (err) -> done err


  after (done) ->
    done()
    mockComponentB.shutdown()
    .then () -> done()
    .fail (err) -> done err


  it 'Sends a message and receives response', (done) ->
    MESSAGETEST = {value1: 'hello', value2: 10}
    MESSAGETESTRESPONSE = {result: 'ok'}
    bindPort = proxyDuplexConnect.config.port
    ephimeralPort = 5001
    msg1 = {
      type: 'bindOnConnect',
      fromInstance: 'A_1', toInstance: 'B_2',
      bindPort: bindPort, connectPort: ephimeralPort
    }
    msg2 = {
      type: 'bindOnData',
      fromInstance: 'A_1', toInstance: 'B_2',
      bindPort: bindPort, connectPort: ephimeralPort
    }
    msg3 = {
      type: 'bindOnDisconnect',
      fromInstance: 'A_1', toInstance: 'B_2',
      bindPort: bindPort, connectPort: ephimeralPort
    }

    dup2.once 'connectOnData', (data) ->
      data = parser.decode data
      data.should.be.eql MESSAGETESTRESPONSE
      dup2.deliverMessage [parser.encode(msg3), null]
      q.delay(500)
      .then () ->
        id = "#{msg1.fromInstance}:#{msg1.bindPort}:#{msg1.connectPort}"
        should.not.exist proxyDuplexConnect.connectPorts[id]
        done()

    tcpServer = net.createServer (socket) ->
      socket.on 'data', (data) ->
        socket.write(parser.encode(MESSAGETESTRESPONSE))
      socket.on 'end', () ->
        # do nothing
      socket.on 'error', (err) ->
        logger.error "socket.on error = #{err.message}"
      socket.on 'close', () -> logger.warn "socket.on close"
      socket.on 'timeout', () -> logger.warn "socket.on timeout"

    tcpServer.listen bindPort, proxyDuplexConnect.bindIp, () ->
      dup2.deliverMessage [parser.encode(msg1), null]
      q.delay(500)
      .then () ->
        id = "#{msg1.fromInstance}:#{msg1.bindPort}:#{msg1.connectPort}"
        should.exist proxyDuplexConnect.connectPorts[id]
      .then () ->
        dup2.deliverMessage [parser.encode(msg2), parser.encode(MESSAGETEST)]
      .fail (err) -> done err

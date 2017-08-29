net = require 'net'
slaputils = require 'slaputils'
q = require 'q'
should = require 'should'
index = require('../src/index')
ProxyDuplexConnect = index.ProxyDuplexConnect
MockComponent = require('./mock/mockComponent')
manifestB = require './manifests/B.json'
_ = require 'lodash'


describe 'ProxyDuplexConnect Tests', ->

  MSG_TEST = { value1: 'hello', value2: 10 }
  MSG_TESTRESPONSE = { result: 'ok' }
  MSG_CHECKOVERLAY = { value1: 'overlay' }
  MSG_CHECKOVERLAYRESPONSE = { result: 'overlay' }
  MSG_FORCECLOSE = { value1: 'forceclose' }

  parser = new slaputils.JsonParser()
  mockComponentB = null
  proxyDuplexConnect = null
  dup2 = null
  logger = null
  ephimeralPort = 5001
  proxyTcpConfiguration = JSON.parse(manifestB.configuration.proxyTcp)
  minPort = proxyTcpConfiguration['dup2'].minPort
  maxPort = proxyTcpConfiguration['dup2'].maxPort
  ports = [minPort..maxPort]
  bindPort1 = ports[0]
  bindPort2 = ports[1]
  tcpServer = null

  msg1 = {
    type: 'bindOnConnect',
    fromInstance: 'A_1', toInstance: 'B_2',
    bindPort: bindPort1, connectPort: ephimeralPort
  }
  msg2 = {
    type: 'bindOnData',
    fromInstance: 'A_1', toInstance: 'B_2',
    bindPort: bindPort1, connectPort: ephimeralPort
  }
  msg3 = {
    type: 'bindOnDisconnect',
    fromInstance: 'A_1', toInstance: 'B_2',
    bindPort: bindPort1, connectPort: ephimeralPort
  }

  msg4 = _.cloneDeep msg1
  msg5 = _.cloneDeep msg2
  msg6 = _.cloneDeep msg3
  msg4.bindPort = bindPort2
  msg5.bindPort = bindPort2
  msg6.bindPort = bindPort2


  closeTcpServer = () ->
    return q.promise (resolve, reject) ->
      if tcpServer?
        tcpServer.close () -> resolve()
      else
        resolve()


  createTcpServer = (port) ->
    return q.promise (resolve, reject) ->
      closeTcpServer()
      .then () ->
        tcpServer = net.createServer (socket) ->
          socket.on 'data', (data) ->
            data = parser.decode(data.toString())
            if data.value1 is 'hello'
              socket.write(parser.encode(MSG_TESTRESPONSE))
            else if data.value1 is 'overlay'
              socket.write(parser.encode(MSG_CHECKOVERLAYRESPONSE))
            else if data.value1 is 'forceclose'
              socket.end()
          socket.on 'end', () -> logger.info 'socket.onEnd'
          socket.on 'error', (e) -> logger.error "socket.onError = #{e.message}"
          socket.on 'close', () -> logger.warn 'socket.onClose'
          socket.on 'timeout', () -> logger.warn 'socket.onTimeout'
        tcpServer.listen "#{port}", proxyDuplexConnect.bindIp, () ->
          resolve()
      .fail (err) ->
        reject err


  before (done) ->
    slaputils.setLoggerOwner 'ProxyDuplexConnectTest'
    logger = slaputils.getLogger 'ProxyDuplexConnectTest'
    logger.configure {
      'console-log': false
      'console-level': 'debug'
      'colorize': true
      'file-log': false
      'http-log': false
      'vm': ''
      'auto-method': true
    }
    MockComponent.useThisChannels('mockChannels_testDuplex')
    mockComponentB = new MockComponent 'B_2', 'B', manifestB.configuration, \
                                       manifestB.provided, manifestB.required
    mockComponentB.run()
    mockComponentB.once 'ready', (bindIp) ->
      proxyDuplexConnect = mockComponentB.proxy.channels['dup2'].proxy
      dup2 = mockComponentB.proxy.channels['dup2'].channel
      dup2.addMember 'A_1'
      done()
    mockComponentB.on 'error', (err) -> done(err)


  after (done) ->
    mockComponentB.shutdown()
    mockComponentB.once 'close', () -> done()


  it 'Send message + receive response, connection closed by client', (done) ->
    dup2.removeAllListeners ['connectOnData']
    dup2.on 'connectOnData', (data) ->
      data = parser.decode data
      if data.result is 'overlay' then return
      data.should.be.eql MSG_TESTRESPONSE
      dup2.deliverMessage [parser.encode(msg3), null]
      q.delay(500)
      .then () ->
        id = "#{msg1.fromInstance}:#{msg1.bindPort}:#{msg1.connectPort}"
        should.not.exist proxyDuplexConnect.connectPorts[id]
        done()

    createTcpServer bindPort1
    .then () ->
      dup2.deliverMessage [parser.encode(msg1), null]
      # Send data immediately after connection, to check that it doesnt fail
      dup2.deliverMessage [parser.encode(msg2), parser.encode(MSG_CHECKOVERLAY)]
      q.delay(500)
    .then () ->
      id = "#{msg1.fromInstance}:#{msg1.bindPort}:#{msg1.connectPort}"
      should.exist proxyDuplexConnect.connectPorts[id]
      dup2.deliverMessage [parser.encode(msg2), parser.encode(MSG_TEST)]
    .fail (err) ->
      done err


  it 'Send message + receive response, closed by server', (done) ->
    dup2DataReceived = false
    dup2.removeAllListeners ['connectOnData']
    dup2.on 'connectOnData', (data) ->
      data = parser.decode data
      data.should.be.eql MSG_TESTRESPONSE
      dup2DataReceived = true
      closeTcpServer()
      .then () ->
        q.delay(500)
      .then () ->
        id = "#{msg1.fromInstance}:#{msg1.bindPort}:#{msg1.connectPort}"
        should.not.exist proxyDuplexConnect.connectPorts[id]
    isDone = (error) ->
      dup2.removeListener 'connectOnDisconnect', connectOnDisconnect
      if error? then done(error) else done()
    connectOnDisconnect = (data) ->
      if dup2DataReceived then isDone()
      else isDone new Error 'Dup2 data not received'
    dup2.on 'connectOnDisconnect', connectOnDisconnect

    createTcpServer bindPort1
    .then () ->
      dup2.deliverMessage [parser.encode(msg1), null]
      q.delay(500)
    .then () ->
      id = "#{msg1.fromInstance}:#{msg1.bindPort}:#{msg1.connectPort}"
      should.exist proxyDuplexConnect.connectPorts[id]
      dup2.deliverMessage [parser.encode(msg2), parser.encode(MSG_TEST)]
      q.delay(500)
    .then () ->
      dup2.deliverMessage [parser.encode(msg2), parser.encode(MSG_FORCECLOSE)]
    .fail (err) ->
      isDone err

  it 'Send message + receive response, connection closed by client. Port 8001'
  , (done) ->
    dup2.removeAllListeners ['connectOnData']
    dup2.on 'connectOnData', (data) ->
      data = parser.decode data
      if data.result is 'overlay' then return
      data.should.be.eql MSG_TESTRESPONSE
      dup2.deliverMessage [parser.encode(msg6), null]
      q.delay(500)
      .then () ->
        id = "#{msg4.fromInstance}:#{msg4.bindPort}:#{msg4.connectPort}"
        should.not.exist proxyDuplexConnect.connectPorts[id]
        done()

    createTcpServer bindPort2
    .then () ->
      dup2.deliverMessage [parser.encode(msg4), null]
      # Send data immediately after connection, to check that it doesnt fail
      dup2.deliverMessage [parser.encode(msg5), parser.encode(MSG_CHECKOVERLAY)]
      q.delay(500)
    .then () ->
      id = "#{msg4.fromInstance}:#{msg4.bindPort}:#{msg4.connectPort}"
      should.exist proxyDuplexConnect.connectPorts[id]
      dup2.deliverMessage [parser.encode(msg5), parser.encode(MSG_TEST)]
    .fail (err) ->
      done err

  it 'Send message + receive response, closed by server- Port 8001', (done) ->
    dup2DataReceived = false
    dup2.removeAllListeners ['connectOnData']
    dup2.on 'connectOnData', (data) ->
      data = parser.decode data
      data.should.be.eql MSG_TESTRESPONSE
      dup2DataReceived = true
      closeTcpServer()
      .then () ->
        q.delay(500)
      .then () ->
        id = "#{msg4.fromInstance}:#{msg4.bindPort}:#{msg4.connectPort}"
        should.not.exist proxyDuplexConnect.connectPorts[id]
    dup2.on 'connectOnDisconnect', (data) ->
      if dup2DataReceived then done()
      else done new Error 'Dup2 data not received'

    createTcpServer bindPort2
    .then () ->
      dup2.deliverMessage [parser.encode(msg4), null]
      q.delay(500)
    .then () ->
      id = "#{msg4.fromInstance}:#{msg4.bindPort}:#{msg4.connectPort}"
      should.exist proxyDuplexConnect.connectPorts[id]
      dup2.deliverMessage [parser.encode(msg5), parser.encode(MSG_TEST)]
      q.delay(500)
    .then () ->
      dup2.deliverMessage [parser.encode(msg5), parser.encode(MSG_FORCECLOSE)]
    .fail (err) ->
      done err

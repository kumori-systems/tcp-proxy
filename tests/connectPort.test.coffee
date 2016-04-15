net = require 'net'
slaputils = require 'slaputils'
q = require 'q'
should = require 'should'
index = require('../src/index')
DuplexConnectPort = index.DuplexConnectPort


describe 'ConnectPort Tests', ->


  parser = new slaputils.JsonParser()
  MESSAGETEST = {value1: 'hello', value2: 10}
  MESSAGETESTRESPONSE = {result: 'ok'}
  connectPortA1_1 = null
  connectPortA1_2 = null
  tcpServer = null # simulates legacy server
  logger = null


  before (done) ->
    slaputils.setLoggerOwner 'ConnectPort'
    logger = slaputils.getLogger 'ConnectPort'
    logger.configure {
      'console-log' : false
      'console-level' : 'debug'
      'colorize': true
      'file-log' : false
      'file-level': 'debug'
      'file-filename' : 'slap.log'
      'http-log' : false
      'vm' : ''
      'auto-method': false
    }
    binded = false
    tcpServer = net.createServer (socket) ->
      socket.on 'data', (data) ->
        socket.write(parser.encode(MESSAGETESTRESPONSE))
      socket.on 'end', () ->
        # do nothing
      socket.on 'error', (err) ->
        logger.error "socket.on error = #{err.message}"
        if not binded then done err
      socket.on 'close', () -> logger.warn "socket.on close"
      socket.on 'timeout', () -> logger.warn "socket.on timeout"
    tcpServer.listen 8000, '127.0.0.2', () ->
      binded = true
      connectPortA1_1 = new DuplexConnectPort 'B_2', 'A_1', '127.0.0.2', \
                                              8000, 5001
      connectPortA1_2 = new DuplexConnectPort 'B_2', 'A_1', '127.0.0.2',
                                              8000, 5002
      connectPortA1_1.init()
      .then () -> connectPortA1_2.init()
      .then () -> done()
      .fail (err) -> done err


  after (done) ->
    connectPortA1_1.terminate()
    .then () -> connectPortA1_2.terminate()
    .then () -> done()
    .fail (err) -> done err
    pendingDisconnect = 2
    checkClose = () ->
      pendingDisconnect--
      if pendingDisconnect is 0
        tcpServer.close()
        done()
    connectPortA1_1.once 'connectOnDisconnect', (event) -> checkClose()
    connectPortA1_2.once 'connectOnDisconnect', (event) -> checkClose()


  it 'Sends a message and connectport emits a response', (done) ->
    test(connectPortA1_1)
    .then () -> done()
    .fail (err) -> reject err


  it 'Repeats test, using other connectport', (done) ->
    test(connectPortA1_2)
    .then () -> done()
    .fail (err) -> reject err


  it 'Repeats test, overlaying two connectport', (done) ->
    promises = []
    test(connectPortA1_1)
    test(connectPortA1_2)
    q.all promises
    .then () -> done()
    .fail (err) -> reject err


  test = (port) ->
    return q.promise (resolve, reject) ->
      port.once 'connectOnData', (event) ->
        message = parser.decode event.data
        message.should.be.eql MESSAGETESTRESPONSE
        resolve()
      port.send parser.encode(MESSAGETEST)

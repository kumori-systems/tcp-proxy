net = require 'net'
q = require 'q'
should = require 'should'
# index = require('../lib/index')
util = require('../lib/util')
# DuplexConnectPort = index.DuplexConnectPort
DuplexConnectPort = require '../lib/duplex-connect-port'

#### START: ENABLE LOG LINES FOR DEBUGGING ####
# This will show all log lines in the code if the test are executed with
# DEBUG="tcp-proxy:*" set in the environment. For example, running:
#
# $ DEBUG="tcp-proxy:*" npm test
#
debug = require 'debug'
# debug.enable 'tcp-proxy:*'
# debug.enable 'tcp-proxy:info, tcp-proxy:debug'
debug.log = () ->
  console.log arguments...
logger = util.getLogger()
#### END: ENABLE LOG LINES FOR DEBUGGING ####

#-------------------------------------------------------------------------------


describe 'ConnectPort Tests', ->


  parser = util.getDefaultParser()
  MESSAGETEST = { value1: 'hello', value2: 10 }
  MESSAGETESTRESPONSE = { result: 'ok' }
  connectPortA1_1 = null
  connectPortA1_2 = null
  tcpServer = null # simulates legacy server


  before (done) ->
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


  it 'Sends a message and connectport emits a response', () ->
    test(connectPortA1_1)


  it 'Repeats test, using other connectport', () ->
    test(connectPortA1_2)


  it 'Repeats test, overlaying two connectport', () ->
    promises = []
    test(connectPortA1_1)
    test(connectPortA1_2)
    q.all promises


  test = (port) ->
    return q.promise (resolve, reject) ->
      port.once 'connectOnData', (event) ->
        message = parser.decode event.data
        message.should.be.eql MESSAGETESTRESPONSE
        resolve()
      port.send parser.encode(MESSAGETEST)

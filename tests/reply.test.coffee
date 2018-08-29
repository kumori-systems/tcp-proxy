net = require 'net'
q = require 'q'
should = require 'should'
index = require('../lib/index')
IpUtils = require '../lib/ip-utils'
util = require('../lib/util')
ProxyReply = index.ProxyReply

MockComponent = require('./mock/mockComponent')
manifestB = require './manifests/B.json'

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

describe 'ProxyReply Tests', ->


  parser = util.getDefaultParser()
  MESSAGEREQUEST = { value: 'this is the request' }
  MESSAGEREPLY = { value: 'this is the reply' }
  mockComponentB = null

  proxyReply1 = null
  rep1 = null
  tcpServer = null


  before (done) ->
    IpUtils.__unitTestUtil__ 0
    MockComponent.useThisChannels('mockChannels_testReply')
    mockComponentB = new MockComponent 'B_2', 'B', manifestB.configuration, \
                                       manifestB.provided, manifestB.required
    mockComponentB.run()

    mockComponentB.once 'ready', (bindIp) ->
      proxyReply1 = mockComponentB.proxy.channels['rep1'].proxy
      rep1 = mockComponentB.proxy.channels['rep1'].channel
      done()
    mockComponentB.on 'error', (err) -> done err


  after (done) ->
    mockComponentB.shutdown()
    mockComponentB.once 'close', () -> done()
    if tcpServer? then tcpServer.close()


  it 'Sends a request and receive reply', (done) ->
    tcpServer = net.createServer (socket) ->
      socket.on 'data', (data) ->
        logger.info "TEST socket.on data #{data}"
        parser.decode(data).should.be.eql MESSAGEREQUEST
        socket.write(parser.encode(MESSAGEREPLY))
      socket.on 'end', () ->
        logger.info "TEST socket.on end"
      socket.on 'close', () ->
        logger.info "TEST socket.on close"
      socket.on 'error', (err) ->
        logger.error "TEST socket.on error = #{err.message}"
      socket.on 'timeout', () ->
        logger.warn "TEST socket.on timeout"

    dynRequest = null
    dynReply = null
    tcpServer.listen proxyReply1.bindPort, proxyReply1.bindIp, () ->
      requestConnect = parser.encode({ type: 'connect', fromInstance: 'A_1'
                       , connectPort: 5001 })
      dynRequest = new MockComponent.Request('dyn_reply_A_1', 'A_1')
      rep1.handleRequest [requestConnect], [dynRequest]
      .then () ->
        q.delay(100)
      .then () ->
        dynReply = proxyReply1.connections['A_1'][5001].dynReply
        requestData = parser.encode({ type: 'data', fromInstance: 'A_1'
                      , connectPort: 5001 })
        data = parser.encode(MESSAGEREQUEST)
        try
          dynReply.handleRequest [requestData, data]
          .then () ->
            q.delay(500)
          .then () ->
            requestDisconnect = parser.encode({ type: 'disconnected'
                                , fromInstance: 'A_1', connectPort: 5001 })
            dynReply.handleRequest [requestDisconnect, null]
          .then () ->
            q.delay(500)
          .then () ->
            receivedMessage = parser.decode(dynRequest.getLastMessageSended())
            receivedMessage.value.should.equal MESSAGEREPLY.value
            done()
          .fail (err) ->
            done err
        catch e
          done e

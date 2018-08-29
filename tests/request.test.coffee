net = require 'net'
q = require 'q'
should = require 'should'
index = require('../lib/index')
IpUtils = require '../lib/ip-utils'
util = require('../lib/util')
ProxyRequest = index.ProxyRequest

MockComponent = require('./mock/mockComponent')
manifestA = require './manifests/A.json'

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
#### END: ENABLE LOG LINES FOR DEBUGGING ####

#-------------------------------------------------------------------------------


describe 'ProxyRequest Tests', ->


  parser = util.getDefaultParser()
  MESSAGEREQUEST1 = { value: 'request message 1' }
  MESSAGEREPLY1 = { value: 'reply message 1' }
  MESSAGEREQUEST2 = { value: 'request message 2' }
  MESSAGEREPLY2 = { value: 'reply message 2' }
  mockComponentA = null

  proxyRequest1 = null
  req1 = null


  before (done) ->
    IpUtils.__unitTestUtil__ 0
    MockComponent.useThisChannels('mockChannels_testRequest')
    mockComponentA = new MockComponent 'A_1', 'A', manifestA.configuration, \
                                       manifestA.provided, manifestA.required
    mockComponentA.run()
    mockComponentA.once 'ready', (bindIp) ->
      proxyRequest1 = mockComponentA.proxy.channels['req1'].proxy
      req1 = mockComponentA.proxy.channels['req1'].channel
      done()
    mockComponentA.on 'error', (err) -> done err


  after (done) ->
    mockComponentA.shutdown()
    mockComponentA.once 'close', () -> done()


  it 'Sends a request and receive reply', (done) ->
    options = { host: proxyRequest1.bindIp, port: proxyRequest1.bindPort }
    client = net.connect options, () ->
      req1.setExpectedReply(parser.encode(MESSAGEREPLY1))
      client.write parser.encode(MESSAGEREQUEST1)
      client.once 'data', (data) ->
        messageReply = parser.decode(data)
        messageReply.should.be.eql(MESSAGEREPLY1)
        done()


  it 'Sends a request and receive reply', (done) ->
    options = { host: proxyRequest1.bindIp, port: proxyRequest1.bindPort }
    client = net.connect options, () ->
      req1.setExpectedReply(parser.encode(MESSAGEREPLY1))
      client.write parser.encode(MESSAGEREQUEST1)
      client.once 'data', (data) ->
        messageReply = parser.decode(data)
        messageReply.should.be.eql(MESSAGEREPLY1)
        req1.setExpectedReply(parser.encode(MESSAGEREPLY2))
        client.write parser.encode(MESSAGEREQUEST2)
        client.once 'data', (data) ->
          messageReply = parser.decode(data)
          messageReply.should.be.eql(MESSAGEREPLY2)
          done()

  it 'Sends a request and receive a timeout', (done) ->
    options = { host: proxyRequest1.bindIp, port: proxyRequest1.bindPort }
    client = net.connect options, () ->
      req1.setExpectedReply(null)
      client.write parser.encode(MESSAGEREQUEST1)
      client.once 'data', (data) ->
        done new Error 'expected timeout!'
    setTimeout () ->
      done()
    , 1000

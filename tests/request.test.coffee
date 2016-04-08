net = require 'net'
slaputils = require 'slaputils'
q = require 'q'
should = require 'should'
index = require('../src/index')
IpUtils = require '../src/ip-utils'
MockComponent = require('./mock/mock').MockComponent
manifestA = require './manifests/A.json'
ProxyRequest = index.ProxyRequest


describe.skip 'ProxyRequest Tests', ->


  parser = new slaputils.JsonParser()
  MESSAGEREQUEST1 = {value: 'request message 1'}
  MESSAGEREPLY1 = {value: 'reply message 1'}
  MESSAGEREQUEST2 = {value: 'request message 2'}
  MESSAGEREPLY2 = {value: 'reply message 2'}
  logger = null
  mockComponentA = null

  proxyRequest1 = null
  req1 = null


  before (done) ->
    slaputils.setLoggerOwner 'ProxyRequestTest'
    logger = slaputils.getLogger 'ProxyRequestTest'
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
    mockComponentA = new MockComponent 'A_1', 'A', manifestA.configuration, \
                                       manifestA.provided, manifestA.required
    mockComponentA.run()
    .then () ->
      proxyRequest1 = mockComponentA.proxyTcp.channels['req1'].proxy
      req1 = mockComponentA.proxyTcp.channels['req1'].channel
      done()
    .fail (err) -> done err


  after (done) ->
    mockComponentA.shutdown()
    .then () -> done()
    .fail (err) -> done err


  it 'JJJ', (done) -> done()

  ###
  it 'Sends a request and receive reply', (done) ->
    options = {host: proxyRequest1.bindIp, port: proxyRequest1.bindPort}
    client = net.connect options, () ->
      req1.setExpectedReply MESSAGEREPLY1
      client.write parser.encode MESSAGEREQUEST1
      client.once 'data', (data) ->
        messageReply = parser.decode data
        messageReply.should.be.eql MESSAGEREPLY1
        req1.setExpectedReply MESSAGEREPLY2
        client.write parser.encode MESSAGEREQUEST2
        client.once 'data', (data) ->
          messageReply = parser.decode data
          messageReply.should.be.eql MESSAGEREPLY2
          done()


  it 'Sends a request and receive a timeout', (done) ->
    options = {host: proxyRequest1.bindIp, port: proxyRequest1.bindPort}
    client = net.connect options, () ->
      req1.setExpectedReply null
      client.write parser.encode MESSAGEREQUEST1
      client.once 'data', (data) ->
        done new Error 'expected timeout!'
    setTimeout () ->
      done()
    , 1000

  ###
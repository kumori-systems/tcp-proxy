net = require 'net'
slaputils = require 'slaputils'
q = require 'q'
should = require 'should'

index = require('../src/index')
ProxyDuplexBind = index.ProxyDuplexBind

MockComponent = require('./mock/mockComponent')
manifestA = require './manifests/A.json'


describe 'DuplexBind Tests', ->


  parser = new slaputils.JsonParser()
  MEMBERSHIP_TIMEOUT = 500
  MESSAGETEST = { value1: 'hello', value2: 10 }
  mockComponentA = null
  proxyDuplexBind = null
  dup1 = null
  logger = null


  before (done) ->
    slaputils.setLoggerOwner 'DuplexBind'
    logger = slaputils.getLogger 'DuplexBind'
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

    mockComponentA = new MockComponent 'A_1', 'A', manifestA.configuration, \
                                       manifestA.provided, manifestA.required
    mockComponentA.run()
    mockComponentA.once 'ready', (bindIp) ->
      proxyDuplexBind = mockComponentA.proxy.channels['dup1'].proxy
      dup1 = mockComponentA.proxy.channels['dup1'].channel
      done()
    mockComponentA.on 'error', (err) -> done err


  after (done) ->
    mockComponentA.shutdown()
    mockComponentA.once 'close', () -> done()


  it 'Add correct members', (done) ->
    @timeout MEMBERSHIP_TIMEOUT * 2
    m = proxyDuplexBind.currentMembership
    m.should.be.eql []
    dup1.addMember 'B_3'
    setTimeout () ->
      m = proxyDuplexBind.currentMembership
      b = proxyDuplexBind.bindPorts
      m.should.be.eql [{ iid: 'B_3', endpoint: 'x', service: 'x' }]
      should.exist b['B_3']
      done()
    , MEMBERSHIP_TIMEOUT


  it 'Send and receive messages from 8000', (done) ->
    @timeout MEMBERSHIP_TIMEOUT * 4
    bindport_B_3 = proxyDuplexBind.bindPorts['B_3']['8000']
    options = { host: bindport_B_3.ip, port: bindport_B_3.port }
    promises = []
    promises.push clientSendAndReceive(options, "1")
    # a second overlay connection!
    promises.push clientSendAndReceive(options, "2")
    q.all promises
    .then () -> done()
    .fail (err) -> done err

  it 'Send and receive messages from 8001', (done) ->
    @timeout MEMBERSHIP_TIMEOUT * 4
    bindport_B_3 = proxyDuplexBind.bindPorts['B_3']['8001']
    options = { host: bindport_B_3.ip, port: bindport_B_3.port }
    promises = []
    promises.push clientSendAndReceive(options, "3")
    # a second overlay connection!
    promises.push clientSendAndReceive(options, "4")
    q.all promises
    .then () -> done()
    .fail (err) -> done err

  clientSendAndReceive = (options, id) ->
    method = 'test.clientSendAndReceive()'
    logger.info "#{method} options = #{JSON.stringify options}"
    WAIT_TIME = 500
    q.promise (resolve, reject) ->
      legacyClient = net.connect options, () ->
        q.delay(WAIT_TIME)
        .then () ->
          legacyClient.write parser.encode MESSAGETEST
          q.delay(WAIT_TIME)
        .then () ->
          promise = q.promise (resolve2, reject2) ->
            legacyClient.on 'data', (data) ->
              message = parser.decode data
              if message.result is 'ok'
                logger.info "#{method} message result ok received"
                resolve2()
              else
                reject2 new Error 'Unexpected Message'
          q.timeout promise, (MEMBERSHIP_TIMEOUT + 1000)
        .then () ->
          legacyClient.end()
          q.delay(WAIT_TIME)
        .then () ->
          resolve()
        .fail (err) ->
          logger.info "#{method} #{err.message}"
          reject err

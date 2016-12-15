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
  MESSAGETEST = {value1: 'hello', value2: 10}
  mockComponentA = null
  proxyDuplexBind = null
  dup1 = null
  logger = null


  before (done) ->
    slaputils.setLoggerOwner 'DuplexBind'
    logger = slaputils.getLogger 'DuplexBind'
    logger.configure {
      'console-log' : false
      'console-level' : 'debug'
      'colorize': true
      'file-log' : false
      'http-log' : false
      'vm' : ''
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
    @timeout MEMBERSHIP_TIMEOUT*2
    m = proxyDuplexBind.currentMembership
    m.should.be.eql []
    dup1.addMember 'B_3'
    setTimeout () ->
      m = proxyDuplexBind.currentMembership
      b = proxyDuplexBind.bindPorts
      m.should.be.eql [{iid:'B_3', endpoint:'x', service:'x'}]
      should.exist b['B_3']
      done()
    , MEMBERSHIP_TIMEOUT


  it 'Send and receive messages', (done) ->
    @timeout MEMBERSHIP_TIMEOUT*4
    bindport_B_3 = proxyDuplexBind.bindPorts['B_3']
    options = {host: bindport_B_3.ip, port: bindport_B_3.port}
    promises = []
    promises.push clientSendAndReceive(options)
    promises.push clientSendAndReceive(options) # a second overlay connection!
    q.all promises
    .then () -> done()
    .fail (err) -> done err


  clientSendAndReceive = (options) ->
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
          legacyClient.on 'data', (data) ->
            message = parser.decode data
            if message.result is 'ok'
              logger.info "#{method} message result ok received"
              q()
            else
              reject new Error 'Unexpected Message'
          setTimeout () ->
            reject new Error 'Timeout message'
          , MEMBERSHIP_TIMEOUT+1000
        .then () ->
          legacyClient.end()
          q.delay(WAIT_TIME)
        .then () ->
          resolve()
        .fail (err) ->
          logger.info "#{method} #{err.message}"
          reject err

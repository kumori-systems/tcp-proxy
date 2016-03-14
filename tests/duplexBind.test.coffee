net = require 'net'
slaputils = require 'slaputils'
q = require 'q'
should = require 'should'
index = require('../src/index')
ProxyDuplexBind = index.ProxyDuplexBind
MockComponent = require('./mock/mock').MockComponent
manifestA = require './manifests/A.json'


describe 'ProxyDuplexBind Tests', ->


  parser = new slaputils.JsonParser()
  GETROLE_TIMEOUT = 5000 # should be equal to proxy-duplex-bind/GETROLE_TIMEOUT
  MESSAGETEST = {value1: 'hello', value2: 10}
  mockComponentA = null
  proxyDuplexBind = null
  dup1 = null
  logger = null


  before (done) ->
    slaputils.setLoggerOwner 'ProxyDuplexBindTest'
    logger = slaputils.getLogger 'ProxyDuplexBindTest'
    logger.configure {
      'console-log' : false
      'console-level' : 'debug'
      'colorize': true
      'file-log' : false
      'http-log' : false
      'vm' : ''
      'auto-method': true
    }
    mockComponentA = new MockComponent 'A_1', 'A', manifestA.configuration, \
                                       manifestA.provided, manifestA.required
    mockComponentA.run()
    .then () ->
      proxyDuplexBind = mockComponentA.proxyTcp.channels['dup1'].proxy
      dup1 = mockComponentA.proxyTcp.channels['dup1'].channel
      done()
    .fail (err) -> done err


  after (done) ->
    done()
    mockComponentA.shutdown()
    .then () -> done()
    .fail (err) -> done err


  it 'Add correct members', (done) ->
    @timeout GETROLE_TIMEOUT*2
    m = proxyDuplexBind.currentMembership
    b = proxyDuplexBind.bindPorts
    m.should.be.eql [] # A_1 isnt included in membership
    dup1.addMember 'A_2'
    dup1.addMember 'B_3'
    setTimeout () ->
      m.should.be.eql ['A_2', 'B_3']
      should.not.exist b['A_2']
      should.exist b['B_3']
      done()
    , GETROLE_TIMEOUT


  it 'Add incorrect-member', (done) ->
    @timeout GETROLE_TIMEOUT*2
    m = proxyDuplexBind.currentMembership
    b = proxyDuplexBind.bindPorts
    dup1.addMember 'Z_4'
    setTimeout () ->
      m.should.be.eql ['A_2', 'B_3'] # Z4 -> simulated error
      should.exist b['B_3']
      done()
    , GETROLE_TIMEOUT


  it 'Add timeout-member', (done) ->
    @timeout GETROLE_TIMEOUT*2
    m = proxyDuplexBind.currentMembership
    b = proxyDuplexBind.bindPorts
    dup1.addMember 'T_4'
    setTimeout () ->
      m.should.be.eql ['A_2', 'B_3'] # T4 -> simulated timeout
      should.exist b['B_3']
      done()
    , GETROLE_TIMEOUT+1000


  it 'Send and receive messages', (done) ->
    @timeout GETROLE_TIMEOUT*4
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
          , GETROLE_TIMEOUT+1000
        .then () ->
          legacyClient.end()
          q.delay(WAIT_TIME)
        .then () ->
          resolve()
        .fail (err) ->
          logger.info "#{method} #{err.message}"
          reject err

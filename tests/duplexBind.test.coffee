net = require 'net'
q = require 'q'
should = require 'should'
util = require('../lib/util')

index = require('../lib/index')
ProxyDuplexBind = index.ProxyDuplexBind
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
logger = util.getLogger()
#### END: ENABLE LOG LINES FOR DEBUGGING ####

#-------------------------------------------------------------------------------


describe 'DuplexBind Tests', ->


  parser = util.getDefaultParser()
  MEMBERSHIP_TIMEOUT = 500
  MESSAGETEST = { value1: 'hello', value2: 10 }
  mockComponentA = null
  proxyDuplexBind = null
  dup1 = null


  before (done) ->

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


  it 'Send and receive messages from 8000', () ->
    @timeout MEMBERSHIP_TIMEOUT * 4
    bindport_B_3 = proxyDuplexBind.bindPorts['B_3']['8000']
    options = { host: bindport_B_3.ip, port: bindport_B_3.port }
    promises = []
    promises.push clientSendAndReceive(options, "1")
    # a second overlay connection!
    promises.push clientSendAndReceive(options, "2")
    q.all promises

  it 'Send and receive messages from 8001', () ->
    @timeout MEMBERSHIP_TIMEOUT * 4
    bindport_B_3 = proxyDuplexBind.bindPorts['B_3']['8001']
    options = { host: bindport_B_3.ip, port: bindport_B_3.port }
    promises = []
    promises.push clientSendAndReceive(options, "3")
    # a second overlay connection!
    promises.push clientSendAndReceive(options, "4")
    q.all promises

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

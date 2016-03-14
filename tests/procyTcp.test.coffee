should = require 'should'
slaputils = require 'slaputils'
q = require 'q'
_ = require 'lodash'
ProxyTcp  = require('../src/index').ProxyTcp
MockComponent = require('./mock/mock').MockComponent

manifestA = require './manifests/A.json'
manifestB = require './manifests/B.json'
manifestC = require './manifests/C.json'


describe 'Initialization tests', ->


  logger = null


  before (done) ->
    slaputils.setLoggerOwner 'InitializationTest'
    logger = slaputils.getLogger 'Initializationest'
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
    done()


  it 'Correct proxytcp manifests', (done) ->

    mockComponentA = new MockComponent 'A_1', 'A', manifestA.configuration, \
                                         manifestA.provided, manifestA.required
    c = mockComponentA.proxyTcp.channels
    c['send1'].proxy.constructor.name.should.be.eql 'ProxySend'
    c['req1'].proxy.constructor.name.should.be.eql 'ProxyRequest'
    c['dup1'].proxy.constructor.name.should.be.eql 'ProxyDuplexBind'
    should.not.exist c['noproxychannel']

    mockComponentB = new MockComponent 'B_1', 'B', manifestB.configuration, \
                                       manifestB.provided, manifestB.required
    c = mockComponentB.proxyTcp.channels
    c['recv1'].proxy.constructor.name.should.be.eql 'ProxyReceive'
    c['rep1'].proxy.constructor.name.should.be.eql 'ProxyReply'
    c['dup2'].proxy.constructor.name.should.be.eql 'ProxyDuplexConnect'

    mockComponentA.run()
    .then () -> mockComponentB.run()
    .then () -> mockComponentA.shutdown()
    .then () -> mockComponentB.shutdown()
    .then () -> done()
    .fail (err) -> done err


  it 'Incorrect proxytcp manifest', (done) ->
    try
      mockComponentC = new MockComponent 'C_1', 'C', manifestC.configuration, \
                                         manifestC.provided, manifestC.required
      done new Error 'This test must fail!'
    catch e
      if _.startsWith(e.message, 'Channel type doesnt exists') then done()
      else done e

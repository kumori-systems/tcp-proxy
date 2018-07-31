should = require 'should'
q = require 'q'
_ = require 'lodash'
util = require('../src/util')

MockComponent = require('./mock/mockComponent')

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

manifestA = require './manifests/A.json'
manifestB = require './manifests/B.json'
manifestC = require './manifests/C.json'


describe 'Initialization tests', ->

  before (done) ->
    MockComponent.useThisChannels('mockChannels_testProxyTcp')
    done()


  it 'Correct proxytcp manifests A', (done) ->
    mockComponentA = new MockComponent 'A_1', 'A', manifestA.configuration, \
                                         manifestA.provided, manifestA.required
    mockComponentA.run()
    mockComponentA.on 'ready', (bindIp) ->
      c = mockComponentA.proxy.channels
      c['send1'].proxy.constructor.name.should.be.eql 'ProxySend'
      c['req1'].proxy.constructor.name.should.be.eql 'ProxyRequest'
      c['dup1'].proxy.constructor.name.should.be.eql 'ProxyDuplexBind'
      should.not.exist c['noproxychannel']
      setTimeout () ->
        mockComponentA.shutdown()
      , 100
    mockComponentA.on 'close', () ->
      done()
    mockComponentA.on 'error', (err) ->
      done(err)


  it 'Correct proxytcp manifests B', (done) ->
    mockComponentB = new MockComponent 'B_1', 'B', manifestB.configuration, \
                                       manifestB.provided, manifestB.required
    mockComponentB.run()
    mockComponentB.on 'ready', (bindIp) ->
      c = mockComponentB.proxy.channels
      c['recv1'].proxy.constructor.name.should.be.eql 'ProxyReceive'
      c['rep1'].proxy.constructor.name.should.be.eql 'ProxyReply'
      c['dup2'].proxy.constructor.name.should.be.eql 'ProxyDuplexConnect'
      setTimeout () ->
        mockComponentB.shutdown()
      , 100
    mockComponentB.on 'close', () ->
      done()
    mockComponentB.on 'error', (err) ->
      done(err)


  it 'Incorrect proxytcp manifest', (done) ->
    try
      mockComponentC = new MockComponent 'C_1', 'C', manifestC.configuration, \
                                         manifestC.provided, manifestC.required
      done new Error 'This test must fail!'
    catch e
      if _.startsWith(e.message, 'Channel type doesnt exists') then done()
      else done(e)

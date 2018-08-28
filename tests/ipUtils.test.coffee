_ = require 'lodash'
should = require 'should'
IpUtils = require '../lib/ip-utils'
util = require('../lib/util')

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


describe 'Ip-Utils tests', ->

  after (done) ->
    IpUtils.__unitTestUtil__ 0
    done()


  it 'Get IP from IID', (done) ->
    ipA1 = IpUtils.getIpFromIid 'A_X_0'
    ipA65532 = IpUtils.getIpFromIid 'A_X_65532'
    ipA1.should.be.equal '127.0.0.2'
    ipA65532.should.be.equal '127.0.255.254'
    done()


  it 'Get IP from IID, using dash', (done) ->
    ipA1 = IpUtils.getIpFromIid 'A_X-0'
    ipA65532 = IpUtils.getIpFromIid 'A_X-65532'
    ipA1.should.be.equal '127.0.0.2'
    ipA65532.should.be.equal '127.0.255.254'
    done()


  it 'Get IP from IID out of range', (done) ->
    try
      ipA65533 = IpUtils.getIpFromIid 'A_X_65533'
      done new Error "IP #{ipA65533} getted, but fail expected"
    catch e
      # fail expected
      done()


  it 'Get IP from pool', (done) ->
    IpUtils.__unitTestUtil__ 0
    ipA = IpUtils.getIpFromPool()
    ipA.should.be.equal '127.1.0.1'
    ipB = IpUtils.getIpFromPool()
    ipB.should.be.equal '127.1.0.2'
    IpUtils.__unitTestUtil__ 65534
    ipC = IpUtils.getIpFromPool()
    ipC.should.be.equal '127.1.255.255'
    done()


  it 'Get IP from pool out of range', (done) ->
    try
      IpUtils.__unitTestUtil__ 65535
      ipD = IpUtils.getIpFromPool()
      done new Error "IP #{ipD} getted, but fail expected"
    catch e
      # fail expected
      done()

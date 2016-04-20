slaputils = require 'slaputils'
_ = require 'lodash'
should = require 'should'
IpUtils = require '../src/ip-utils'


describe 'Ip-Utils tests', ->


  logger = null


  before (done) ->
    slaputils.setLoggerOwner 'IpUtilsTest'
    logger = slaputils.getLogger 'IpUtilsTest'
    logger.configure {
      'console-log' : false
      'console-level' : 'debug'
      'colorize': true
      'file-log' : false
      'file-level': 'debug'
      'file-filename' : 'slap.log'
      'http-log' : false
      'vm' : ''
      'auto-method': false
    }
    done()

  after (done) ->
    IpUtils.__unitTestUtil__ 0
    done()


  it 'Get IP from IID', (done) ->
    ipA1 = IpUtils.getIpFromIid 'A_X_0'
    ipA65532 = IpUtils.getIpFromIid 'A_X_65532'
    ipA1.should.be.equal '127.0.0.2'
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

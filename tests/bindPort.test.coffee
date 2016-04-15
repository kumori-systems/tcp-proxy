net = require 'net'
slaputils = require 'slaputils'
q = require 'q'
should = require 'should'
index = require('../src/index')
DuplexBindPort = index.DuplexBindPort


describe 'BindPort Tests', ->


  parser = new slaputils.JsonParser()
  MESSAGETEST = {value1: 'hello', value2: 10}
  bindPortB2 = null
  bindPortB3 = null
  logger = null


  before (done) ->
    slaputils.setLoggerOwner 'BindPort'
    logger = slaputils.getLogger 'BindPort'
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
    bindPortB2 = new DuplexBindPort 'A_1', 'B_2', 8000
    bindPortB3 = new DuplexBindPort 'A_1', 'B_3', 8000
    promises = []
    promises.push bindPortB2.init()
    promises.push bindPortB3.init()
    q.all promises
    .then () -> done()
    .fail (err) -> done err


  after (done) ->
    promises = []
    promises.push bindPortB2.terminate()
    promises.push bindPortB3.terminate()
    q.all promises
    .then () -> done()
    .fail (err) -> done err


  it 'Connects tcpclient, sends a message and bindport emits it', (done) ->
    test(bindPortB2)
    .then () -> done()
    .fail (err) -> reject err


  it 'Repeats test, using other bindport', (done) ->
    test(bindPortB3)
    .then () -> done()
    .fail (err) -> reject err


  it 'Repeats test, overlayng two bindports', (done) ->
    promises = []
    promises.push test(bindPortB2)
    promises.push test(bindPortB3)
    q.all promises
    .then () -> done()
    .fail (err) -> reject err


  test = (port) ->
    return q.promise (resolve, reject) ->
      connectreceived = false
      datareceived = false
      port.once 'bindOnConnect', (event) ->
        connectreceived = true
      port.once 'bindOnData', (event) ->
        datareceived = true
        message = parser.decode event.data
        message.should.be.eql MESSAGETEST
      port.once 'bindOnDisconnect', (event) ->
        if not connectreceived then reject new Error 'connect not received'
        else if not datareceived then reject new Error 'data not received'
        else resolve()
      options = {host: port.ip, port: port.port}
      tcpClient = net.connect options, () ->
        tcpClient.write parser.encode MESSAGETEST
        tcpClient.end()


net = require 'net'
q = require 'q'
should = require 'should'
# index = require('../src/index')
util = require('../src/util')
# DuplexBindPort = index.DuplexBindPort
DuplexBindPort = require '../src/duplex-bind-port'

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


describe 'BindPort Tests', ->


  parser = util.getDefaultParser()
  MESSAGETEST = { value1: 'hello', value2: 10 }
  bindPortB2 = null
  bindPortB3 = null


  before () ->
    bindPortB2 = new DuplexBindPort 'A_1', 'B_2', 8000
    bindPortB3 = new DuplexBindPort 'A_1', 'B_3', 8000
    promises = []
    promises.push bindPortB2.init()
    promises.push bindPortB3.init()
    q.all promises


  after () ->
    promises = []
    promises.push bindPortB2.terminate()
    promises.push bindPortB3.terminate()
    q.all promises


  it 'Connects tcpclient, sends a message and bindport emits it', () ->
    test(bindPortB2)


  it 'Repeats test, using other bindport', () ->
    test(bindPortB3)


  it 'Repeats test, overlayng two bindports', () ->
    promises = []
    promises.push test(bindPortB2)
    promises.push test(bindPortB3)
    q.all promises


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
      options = { host: port.ip, port: port.port }
      tcpClient = net.connect options, () ->
        tcpClient.write parser.encode MESSAGETEST
        tcpClient.end()


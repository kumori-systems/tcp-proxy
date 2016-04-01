ProxyTcp              = require './proxy-tcp'
ProxyDuplexBind       = require './proxy-duplex-bind'
ProxyDuplexConnect    = require './proxy-duplex-connect'
DuplexBindPort        = require './duplex-bind-port'
DuplexConnectPort     = require './duplex-connect-port'
ProxyRequest          = require './proxy-request'
ProxyReply            = require './proxy-reply'
ProxySend             = require './proxy-send'
ProxyReceive          = require './proxy-receive'
slaputils             = require 'slaputils'

slaputils.setLogger [ProxyTcp, ProxyDuplexBind, ProxyDuplexConnect, \
                     DuplexBindPort, DuplexConnectPort, \
                     ProxyRequest, ProxyReply, \
                     ProxySend, ProxyReceive]

slaputils.setParser [ProxyTcp, ProxyDuplexBind, ProxyDuplexConnect, \
                     DuplexBindPort, DuplexConnectPort, \
                     ProxyRequest, ProxyReply, \
                     ProxySend, ProxyReceive]

exports.ProxyTcp = ProxyTcp
exports.ProxyDuplexBind = ProxyDuplexBind
exports.ProxyDuplexConnect = ProxyDuplexConnect
exports.DuplexBindPort = DuplexBindPort
exports.DuplexConnectPort = DuplexConnectPort
exports.ProxyRequest = ProxyRequest
exports.ProxyReply = ProxyReply
exports.ProxySend = ProxySend
exports.ProxyReceive = ProxyReceive

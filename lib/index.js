(function() {
  var DuplexBindPort, DuplexConnectPort, ProxyDuplexBind, ProxyDuplexConnect, ProxyReceive, ProxyReply, ProxyRequest, ProxySend, ProxyTcp;

  ProxyTcp = require('./proxy-tcp').ProxyTcp;

  ProxyDuplexBind = require('./proxy-duplex-bind');

  ProxyDuplexConnect = require('./proxy-duplex-connect');

  DuplexBindPort = require('./duplex-bind-port');

  DuplexConnectPort = require('./duplex-connect-port');

  ProxyRequest = require('./proxy-request');

  ProxyReply = require('./proxy-reply');

  ProxySend = require('./proxy-send');

  ProxyReceive = require('./proxy-receive');

  exports.TcpProxy = ProxyTcp;

}).call(this);
//# sourceMappingURL=index.js.map
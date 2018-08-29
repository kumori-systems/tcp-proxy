(function() {
  var DuplexBindPort, EventEmitter, ipUtils, net, q, util,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty;

  net = require('net');

  EventEmitter = require('events').EventEmitter;

  q = require('q');

  ipUtils = require('./ip-utils');

  util = require('./util');

  DuplexBindPort = (function(superClass) {
    extend(DuplexBindPort, superClass);

    function DuplexBindPort(iid, remoteIid, port) {
      var method;
      this.iid = iid;
      this.remoteIid = remoteIid;
      this.port = port;
      this._onTimeout = bind(this._onTimeout, this);
      this._onClose = bind(this._onClose, this);
      this._onError = bind(this._onError, this);
      this._onDisconnect = bind(this._onDisconnect, this);
      this._onData = bind(this._onData, this);
      this._onConnection = bind(this._onConnection, this);
      method = 'DuplexBindPort.constructor';
      if (this.logger == null) {
        this.logger = util.getLogger();
      }
      this.ip = ipUtils.getIpFromIid(this.remoteIid);
      this.name = this.iid + "/" + this.remoteIid + ":" + this.ip + ":" + this.port;
      this.logger.info(method + " " + this.name);
      this.tcpServer = null;
      this.connections = {};
    }

    DuplexBindPort.prototype.init = function() {
      var method;
      method = 'DuplexBindPort.init';
      this.logger.info(method + " " + this.name);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          var binded;
          binded = false;
          _this.tcpServer = net.createServer(_this._onConnection);
          _this.tcpServer.on('error', function(err) {
            _this.logger.error(method + " " + _this.name + " " + err.message);
            if (!binded) {
              return reject(err);
            }
          });
          return _this.tcpServer.listen(_this.port, _this.ip, function() {
            _this.logger.info(method + " " + _this.name + " listening");
            binded = true;
            return resolve();
          });
        };
      })(this));
    };

    DuplexBindPort.prototype.terminate = function() {
      var method;
      method = 'DuplexBindPort.terminate';
      this.logger.info(method + " " + this.name);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          if (_this.tcpServer != null) {
            _this.tcpServer.close();
            _this.tcpServer = null;
          }
          return resolve();
        };
      })(this));
    };

    DuplexBindPort.prototype.send = function(message, connectPort) {
      var buf, method;
      method = 'DuplexBindPort.send';
      buf = new Buffer(message);
      this.logger.debug(method + " " + this.name);
      if (this.connections[connectPort] != null) {
        return this.connections[connectPort].write(buf);
      } else {
        return this.logger.error(method + " " + this.name + " connection " + connectPort + " not found");
      }
    };

    DuplexBindPort.prototype.deleteConnection = function(connectPort) {
      var method;
      method = 'DuplexBindPort.deleteConnection';
      this.logger.debug(method + " " + this.name + " " + connectPort);
      if (this.connections[connectPort] != null) {
        this.connections[connectPort].end();
        return delete this.connections[connectPort];
      }
    };

    DuplexBindPort.prototype._onConnection = function(socket) {
      var connectPort, method;
      method = 'DuplexBindPort._onConnection';
      connectPort = socket.remotePort;
      this.logger.debug(method + " " + this.name + " " + connectPort);
      this.connections[connectPort] = socket;
      this.emit('bindOnConnect', {
        remoteIid: this.remoteIid,
        bindPort: this.port,
        connectPort: connectPort,
        data: null
      });
      socket.on('data', (function(_this) {
        return function(data) {
          return _this._onData(data, connectPort);
        };
      })(this));
      socket.on('end', (function(_this) {
        return function() {
          return _this._onDisconnect(connectPort);
        };
      })(this));
      socket.on('error', (function(_this) {
        return function(err) {
          return _this._onError(err, connectPort);
        };
      })(this));
      socket.on('close', (function(_this) {
        return function() {
          return _this._onClose(connectPort);
        };
      })(this));
      return socket.on('timeout', (function(_this) {
        return function() {
          return _this._onTimeout(connectPort);
        };
      })(this));
    };

    DuplexBindPort.prototype._onData = function(data, connectPort) {
      var method;
      method = 'DuplexBindPort._onData';
      this.logger.debug(method + " " + this.name + " " + connectPort);
      return this.emit('bindOnData', {
        remoteIid: this.remoteIid,
        bindPort: this.port,
        connectPort: connectPort,
        data: data
      });
    };

    DuplexBindPort.prototype._onDisconnect = function(connectPort) {
      var method;
      method = 'DuplexBindPort._onDisconnect';
      this.logger.debug(method + " " + this.name + " " + connectPort);
      this.deleteConnection(connectPort);
      return this.emit('bindOnDisconnect', {
        remoteIid: this.remoteIid,
        bindPort: this.port,
        connectPort: connectPort,
        data: null
      });
    };

    DuplexBindPort.prototype._onError = function(err, connectPort) {
      var method;
      method = 'DuplexBindPort._onError';
      return this.logger.error(method + " " + this.name + " " + connectPort + " " + err.message);
    };

    DuplexBindPort.prototype._onClose = function(connectPort) {
      var method;
      method = 'DuplexBindPort._onClose';
      return this.logger.debug(method + " " + this.name + " " + connectPort);
    };

    DuplexBindPort.prototype._onTimeout = function(connectPort) {
      var method;
      method = 'DuplexBindPort._onTimeout';
      return this.logger.error(method + " " + this.name + " " + connectPort + " " + err.message);
    };

    return DuplexBindPort;

  })(EventEmitter);

  module.exports = DuplexBindPort;

}).call(this);
//# sourceMappingURL=duplex-bind-port.js.map
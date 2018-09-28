(function() {
  var DuplexConnectPort, EventEmitter, ipUtils, net, q, util,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty;

  net = require('net');

  EventEmitter = require('events').EventEmitter;

  q = require('q');

  util = require('./util');

  ipUtils = require('./ip-utils');

  DuplexConnectPort = (function(superClass) {
    extend(DuplexConnectPort, superClass);

    function DuplexConnectPort(iid, remoteIid, bindIp, bindPort, connectPort) {
      var method;
      this.iid = iid;
      this.remoteIid = remoteIid;
      this.bindIp = bindIp;
      this.bindPort = bindPort;
      this.connectPort = connectPort;
      this._onEnd = bind(this._onEnd, this);
      this._onData = bind(this._onData, this);
      method = 'DuplexConnectPort.constructor';
      if (this.logger == null) {
        this.logger = util.getLogger();
      }
      this.name = this.iid + "/" + this.remoteIid + ":" + this.bindIp + ":" + this.bindPort + ":" + this.connectPort;
      this.logger.info(method + " " + this.name);
      this._tcpClient = null;
      this._creatingPromise = null;
    }

    DuplexConnectPort.prototype.init = function() {
      var method;
      method = 'DuplexConnectPort.init';
      this.logger.info(method + " " + this.name);
      this._creatingPromise = this._connect();
      return this._creatingPromise;
    };

    DuplexConnectPort.prototype.terminate = function() {
      var method;
      method = 'DuplexConnectPort.terminate';
      this.logger.info(method + " " + this.name);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          if (_this._tcpClient != null) {
            _this._creatingPromise.then(function() {
              _this._tcpClient.removeListener('end', _this._onEnd);
              _this._tcpClient.end();
              return _this._tcpClient = null;
            });
          }
          return resolve();
        };
      })(this));
    };

    DuplexConnectPort.prototype.send = function(data) {
      var method;
      method = 'DuplexConnectPort.send';
      this.logger.debug(method + " " + this.name);
      return this._creatingPromise.then((function(_this) {
        return function() {
          if (_this._tcpClient != null) {
            return _this._tcpClient.write(data);
          } else {
            return _this.logger.error(method + " " + _this.name + " error: tcpclient is null");
          }
        };
      })(this));
    };

    DuplexConnectPort.prototype._connect = function() {
      var method;
      method = 'DuplexConnectPort._connect';
      this.logger.info(method + " " + this.name);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          var connected, options;
          connected = false;
          options = {
            host: _this.bindIp,
            port: _this.bindPort,
            localAddress: ipUtils.getIpFromIid(_this.remoteIid)
          };
          _this._tcpClient = net.connect(options, function() {
            _this.logger.info(method + " " + _this.name + " connected " + (JSON.stringify(options)));
            connected = true;
            return resolve();
          });
          _this._tcpClient.on('data', _this._onData);
          _this._tcpClient.on('end', _this._onEnd);
          _this._tcpClient.on('error', function(err) {
            _this.logger.error(method + " " + _this.name + " onError: " + err.message);
            if (connected === false) {
              return reject(err);
            }
          });
          _this._tcpClient.on('close', function() {
            _this.logger.info(method + " " + _this.name + " onClose");
            if (connected === false) {
              return reject(new Error('onClose event'));
            }
          });
          return _this._tcpClient.on('timeout', function() {
            _this.logger.info(method + " " + _this.name + " onTimeout");
            if (connected === false) {
              return reject(new Error('onTimeout event'));
            }
          });
        };
      })(this));
    };

    DuplexConnectPort.prototype._onData = function(data) {
      var method;
      method = 'DuplexConnectPort._onData';
      this.logger.debug(method + " " + this.name);
      return this.emit('connectOnData', {
        remoteIid: this.remoteIid,
        bindPort: this.bindPort,
        connectPort: this.connectPort,
        data: data
      });
    };

    DuplexConnectPort.prototype._onEnd = function(remotePort) {
      var method;
      method = 'DuplexConnectPort._onEnd';
      this.logger.debug(method + " " + this.name);
      return this.emit('connectOnDisconnect', {
        remoteIid: this.remoteIid,
        bindPort: this.bindPort,
        connectPort: this.connectPort,
        data: null
      });
    };

    return DuplexConnectPort;

  })(EventEmitter);

  module.exports = DuplexConnectPort;

}).call(this);
//# sourceMappingURL=duplex-connect-port.js.map
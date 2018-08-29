(function() {
  var ProxyRequest, ipUtils, net, q, util,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  net = require('net');

  q = require('q');

  ipUtils = require('./ip-utils');

  util = require('./util');

  ProxyRequest = (function() {
    function ProxyRequest(owner, role, iid, channel, bindPorts, parser) {
      var method;
      this.owner = owner;
      this.role = role;
      this.iid = iid;
      this.channel = channel;
      this.bindPorts = bindPorts;
      this.parser = parser;
      this._onTcpEnd = bind(this._onTcpEnd, this);
      this._onTcpData = bind(this._onTcpData, this);
      this._processConnection = bind(this._processConnection, this);
      method = 'ProxyRequest.constructor';
      if (this.logger == null) {
        this.logger = util.getLogger();
      }
      if ((!Array.isArray(this.bindPorts)) || (this.bindPorts.length > 1)) {
        throw new Error(method + ". Last parameter should be an array with a single port");
      }
      this.bindIp = ipUtils.getIpFromPool();
      this.name = this.role + "/" + this.iid + "/" + this.channel.name + "/" + this.bindIp + ":" + this.bindPorts;
      this.bindPort = this.bindPorts[0];
      this.logger.info(method + " " + this.name);
      this.tcpServer = null;
      this.connections = {};
    }

    ProxyRequest.prototype.init = function() {
      var method;
      method = "ProxyRequest.init " + this.name;
      this.logger.info("" + method);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          var binded;
          binded = false;
          _this.tcpServer = net.createServer().listen(_this.bindPort, _this.bindIp);
          _this.tcpServer.on('listening', function() {
            _this.logger.info(method + " tcpserver onListen (" + _this.bindIp + ":" + _this.bindPort + ")");
            binded = true;
            _this.owner.emit('change', {
              channel: _this.channel.name,
              listening: true,
              ip: _this.bindIp,
              port: _this.bindPort
            });
            return resolve();
          });
          _this.tcpServer.on('error', function(err) {
            var connection, key, ref;
            _this.logger.error(method + " tcpserver onError " + err.stack);
            if (!binded) {
              return reject(err);
            } else {
              ref = _this.connections;
              for (key in ref) {
                connection = ref[key];
                connection.socket.end();
              }
              return _this.tcpServer.close();
            }
          });
          _this.tcpServer.on('close', function() {
            _this.logger.info(method + " tcpserver onClose");
            _this.tcpServer = null;
            return _this.owner.emit('change', {
              channel: _this.channel.name,
              listening: false,
              ip: _this.bindIp,
              port: _this.bindPort
            });
          });
          return _this.tcpServer.on('connection', function(socket) {
            _this.logger.info(method + " tcpserver onConnection");
            return _this._processConnection(socket);
          });
        };
      })(this));
    };

    ProxyRequest.prototype.terminate = function() {
      var connection, key, method, ref;
      method = "ProxyRequest.terminate " + this.name;
      this.logger.info("" + method);
      ref = this.connections;
      for (key in ref) {
        connection = ref[key];
        connection.socket.end();
      }
      if (this.tcpServer != null) {
        this.tcpServer.close();
      }
      return q();
    };

    ProxyRequest.prototype._processConnection = function(socket) {
      var connectPort, dynReply, dynRequestPromise, method;
      method = "ProxyRequest._processConnection " + this.name;
      connectPort = socket.remotePort;
      this.logger.debug(method + " port:" + connectPort);
      dynReply = this.channel.runtimeAgent.createChannel();
      dynReply.handleRequest = (function(_this) {
        return function(request) {
          var err, header;
          header = _this.parser.decode(request[0]);
          if (header.type === 'data') {
            return _this._onChannelData(header, request[1], connectPort);
          } else if (header.type === 'disconnected') {
            return _this._onChannelEnd(header, connectPort);
          } else {
            err = new Error("Unexpected request type=" + header.type);
            _this.logger.error(method + " err:" + err.message);
            return q(err);
          }
        };
      })(this);
      dynRequestPromise = this._sendConnect(connectPort, dynReply);
      this.connections[connectPort] = {
        socket: socket,
        dynReply: dynReply,
        dynRequest: null,
        dynRequestPromise: dynRequestPromise
      };
      socket.on('data', (function(_this) {
        return function(data) {
          return _this._onTcpData(data, connectPort);
        };
      })(this));
      socket.on('end', (function(_this) {
        return function() {
          return _this._onTcpEnd(connectPort);
        };
      })(this));
      socket.on('error', (function(_this) {
        return function(err) {
          _this.logger.error(method + " event:onError " + err.stack);
          return socket.end();
        };
      })(this));
      socket.on('timeout', (function(_this) {
        return function() {
          _this.logger.error(method + " event:onTimeout");
          return socket.end();
        };
      })(this));
      return socket.on('close', (function(_this) {
        return function() {
          return _this.logger.debug(method + " event:onClose");
        };
      })(this));
    };

    ProxyRequest.prototype._onTcpData = function(data, connectPort) {
      var method;
      method = "ProxyRequest._onTcpData " + this.name + " port:" + connectPort;
      this.logger.debug("" + method);
      if (this.connections[connectPort] == null) {
        return this.logger.error(method + " connection not found");
      } else {
        return this._getCurrentDynRequest(connectPort).then((function(_this) {
          return function(dynRequest) {
            return dynRequest.sendRequest([_this.parser.encode(_this._createMessageHeader('data', connectPort)), data]);
          };
        })(this)).then((function(_this) {
          return function(reply) {
            var ref, ref1, status;
            status = reply[0][0];
            if (status.status !== 'OK') {
              _this.logger.error(method + " status: " + status.status);
              return (ref = _this.connections[connectPort]) != null ? (ref1 = ref.socket) != null ? ref1.end() : void 0 : void 0;
            }
          };
        })(this)).fail((function(_this) {
          return function(err) {
            var ref, ref1;
            _this.logger.error(method + " err: " + err.stack);
            return (ref = _this.connections[connectPort]) != null ? (ref1 = ref.socket) != null ? ref1.end() : void 0 : void 0;
          };
        })(this));
      }
    };

    ProxyRequest.prototype._onChannelData = function(header, data, connectPort) {
      var method;
      method = "ProxyRequest._onChannelData " + this.name + " port:" + connectPort;
      this.logger.debug("" + method);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          var err;
          try {
            _this.connections[connectPort].socket.write(data);
            return resolve(['ACK']);
          } catch (error) {
            err = error;
            _this.logger.error(method + " catch error: " + err.stack);
            return reject(err);
          }
        };
      })(this));
    };

    ProxyRequest.prototype._onTcpEnd = function(connectPort) {
      var method;
      method = "ProxyRequest._onTcpEnd " + this.name + " port:" + connectPort;
      this.logger.debug("" + method);
      if (this.connections[connectPort] != null) {
        return this._getCurrentDynRequest(connectPort).then((function(_this) {
          return function(dynRequest) {
            return dynRequest.sendRequest([_this.parser.encode(_this._createMessageHeader('disconnected', connectPort))]);
          };
        })(this)).then((function(_this) {
          return function(reply) {
            var status;
            status = reply[0][0];
            if (status.status !== 'OK') {
              return _this.logger.error(method + " status: " + status.status);
            }
          };
        })(this)).fail((function(_this) {
          return function(err) {
            return _this.logger.error(method + " " + err.stack);
          };
        })(this)).done((function(_this) {
          return function() {
            return delete _this.connections[connectPort];
          };
        })(this));
      }
    };

    ProxyRequest.prototype._onChannelEnd = function(header, connectPort) {
      var method;
      method = "ProxyRequest._onChannelEnd " + this.name + " port:" + connectPort;
      this.logger.debug("" + method);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          var err, ref, ref1;
          try {
            if ((ref = _this.connections[header.connectPort]) != null) {
              if ((ref1 = ref.socket) != null) {
                ref1.end();
              }
            }
            return resolve(['ACK']);
          } catch (error) {
            err = error;
            _this.logger.error(method + " catch error: " + err.stack);
            return reject(err);
          }
        };
      })(this));
    };

    ProxyRequest.prototype._sendConnect = function(connectPort, dynReply) {
      var method;
      method = "ProxyRequest._sendConnect " + this.name + " port:" + connectPort;
      return q.promise((function(_this) {
        return function(resolve, reject) {
          var header;
          _this.logger.debug("" + method);
          header = _this.parser.encode(_this._createMessageHeader('connect', connectPort));
          return _this.channel.sendRequest([header], [dynReply]).then(function(reply) {
            var dynRequest, err, ref, status;
            status = reply[0][0];
            if (status.status === 'OK') {
              if (reply.length > 1 && ((ref = reply[1]) != null ? ref.length : void 0) > 0) {
                _this.logger.debug(method + " resolved");
                dynRequest = reply[1][0];
                _this.connections[connectPort].dynRequest = dynRequest;
                return resolve();
              } else {
                err = new Error("DynRequest not returned");
                _this.logger.error(method + " " + err.stack);
                return reject(err);
              }
            } else {
              _this.logger.error(method + " status=" + status.status);
              return reject(err);
            }
          }).fail(function(err) {
            _this.logger.error(method + " " + err.stack);
            return reject(err);
          });
        };
      })(this));
    };

    ProxyRequest.prototype._getCurrentDynRequest = function(connectPort) {
      return q.promise((function(_this) {
        return function(resolve, reject) {
          return _this.connections[connectPort].dynRequestPromise.then(function() {
            return resolve(_this.connections[connectPort].dynRequest);
          }).fail(function(err) {
            return reject(err);
          });
        };
      })(this));
    };

    ProxyRequest.prototype._createMessageHeader = function(type, connectPort) {
      return {
        type: type,
        fromInstance: this.iid,
        connectPort: connectPort
      };
    };

    return ProxyRequest;

  })();

  module.exports = ProxyRequest;

}).call(this);
//# sourceMappingURL=proxy-request.js.map
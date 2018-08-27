(function() {
  var ProxyReply, ipUtils, net, q, util,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  net = require('net');

  q = require('q');

  ipUtils = require('./ip-utils');

  util = require('./util');

  ProxyReply = (function() {
    function ProxyReply(owner, role, iid1, channel, bindPorts, parser) {
      var method;
      this.owner = owner;
      this.role = role;
      this.iid = iid1;
      this.channel = channel;
      this.bindPorts = bindPorts;
      this.parser = parser;
      this._onTcpEnd = bind(this._onTcpEnd, this);
      this._onTcpData = bind(this._onTcpData, this);
      this._handleRequest = bind(this._handleRequest, this);
      method = 'ProxyReply.constructor';
      if (this.logger == null) {
        this.logger = util.getLogger();
      }
      if ((!Array.isArray(this.bindPorts)) || (this.bindPorts.length > 1)) {
        throw new Error(method + ". Last parameter should be an array with a single port");
      }
      this.bindIp = ipUtils.getIpFromIid(this.iid);
      this.name = this.role + "/" + this.iid + "/" + this.channel.name + "/" + this.bindIp + ":" + this.bindPorts;
      this.bindPort = this.bindPorts[0];
      this.connectOptions = {
        host: this.bindIp,
        port: this.bindPort
      };
      this.logger.info(method + " " + this.name);
      this.connections = {};
      this.channel.handleRequest = this._handleRequest;
    }

    ProxyReply.prototype.init = function() {
      var method;
      method = "ProxyReply.init " + this.name;
      this.logger.info("" + method);
      return q();
    };

    ProxyReply.prototype.terminate = function() {
      var connection, iid, instance, method, port, ref;
      method = "ProxyReply.terminate " + this.name;
      this.logger.info("" + method);
      ref = this.connections;
      for (iid in ref) {
        instance = ref[iid];
        for (port in instance) {
          connection = instance[port];
          connection.socket.end();
        }
      }
      return q();
    };

    ProxyReply.prototype._handleRequest = function(arg, arg1) {
      var dynRequest, header, method;
      header = arg[0];
      dynRequest = arg1[0];
      method = "ProxyReply._handleRequest " + this.name;
      this.logger.debug("" + method);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          var connectPort, err, iid, onConnectError, ref, socket;
          try {
            header = _this.parser.decode(header);
            if (header.type !== 'connect') {
              return reject(new Error("Unexpected request type=" + header.type));
            } else {
              iid = header.fromInstance;
              connectPort = header.connectPort;
              if (((ref = _this.connections[iid]) != null ? ref[connectPort] : void 0) != null) {
                throw new Error("Port " + iid + "/" + connectPort + " already exists");
              }
              onConnectError = function(err) {
                return reject(err);
              };
              socket = net.connect(_this.connectOptions);
              socket.once('error', onConnectError);
              return socket.once('connect', function() {
                var conn, dynReply, parent;
                method = method + " port:" + connectPort;
                socket.removeListener('error', onConnectError);
                dynReply = _this.channel.runtimeAgent.createChannel();
                if (_this.connections[iid] == null) {
                  _this.connections[iid] = {};
                }
                conn = {
                  iid: iid,
                  connectPort: connectPort,
                  socket: socket,
                  dynRequest: dynRequest,
                  dynReply: dynReply
                };
                _this.connections[iid][connectPort] = conn;
                socket.on('data', function(data) {
                  return _this._onTcpData(data, conn);
                });
                socket.on('end', function() {
                  return _this._onTcpEnd(conn);
                });
                socket.on('error', function(err) {
                  _this.logger.error(method + " event:onError " + err.stack);
                  return socket.end();
                });
                socket.on('timeout', function() {
                  _this.logger.error(method + " event:onTimeout");
                  return socket.end();
                });
                socket.on('close', function() {
                  return _this.logger.debug(method + " event:onClose");
                });
                parent = _this;
                dynReply.handleRequest = function(arg2) {
                  var data, err, header;
                  header = arg2[0], data = arg2[1];
                  header = this.parser.decode(header);
                  if (header.type === 'data') {
                    return parent._onChannelData(header, data);
                  } else if (header.type === 'disconnected') {
                    return parent._onChannelEnd(header);
                  } else {
                    err = new Error("Unexpected request type=" + header.type);
                    this.logger.error(method + " err:" + err.message);
                    return q(err);
                  }
                };
                return resolve([['ACK'], [dynReply]]);
              });
            }
          } catch (error) {
            err = error;
            _this.logger.error(method + " catch error: " + err.stack);
            return reject(err);
          }
        };
      })(this));
    };

    ProxyReply.prototype._onTcpData = function(data, conn) {
      var dynRequest, method;
      method = "ProxyReply._onTcpData " + this.name;
      this.logger.debug(method + " port:" + conn.connectPort);
      dynRequest = conn.dynRequest;
      if (dynRequest != null) {
        return dynRequest.sendRequest([this.parser.encode(this._createMessageHeader('data', conn.connectPort)), data]).then((function(_this) {
          return function(reply) {
            var status;
            status = reply[0][0];
            if (status.status !== 'OK') {
              _this.logger.error(method + " status: " + status.status);
              return socket.end();
            }
          };
        })(this)).fail((function(_this) {
          return function(err) {
            return _this.logger.error(method + " " + err.stack);
          };
        })(this));
      } else {
        this.logger.error(method + " dynRequest not found");
        return socket.end();
      }
    };

    ProxyReply.prototype._onChannelData = function(header, data, socket) {
      var method;
      method = "ProxyReply._onChannelData " + this.name;
      this.logger.debug("" + method);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          var connectPort, err, iid;
          try {
            iid = header.fromInstance;
            connectPort = header.connectPort;
            _this.connections[iid][connectPort].socket.write(data);
            return resolve(['ACK']);
          } catch (error) {
            err = error;
            _this.logger.error(method + " catch error: " + err.stack);
            return reject(err);
          }
        };
      })(this));
    };

    ProxyReply.prototype._onTcpEnd = function(conn) {
      var dynRequest, method;
      method = "ProxyReply._onTcpEnd " + this.name + " port:" + conn.connectPort;
      this.logger.debug("" + method);
      dynRequest = conn.dynRequest;
      if (dynRequest != null) {
        return dynRequest.sendRequest([this.parser.encode(this._createMessageHeader('disconnected', conn.connectPort))]).then((function(_this) {
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
            return delete _this.connections[conn.iid][conn.connectPort];
          };
        })(this));
      }
    };

    ProxyReply.prototype._onChannelEnd = function(header, connectPort) {
      var method;
      method = "ProxyReply._onChannelEnd " + this.name + " port:" + header.connectPort;
      this.logger.debug("" + method);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          var err, iid, socket;
          try {
            iid = header.fromInstance;
            connectPort = header.connectPort;
            socket = _this.connections[iid][connectPort].socket;
            if (socket != null) {
              socket.end();
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

    ProxyReply.prototype._createMessageHeader = function(type, connectPort) {
      return {
        type: type,
        fromInstance: this.iid,
        connectPort: connectPort
      };
    };

    return ProxyReply;

  })();

  module.exports = ProxyReply;

}).call(this);
//# sourceMappingURL=proxy-reply.js.map
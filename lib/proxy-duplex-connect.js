(function() {
  var DuplexConnectPort, ProxyDuplexConnect, _, ipUtils, q, util,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  q = require('q');

  _ = require('lodash');

  ipUtils = require('./ip-utils');

  DuplexConnectPort = require('./duplex-connect-port');

  util = require('./util');

  ProxyDuplexConnect = (function() {
    function ProxyDuplexConnect(owner, role, iid, channel, ports, parser) {
      var method;
      this.owner = owner;
      this.role = role;
      this.iid = iid;
      this.channel = channel;
      this.ports = ports;
      this.parser = parser;
      this._onConnectDisconnect = bind(this._onConnectDisconnect, this);
      this._onConnectData = bind(this._onConnectData, this);
      this._onMessage = bind(this._onMessage, this);
      this._onChangeMembership = bind(this._onChangeMembership, this);
      this.name = this.role + "/" + this.iid + "/" + this.channel.name;
      if (this.logger == null) {
        this.logger = util.getLogger();
      }
      method = "ProxyDuplexConnect.constructor " + this.name;
      this.logger.info(method);
      this.bindIp = ipUtils.getIpFromIid(this.iid);
      this.connectPorts = {};
      this.currentMembership = {};
    }

    ProxyDuplexConnect.prototype.init = function() {
      var method;
      method = "ProxyDuplexConnect.init " + this.name;
      this.logger.info(method);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          _this.channel.on('changeMembership', _this._onChangeMembership);
          _this.channel.on('message', _this._onMessage);
          return _this.channel.getMembership().then(function(members) {
            resolve();
            return process.nextTick(function() {
              return _this._onChangeMembership(members);
            });
          }).fail(function(err) {
            return reject(err);
          });
        };
      })(this));
    };

    ProxyDuplexConnect.prototype.terminate = function() {
      var method;
      method = "ProxyDuplexConnect.terminate " + this.name;
      this.logger.info(method);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          var key, port, promises, ref;
          promises = [];
          ref = _this.connectPorts;
          for (key in ref) {
            port = ref[key];
            promises.push(port.terminate());
          }
          return q.all(promises).then(function() {
            return resolve();
          });
        };
      })(this));
    };

    ProxyDuplexConnect.prototype._onChangeMembership = function(newMembership) {
      var method, newIds;
      method = "ProxyDuplexConnect._onChangeMembership " + this.name;
      newIds = this._getIdFromMembership(newMembership);
      this.logger.info(method + " newMembership=" + newIds);
      return this.currentMembership = _.cloneDeep(newMembership);
    };

    ProxyDuplexConnect.prototype._onMessage = function(segments) {
      var connectPort, data, id, method, msg;
      method = "ProxyDuplexConnect._onMessage " + this.name;
      msg = this.parser.decode(segments[0]);
      id = msg.fromInstance + ":" + msg.bindPort + ":" + msg.connectPort;
      this.logger.debug(method + " type=" + msg.type + " id=" + id);
      switch (msg.type) {
        case 'bindOnConnect':
          return this._createConnectPort(id, msg).fail((function(_this) {
            return function(err) {
              var message;
              _this.logger.error(method + " " + msg.type + " error = " + err.message);
              message = _this._createMessageSegment('connectOnDisconnect', {
                remoteMember: msg.fromInstance,
                bindPort: msg.bindPort,
                connectPort: msg.connectPort
              });
              return _this._send(message, null, msg.fromInstance);
            };
          })(this));
        case 'bindOnData':
          data = segments[1];
          connectPort = this.connectPorts[id];
          if (connectPort != null) {
            this.logger.debug(method + " " + msg.type + " send msg");
            return connectPort.send(new Buffer(data));
          } else {
            return this.logger.error(method + " " + msg.type + " error = connectPort doesnt exists}");
          }
          break;
        case 'bindOnDisconnect':
          return this._deleteConnectPort(id);
        default:
          return this.logger.warn(method + " Unexpected msg type " + msg.type);
      }
    };

    ProxyDuplexConnect.prototype._onConnectData = function(event) {
      var message;
      message = this._createMessageSegment('connectOnData', event);
      return this._send(message, event.data, event.remoteIid);
    };

    ProxyDuplexConnect.prototype._onConnectDisconnect = function(event) {
      var id, message;
      id = event.remoteIid + ":" + event.bindPort + ":" + event.connectPort;
      this._deleteConnectPort(id);
      message = this._createMessageSegment('connectOnDisconnect', event);
      return this._send(message, null, event.remoteIid);
    };

    ProxyDuplexConnect.prototype._createConnectPort = function(id, msg) {
      return q.promise((function(_this) {
        return function(resolve, reject) {
          var port;
          if (_this.connectPorts[id] != null) {
            return resolve(_this.connectPorts[id]);
          } else {
            port = new DuplexConnectPort(_this.iid, msg.fromInstance, _this.bindIp, msg.bindPort, msg.connectPort);
            _this.connectPorts[id] = port;
            return port.init().then(function() {
              port.on('connectOnData', _this._onConnectData);
              port.on('connectOnDisconnect', _this._onConnectDisconnect);
              _this.connectPorts[id] = port;
              return resolve(port);
            }).fail(function(err) {
              delete _this.connectPorts[id];
              return reject(err);
            });
          }
        };
      })(this));
    };

    ProxyDuplexConnect.prototype._deleteConnectPort = function(id) {
      if (this.connectPorts[id] != null) {
        this.connectPorts[id].terminate();
        return delete this.connectPorts[id];
      }
    };

    ProxyDuplexConnect.prototype._createMessageSegment = function(type, event) {
      return {
        type: type,
        fromInstance: this.iid,
        toInstance: event.remoteIid,
        bindPort: event.bindPort,
        connectPort: event.connectPort
      };
    };

    ProxyDuplexConnect.prototype._send = function(message, data, remoteIid) {
      var aux, target;
      target = this.currentMembership.find(function(m) {
        return m.iid === remoteIid;
      });
      if (target != null) {
        aux = [this.parser.encode(message)];
        if (data != null) {
          aux.push(data);
        }
        return this.channel.send(aux, target);
      } else {
        return this.logger.error("ProxyDuplexConnect._send " + this.name + " remoteMember not found for " + remoteIid);
      }
    };

    ProxyDuplexConnect.prototype._getIdFromMembership = function(membership) {
      var i, len, list, member;
      list = [];
      for (i = 0, len = membership.length; i < len; i++) {
        member = membership[i];
        list.push(member.iid);
      }
      return list;
    };

    ProxyDuplexConnect._loggerDependencies = function() {
      return [DuplexConnectPort];
    };

    return ProxyDuplexConnect;

  })();

  module.exports = ProxyDuplexConnect;

}).call(this);
//# sourceMappingURL=proxy-duplex-connect.js.map
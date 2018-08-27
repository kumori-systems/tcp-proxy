(function() {
  var DuplexBindPort, ProxyDuplexBind, Semaphore, _, q, util,
    bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  q = require('q');

  _ = require('lodash');

  DuplexBindPort = require('./duplex-bind-port');

  Semaphore = require('./semaphore');

  util = require('./util');

  ProxyDuplexBind = (function() {
    function ProxyDuplexBind(owner, role, iid1, channel, ports1, parser) {
      var method;
      this.owner = owner;
      this.role = role;
      this.iid = iid1;
      this.channel = channel;
      this.ports = ports1;
      this.parser = parser;
      this._bindOnDisconnect = bind(this._bindOnDisconnect, this);
      this._bindOnData = bind(this._bindOnData, this);
      this._bindOnConnect = bind(this._bindOnConnect, this);
      this._onMessage = bind(this._onMessage, this);
      this._onChangeMembership = bind(this._onChangeMembership, this);
      this.name = this.role + "/" + this.iid + "/" + this.channel.name + "/[" + this.ports + "]";
      if (this.logger == null) {
        this.logger = util.getLogger();
      }
      method = "ProxyDuplexBind.constructor " + this.name;
      this.logger.info(method);
      if (!Array.isArray(this.ports)) {
        throw new Error(method + ". Last parameter should be an array of ports");
      }
      this.bindPorts = {};
      this.currentMembership = [];
      this.changeMemberSemaphore = new Semaphore();
    }

    ProxyDuplexBind.prototype.init = function() {
      var method;
      method = "ProxyDuplexBind.init " + this.name;
      this.logger.info(method);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          _this.channel.on('changeMembership', _this._onChangeMembership);
          _this.channel.on('message', _this._onMessage);
          return _this.channel.getMembership().then(function(members) {
            resolve();
            return setImmediate(function() {
              return _this._onChangeMembership(members);
            });
          }).fail(function(err) {
            return reject(err);
          });
        };
      })(this));
    };

    ProxyDuplexBind.prototype.terminate = function() {
      var method;
      method = "ProxyDuplexBind.terminate " + this.name;
      this.logger.info(method);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          var bindPort, iid, port, ports, promises, ref;
          promises = [];
          ref = _this.bindPorts;
          for (iid in ref) {
            ports = ref[iid];
            for (port in ports) {
              bindPort = ports[port];
              promises.push(bindPort.terminate());
            }
          }
          return q.all(promises).then(function() {
            return resolve();
          }).fail(function(err) {
            return reject(err);
          });
        };
      })(this));
    };

    ProxyDuplexBind.prototype._onChangeMembership = function(newMembership) {
      var method, newIds;
      method = "ProxyDuplexBind._onChangeMembership " + this.name;
      newIds = this._getIdFromMembership(newMembership);
      this.logger.info(method + " newMembership=" + newIds);
      return this.changeMemberSemaphore.enter(method, this, function() {
        var createMembers, currentIds, deleteMembers, result;
        currentIds = this._getIdFromMembership(this.currentMembership);
        createMembers = _.difference(newIds, currentIds);
        deleteMembers = _.difference(currentIds, newIds);
        this.currentMembership = _.cloneDeep(newMembership);
        result = q();
        createMembers.forEach((function(_this) {
          return function(iid) {
            if (iid !== _this.iid) {
              return result = result.then(function() {
                return _this._createMember(iid);
              });
            }
          };
        })(this));
        deleteMembers.forEach((function(_this) {
          return function(iid) {
            if (iid !== _this.iid) {
              return result = result.then(function() {
                return _this._deleteMember(iid);
              });
            }
          };
        })(this));
        return result.then((function(_this) {
          return function() {
            var bindPort, iid, params, port, ports, ref;
            params = {
              channel: _this.channel.name,
              members: []
            };
            ref = _this.bindPorts;
            for (iid in ref) {
              ports = ref[iid];
              for (port in ports) {
                bindPort = ports[port];
                params.members.push({
                  iid: iid,
                  port: bindPort.port,
                  ip: bindPort.ip
                });
              }
            }
            return _this.owner.emit('change', params);
          };
        })(this)).fail((function(_this) {
          return function(err) {
            return _this.logger.error(method + " " + err.stack);
          };
        })(this));
      });
    };

    ProxyDuplexBind.prototype._createMember = function(iid) {
      var bindPort, error, fn, i, len, method, port, promises, ref;
      method = "ProxyDuplexBind._createMember " + this.name + " iid=" + iid;
      this.logger.info(method);
      try {
        promises = [];
        this.bindPorts[iid] = {};
        ref = this.ports;
        fn = (function(_this) {
          return function(bindPort) {
            return promises = bindPort.init().then(function(res, err) {
              if (err != null) {
                _this.logger.error(method + " " + e.stack);
                if (_this.bindPorts[iid] != null) {
                  return delete _this.bindPorts[iid];
                }
              } else {
                bindPort.on('bindOnConnect', _this._bindOnConnect);
                bindPort.on('bindOnData', _this._bindOnData);
                return bindPort.on('bindOnDisconnect', _this._bindOnDisconnect);
              }
            });
          };
        })(this);
        for (i = 0, len = ref.length; i < len; i++) {
          port = ref[i];
          bindPort = new DuplexBindPort(this.iid, iid, port);
          this.bindPorts[iid][port] = bindPort;
          fn(bindPort);
        }
        return q.all(promises);
      } catch (error1) {
        error = error1;
        return q.reject(error);
      }
    };

    ProxyDuplexBind.prototype._deleteMember = function(iid) {
      var method;
      method = "ProxyDuplexBind._deleteMember " + this.name + " iid=" + iid;
      this.logger.info(method);
      return q.promise((function(_this) {
        return function(resolve, reject) {
          var bindPort, port, promises, ref, results;
          promises = [];
          ref = _this.bindPorts[iid];
          results = [];
          for (port in ref) {
            bindPort = ref[port];
            results.push(promises.push(bindPort.terminate().then(function(res, err) {
              if (err != null) {
                _this.logger.error(method + " " + e.stack);
              }
              delete _this.bindPorts[iid];
              return resolve();
            })));
          }
          return results;
        };
      })(this));
    };

    ProxyDuplexBind.prototype._onMessage = function(segments) {
      var data, message, method;
      method = "ProxyDuplexBind._onMessage " + this.name;
      this.logger.debug(method);
      message = this.parser.decode(segments[0]);
      this.logger.debug("ProxyDuplexBind._onMessage " + this.name, message);
      switch (message.type) {
        case 'connectOnData':
          data = segments[1];
          return this._connectOnData(message, data);
        case 'connectOnDisconnect':
          return this._connectOnDisconnect(message);
        default:
          return this.logger.warn(method + " Unexpected message type " + message.type);
      }
    };

    ProxyDuplexBind.prototype._bindOnConnect = function(event) {
      var message;
      message = this._createMessageSegment('bindOnConnect', event);
      return this._send(message, null, event.remoteIid);
    };

    ProxyDuplexBind.prototype._bindOnData = function(event) {
      var message;
      message = this._createMessageSegment('bindOnData', event);
      return this._send(message, event.data, event.remoteIid);
    };

    ProxyDuplexBind.prototype._bindOnDisconnect = function(event) {
      var message;
      message = this._createMessageSegment('bindOnDisconnect', event);
      return this._send(message, null, event.remoteIid);
    };

    ProxyDuplexBind.prototype._connectOnData = function(message, data) {
      var bindPort, method, ref;
      method = "ProxyDuplexBind._connectOnData " + this.name;
      this.logger.debug(method);
      bindPort = (ref = this.bindPorts[message.fromInstance]) != null ? ref[message.bindPort] : void 0;
      if (bindPort != null) {
        return bindPort.send(data, message.connectPort);
      } else {
        return this.logger.error(method + " bindPort not found for " + message.fromInstance + ":" + message.bindPort + ": " + message);
      }
    };

    ProxyDuplexBind.prototype._connectOnDisconnect = function(message) {
      var bindPort, method, ref;
      method = "ProxyDuplexBind._connectOnDisconnect " + this.name;
      this.logger.debug(method);
      bindPort = (ref = this.bindPorts[message.fromInstance]) != null ? ref[message.bindPort] : void 0;
      if (bindPort != null) {
        return bindPort.deleteConnection(message.connectPort);
      } else {
        return this.logger.error(method + " bindPort not found for " + message.fromInstance + ":" + message.bindPort + ": " + message);
      }
    };

    ProxyDuplexBind.prototype._createMessageSegment = function(type, event) {
      return {
        type: type,
        fromInstance: this.iid,
        toInstance: event.remoteIid,
        bindPort: event.bindPort,
        connectPort: event.connectPort
      };
    };

    ProxyDuplexBind.prototype._send = function(message, data, remoteIid) {
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
        return this.logger.error("ProxyDuplexBind._send " + this.name + " remoteMember not found for " + remoteIid);
      }
    };

    ProxyDuplexBind.prototype._getIdFromMembership = function(membership) {
      var i, len, list, member;
      list = [];
      for (i = 0, len = membership.length; i < len; i++) {
        member = membership[i];
        list.push(member.iid);
      }
      return list;
    };

    ProxyDuplexBind._loggerDependencies = function() {
      return [DuplexBindPort];
    };

    return ProxyDuplexBind;

  })();

  module.exports = ProxyDuplexBind;

}).call(this);
//# sourceMappingURL=proxy-duplex-bind.js.map
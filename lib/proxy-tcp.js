(function() {
  var EventEmitter, ProxyDuplexBind, ProxyDuplexConnect, ProxyReceive, ProxyReply, ProxyRequest, ProxySend, ProxyTcp, ipUtils, q, util,
    extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    hasProp = {}.hasOwnProperty;

  EventEmitter = require('events').EventEmitter;

  q = require('q');

  ipUtils = require('./ip-utils');

  ProxyDuplexBind = require('./proxy-duplex-bind');

  ProxyDuplexConnect = require('./proxy-duplex-connect');

  ProxyRequest = require('./proxy-request');

  ProxyReply = require('./proxy-reply');

  ProxySend = require('./proxy-send');

  ProxyReceive = require('./proxy-receive');

  util = require('./util');

  ProxyTcp = (function(superClass) {
    extend(ProxyTcp, superClass);

    function ProxyTcp(iid, role, channels, parser) {
      var a, channel, method, name, promises, ref;
      this.iid = iid;
      this.role = role;
      this.channels = channels;
      a = a;
      method = 'ProxyTcp.constructor';
      if (this.logger == null) {
        this.logger = util.getLogger();
      }
      this.logger.info("" + method);
      if (this.parser == null) {
        this.parser = util.getDefaultParser();
      }
      this._createProxyChannels();
      promises = [];
      ref = this.channels;
      for (name in ref) {
        channel = ref[name];
        promises.push(channel.proxy.init());
      }
      q.all(promises).then((function(_this) {
        return function() {
          return _this.emit('ready', ipUtils.getIpFromIid(_this.iid));
        };
      })(this)).fail((function(_this) {
        return function(err) {
          return _this.emit('error', err);
        };
      })(this));
    }

    ProxyTcp.prototype.shutdown = function() {
      var channel, method, name, promises, ref;
      method = 'ProxyTcp.shutdown';
      this.logger.info("" + method);
      promises = [];
      ref = this.channels;
      for (name in ref) {
        channel = ref[name];
        promises.push(channel.proxy.terminate());
      }
      return q.all(promises).then((function(_this) {
        return function() {
          _this.logger.info(method + " emit close event");
          return _this.emit('close');
        };
      })(this)).fail((function(_this) {
        return function(err) {
          return _this.emit('error', err);
        };
      })(this));
    };

    ProxyTcp.prototype._createProxyChannels = function() {
      var Proxy, channel, config, method, mode, name, ports, ref, results, type;
      method = 'ProxyTcp._createProxyChannels';
      ref = this.channels;
      results = [];
      for (name in ref) {
        config = ref[name];
        this.logger.info(method + " Processing " + name + " channel");
        channel = config.channel;
        type = channel.constructor.name;
        ports = this._getProxyPorts(config);
        mode = config.mode;
        Proxy = null;
        switch (type) {
          case 'Duplex':
            if (mode === 'bind') {
              Proxy = ProxyDuplexBind;
            } else if (mode === 'connect') {
              Proxy = ProxyDuplexConnect;
            } else {
              throw new Error("Proxy for " + name + ": invalid mode " + mode);
            }
            break;
          case 'Request':
            Proxy = ProxyRequest;
            break;
          case 'Reply':
            Proxy = ProxyReply;
            break;
          case 'Send':
            Proxy = ProxySend;
            break;
          case 'Receive':
            Proxy = ProxyReceive;
            break;
          default:
            throw new Error("Proxy for " + name + ": invalid type " + type);
        }
        config.proxy = new Proxy(this, this.role, this.iid, channel, ports, this.parser);
        results.push(this.logger.info(method + " Add " + config.proxy.constructor.name + " to " + name + " channel"));
      }
      return results;
    };

    ProxyTcp.prototype._getProxyPorts = function(config) {
      var error, i, max, message, min, ports, results;
      ports = [];
      try {
        if ((config != null ? config.ports : void 0) != null) {
          ports = config.ports;
        } else if ((config != null ? config.port : void 0) != null) {
          ports = [config.port];
        } else if (((config != null ? config.minPort : void 0) != null) && ((config != null ? config.maxPort : void 0) != null)) {
          min = Number.parseInt(config.minPort);
          max = Number.parseInt(config.maxPort);
          if (min <= max) {
            ports = (function() {
              results = [];
              for (var i = min; min <= max ? i <= max : i >= max; min <= max ? i++ : i--){ results.push(i); }
              return results;
            }).apply(this);
          } else {
            this.logger.error("ProxyTcp.getProxyPorts. Invalid proxy configuration " + config + ": minPort " + min + " > maxPort " + max);
          }
        }
      } catch (error1) {
        error = error1;
        message = (error != null ? error.stack : void 0) != null ? error.stack : error;
        this.logger.error("ProxyTcp.getProxyPorts. Invalid proxy configuration " + config + ": " + message);
      }
      return ports;
    };

    ProxyTcp._loggerDependencies = function() {
      return [ProxyDuplexBind, ProxyDuplexConnect, ProxyRequest, ProxyReply, ProxySend, ProxyReceive];
    };

    return ProxyTcp;

  })(EventEmitter);

  module.exports.ProxyTcp = ProxyTcp;

}).call(this);
//# sourceMappingURL=proxy-tcp.js.map
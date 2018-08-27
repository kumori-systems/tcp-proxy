(function() {
  var ProxyReceive, q, util;

  q = require('q');

  util = require('./util');

  ProxyReceive = (function() {
    function ProxyReceive(owner, role, iid, channel, ports, parser) {
      var method;
      this.owner = owner;
      this.role = role;
      this.iid = iid;
      this.channel = channel;
      this.ports = ports;
      this.parser = parser;
      method = 'ProxyReceive.constructor';
      if (this.logger == null) {
        this.logger = util.getLogger();
      }
      this.logger.info(method + " role=" + this.role + ",iid=" + this.iid + ",channel=" + this.channel.name);
    }

    ProxyReceive.prototype.init = function() {
      var method;
      method = 'ProxyReceive.init';
      this.logger.info("" + method);
      return q.promise(function(resolve, reject) {
        return resolve();
      });
    };

    ProxyReceive.prototype.terminate = function() {
      var method;
      method = 'ProxyReceive.terminate';
      this.logger.info("" + method);
      return q.promise(function(resolve, reject) {
        return resolve();
      });
    };

    return ProxyReceive;

  })();

  module.exports = ProxyReceive;

}).call(this);
//# sourceMappingURL=proxy-receive.js.map
(function() {
  var ProxySend, q, util;

  q = require('q');

  util = require('./util');

  ProxySend = (function() {
    function ProxySend(owner, role, iid, channel) {
      var method;
      this.owner = owner;
      this.role = role;
      this.iid = iid;
      this.channel = channel;
      method = 'ProxySend.constructor';
      if (this.logger == null) {
        this.logger = util.getLogger();
      }
      this.logger.info(method + " role=" + this.role + ",iid=" + this.iid + ",channel=" + this.channel.name);
    }

    ProxySend.prototype.init = function() {
      var method;
      method = 'ProxySend.init';
      this.logger.info("" + method);
      return q.promise(function(resolve, reject) {
        return resolve();
      });
    };

    ProxySend.prototype.terminate = function() {
      var method;
      method = 'ProxySend.terminate';
      this.logger.info("" + method);
      return q.promise(function(resolve, reject) {
        return resolve();
      });
    };

    return ProxySend;

  })();

  module.exports = ProxySend;

}).call(this);
//# sourceMappingURL=proxy-send.js.map
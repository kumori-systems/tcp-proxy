(function() {
  var Semaphore, q;

  q = require('q');

  Semaphore = (function() {
    function Semaphore() {
      this.semaphores = {};
    }

    Semaphore.prototype.enter = function(name, self, func) {
      this.semaphores[name] = this._get(name);
      return q.Promise((function(_this) {
        return function(resolve, reject) {
          return _this.semaphores[name].promise = _this.semaphores[name].promise.then(function() {
            var err, p;
            try {
              p = func.apply(self);
              if ((p != null) && (p.then != null) && (p["catch"] != null)) {
                return p.then(function(value) {
                  _this._release(name);
                  return resolve(value);
                })["catch"](function(err) {
                  _this._release(name);
                  return reject(err);
                });
              } else {
                _this._release(name);
                return resolve(p);
              }
            } catch (error) {
              err = error;
              _this._release(name);
              return reject(err);
            }
          });
        };
      })(this));
    };

    Semaphore.prototype["delete"] = function(name) {};

    Semaphore.prototype.isLocked = function(name) {
      return this.semaphores[name] != null;
    };

    Semaphore.prototype._get = function(name) {
      if (this.semaphores[name] != null) {
        this.semaphores[name].count++;
      } else {
        this.semaphores[name] = {
          promise: q(),
          count: 1
        };
      }
      return this.semaphores[name];
    };

    Semaphore.prototype._release = function(name) {
      if (this.semaphores[name] != null) {
        this.semaphores[name].promise = q();
        this.semaphores[name].count--;
        if (this.semaphores[name].count === 0) {
          return delete this.semaphores[name];
        }
      }
    };

    Semaphore.prototype._debug_isEmpty = function() {
      var k, ref, v;
      ref = this.semaphores;
      for (k in ref) {
        v = ref[k];
        return false;
      }
      return true;
    };

    return Semaphore;

  })();

  module.exports = Semaphore;

}).call(this);
//# sourceMappingURL=semaphore.js.map
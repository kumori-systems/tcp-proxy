
/*
IPs assigned to instances id (format X_Z or X-Z):
  instance X_0 --> 127.0.0.2
  [...]
  instance X_65532 --> 127.0.255.254
  reserved: 127.0.0.1, 127.0.255.255

Pool IPs, based in internal counter:
  counter = 0 --> 127.1.0.1
  [...]
  counter = 65334 --> 127.1.255.255
 */

(function() {
  var COUNT_SEPARATOR_TOKENS, FIRST_IID_IP_RANGE, FIRST_POOL_IP_RANGE, IID_IP_QUANTITY, LAST_IID_IP_RANGE, LAST_POOL_IP_RANGE, POOL_IP_QUANTITY, num2Ip, pool_counter;

  FIRST_IID_IP_RANGE = 2130706434;

  IID_IP_QUANTITY = 65533;

  LAST_IID_IP_RANGE = IID_IP_QUANTITY + FIRST_IID_IP_RANGE - 1;

  FIRST_POOL_IP_RANGE = 2130771968;

  POOL_IP_QUANTITY = 65535;

  LAST_POOL_IP_RANGE = POOL_IP_QUANTITY + FIRST_POOL_IP_RANGE;

  COUNT_SEPARATOR_TOKENS = ['_', '-'];

  num2Ip = function(num) {
    var d, i, j;
    d = num % 256;
    for (i = j = 1; j <= 3; i = ++j) {
      num = Math.floor(num / 256);
      d = (num % 256) + '.' + d;
    }
    return d;
  };

  pool_counter = 0;

  module.exports = {
    getIpFromIid: function(iid) {
      var e, num;
      try {
        num = parseInt(iid.slice(this._getLastTokenIndex(iid) + 1)) + FIRST_IID_IP_RANGE;
        if (num > LAST_IID_IP_RANGE) {
          throw new Error("id must be < " + IID_IP_QUANTITY);
        }
        return num2Ip(num);
      } catch (error) {
        e = error;
        throw new Error("Error generating IP (iid=" + iid + ") : " + e.message);
      }
    },
    getIpFromPool: function() {
      var e, num;
      try {
        num = ++pool_counter + FIRST_POOL_IP_RANGE;
        if (num > LAST_POOL_IP_RANGE) {
          throw new Error("IP's pool is empty");
        }
        return num2Ip(num);
      } catch (error) {
        e = error;
        throw new Error("Error generating IP (pool_counter=" + pool_counter + ") : " + e.message);
      }
    },
    _getLastTokenIndex: function(iid) {
      var index, j, len, token, tokenIndex;
      index = -1;
      for (j = 0, len = COUNT_SEPARATOR_TOKENS.length; j < len; j++) {
        token = COUNT_SEPARATOR_TOKENS[j];
        tokenIndex = iid.lastIndexOf(token);
        if (tokenIndex > index) {
          index = tokenIndex;
        }
      }
      return index;
    },
    __unitTestUtil__: function(value) {
      return pool_counter = value;
    }
  };

}).call(this);
//# sourceMappingURL=ip-utils.js.map
q = require('q')
count = 0
module.exports = function (op, iid, role, channels, params) {
  count++
  return q.promise(function(resolve, reject) {
    aux = ''
    if ((params != null) && (params != undefined)) {
      aux = JSON.stringify(params)
    }
    console.log('--- legacy('+count+'):'+op+' '+iid+' '+role+' '+ aux)
    resolve()
  })
}

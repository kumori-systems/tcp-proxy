const vm = require ('vm');
const fs = require ('fs');
const path = require('path');
const util = require('util')
const exec = util.promisify(require('child_process').exec)

// var pkg = require('./package.json');

var srcpath = path.resolve(__dirname, 'src')
var list = exec('git --git-dir ../.git --work-tree .. ls-files', {cwd: srcpath} )

// Gobble up a JSON file with comments
function getJSON(filepath) {
  const jsonString = "g = " + fs.readFileSync(filepath, 'utf8') + "; g";
  return (new vm.Script(jsonString)).runInNewContext();
}

function * checkGit(file) {
  let srcpath = path.resolve(__dirname, 'src')
  return list.then((value) => {
    const files = value.stdout.split('\n')
    let found = false
    for (let filename of files) {
      if (filename.localeCompare(file.base) == 0) {
        found = true
      }
    }
    if (!found) {
      file.dir = ""
      file.base = ""
    }
  })
}

exports.default = function * (task) {
  yield task.serial(['build']);
}

exports.clean = function * (task) {
  yield task.clear(['coverage']);
}

exports.superclean = function * (task) {
  task.parallel(['clean']);
  yield task.clear(['lib'])
}

exports.mrproper = function * (task) {
  task.parallel(['superclean']);
  yield task.clear(['node_modules'])
}

exports.build = function * (task) {
  let coffeeops = getJSON('./coffeeconfig.json');
  yield task.serial(['superclean'])
    .source('src/**/*.coffee')
    .run({
      every: true,
      files: true
    }, checkGit)
    .coffee(coffeeops)
    .target('lib')
}

exports.test = function * (task) {
  yield task.serial(['build'])
    .source("./tests/**/*.test.coffee")
    .shell({
      cmd: 'mocha --exit --require coffee-script/register --require coffee-coverage/register-istanbul -u bdd --colors --reporter spec $glob',
      preferLocal: true,
      glob: true
    })
}

exports.lint = function * (task) {
  yield task.source('src tests')
    .shell({
      cmd: 'coffeelint $glob',
      preferLocal: true,
      glob: true
    })
}

// exports.mytest = function * (task) {
//   yield task.source("src/**/*.coffee")
//     .run({
//       every: true,
//       files: true
//     }, checkGit)
//     .target('mytest')
// }
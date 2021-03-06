const vm = require ('vm');
const fs = require ('fs');
const path = require('path');
const util = require('util')
const exec = util.promisify(require('child_process').exec)
const c = require('ansi-colors')

// var pkg = require('./package.json');

// Gobble up a JSON file with comments
function getJSON(filepath) {
  const jsonString = "g = " + fs.readFileSync(filepath, 'utf8') + "; g";
  return (new vm.Script(jsonString)).runInNewContext();
}

// This functions checks which of the source files are included in the current
// working tree in the git repository
function * checkGit(sourceFiles) {
  let filesToIgnore = []
  let srcpath = path.resolve(__dirname, 'src')
  // Get the source files in the working tree
  return (exec('git --git-dir ../.git --work-tree .. ls-files', {cwd: srcpath} ).then((value) => {
    if ((value.sderr) && (value.stderr.length > 0)) {
      return Promise.reject(`Error getting the files included in the repository working tree: ${value.stderr}`)
    }
    const workingFiles = value.stdout.split('\n')
    // For each source files, check if it isn't in the working directory.
    for (let index in sourceFiles) {
      let sourceFile = sourceFiles[index]
      let found = false
      for (let workingFile of workingFiles) {
        srcfile = path.resolve(__dirname, sourceFile.dir, sourceFile.base)
        gitfile = path.resolve(srcpath, workingFile)
        if (gitfile.localeCompare(srcfile) == 0) {
          found = true
        }
      }
      if (!found) {
        filesToIgnore.push(index)
      }
    }
    // Remove from the original source files those not included in the
    // working tree. We remove them in reverse order to avoid changing the
    // index of the files to be removed.
    for (let index of filesToIgnore.reverse()) {
      console.log(`File "${path.resolve(sourceFiles[index].dir, sourceFiles[index].base)}" not added to the git repository... ${c.bold.red("IGNORING")}`)
      sourceFiles.splice(index, 1)
    }
  }))
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
      every: false,
      files: true
    }, checkGit)
    .coffee(coffeeops)
    .target('lib')
}

exports.devbuild = function * (task) {
  let coffeeops = getJSON('./coffeeconfig.json');
  yield task.serial(['superclean'])
    .source('src/**/*.coffee')
    .coffee(coffeeops)
    .target('lib')
}

exports.test = function * (task) {
  yield task.serial(['devbuild'])
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
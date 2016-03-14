q = require 'q'

# TBD: MOVE TO SLAP-UTIL PROJECT

# This class prevents (using promises) that multiple async-PROMISE operations
# will be interleaved.
# BE CAREFUL: this class doesn't works fine for async-callback functions...
#             only for q-promise async functions.
#
# A semaphore object allows us to manage multiple promise-semaphores, which are
# identified by the name used in the "enter" method.
# A promise-semaphore is created the first time is called its "enter" method
# (identified by a name).
#
# If a promise-semaphore is not going to be used anymore, it can be removed with
# the "delete" method.
#
# If is better don't wait when semaphore is locked, method "isLocked" can be
# used.
#
# Example:
#
#   Semaphore = require './semaphore'
#   q = require 'q'
#
#   semaphore = new Semaphore()
#
#   myFuncAsync = (value) ->
#     return q.Promise (resolve, reject) ->
#       setTimeout () ->
#         console.log value
#         resolve value*2
#       , 1000
#
#   myFuncSync = (value) ->
#     console.log value
#     return value*2
#
#   doWorkAsync = (value) ->
#     semaphore.enter "test", this, () ->  # >>> we use semaphore
#       myFuncAsync(value)
#       .then (value) ->
#         myFuncAsync(value)
#       .then (value) ->
#         myFuncAsync(value)
#       .then (value) ->
#         myFuncSync(value)  # >>> sync function... dont worry.
#       .fail (err) ->
#         console.log err.message
#
#   # Both executions will be executed, but not be interleaved
#   doWorkAsync(1)   # prints "1,2,4,8"
#   doWorkAsync(10)  # prints "10,20,40,80"
#
#   # This execution will not be executed, because semaphore is locked and we
#   # dont want wait (in this case)
#   if not semaphore.isLocked("test") then doWorkAsync(20) # prints nothing
#   else console.log "Work not executed"
#
#   # This execution will be executed, because semaphore will not be locked
#   # after 10 seconds
#   setTimeout () ->
#     if not semaphore.isLocked("test")
#       doWorkAsync(30)  # prints "30,60,120,240"
#   , 10000
#
#
class Semaphore

  constructor: () ->
    @semaphores = {}

  enter: (name, self, func) ->
    return q.Promise (resolve, reject) =>
      @semaphores[name] = @_get name
      @semaphores[name].promise = @semaphores[name].promise.then () =>
        try
          p = func.apply self
          if p? and p.then? and p.fail?
            p.then (value) =>
              @_release name
              resolve value
            .fail (err) =>
              @_release name
              reject err
          else
            @_release name
            resolve p
        catch err
          @_release name
          reject err

  delete: (name) ->
    delete @semaphores[name]

  isLocked: (name) ->
    if @semaphores[name]? then return @semaphores[name].locked
    return false

  _get: (name) ->
    if not @semaphores[name]?
      @semaphores[name] = {
        promise: q()
        locked: true
      }
    return @semaphores[name]

  _release: (name) ->
    if @semaphores[name]?
      @semaphores[name].promise = q()
      @semaphores[name].locked = false

module.exports = Semaphore



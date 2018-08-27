q = require 'q'

# This class prevents (using promises) that multiple async-PROMISE operations
# will be interleaved.
# BE CAREFUL: this class doesn't works fine for async-callback functions...
#             only for q-promise async functions.
#             JS-6 promises : not tested.
#
# A semaphore object allows us to manage multiple promise-semaphores, which are
# identified by the name used in the "enter" method.
# A promise-semaphore is created the first time is called its "enter" method
# (identified by a name).
#
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
# ** DEPRECATED *** (current version is auto-deleted)
# If a promise-semaphore is not going to be used anymore, it can be removed with
# the "delete" method.
#
class Semaphore


  constructor: () ->
    @semaphores = {}


  enter: (name, self, func) ->
    @semaphores[name] = @_get name
    return q.Promise (resolve, reject) =>
      @semaphores[name].promise = @semaphores[name].promise.then () =>
        try
          p = func.apply self
          if p? and p.then? and p.catch?
            p.then (value) =>
              @_release name
              resolve value
            .catch (err) =>
              @_release name
              reject err
          else
            @_release name
            resolve p
        catch err
          @_release name
          reject err


  delete: (name) ->
    # Deprecated. Do nothing


  isLocked: (name) ->
    return @semaphores[name]?


  _get: (name) ->
    if @semaphores[name]?
      @semaphores[name].count++
    else
      @semaphores[name] = {
        promise: q()
        count: 1
      }
    return @semaphores[name]


  _release: (name) ->
    if @semaphores[name]?
      @semaphores[name].promise = q()
      @semaphores[name].count--
      if @semaphores[name].count is 0 then delete @semaphores[name]


  # Just for debug memory leaks!
  _debug_isEmpty: () ->
    for  k,v of @semaphores
      return false
    return true


module.exports = Semaphore

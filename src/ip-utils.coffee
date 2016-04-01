###
IPs assigned to instances id (format X_Z):
  instance X_0 --> 127.0.0.2
  [...]
  instance X_65532 --> 127.0.255.254
  reserved: 127.0.0.1, 127.0.255.255

Pool IPs, based in internal counter:
  counter = 0 --> 127.1.0.1
  [...]
  counter = 65334 --> 127.1.255.255
###

FIRST_IID_IP_RANGE = 2130706434  # 127.0.0.2
IID_IP_QUANTITY = 65533
LAST_IID_IP_RANGE = IID_IP_QUANTITY+FIRST_IID_IP_RANGE-1 # 127.0.255.254

FIRST_POOL_IP_RANGE = 2130771968 # 127.1.0.1
POOL_IP_QUANTITY = 65535
LAST_POOL_IP_RANGE = POOL_IP_QUANTITY+FIRST_POOL_IP_RANGE # 127.1.255.255


num2Ip = (num) ->
  d = num%256
  for i in [1..3]
    num = Math.floor(num / 256)
    d = (num % 256) + '.' + d
  return d

pool_counter = 0

module.exports =

  getIpFromIid: (iid) ->
    try
      num = parseInt(iid[iid.lastIndexOf('_')+1..]) + FIRST_IID_IP_RANGE
      if num > LAST_IID_IP_RANGE
        throw new Error "id must be < #{IID_IP_QUANTITY}"
      return num2Ip num
    catch e
      throw new Error "Error generating IP (iid=#{iid}) : #{e.message}"

  getIpFromPool: () ->
    try
      num = ++pool_counter + FIRST_POOL_IP_RANGE
      if num > LAST_POOL_IP_RANGE
        throw new Error "IP's pool is empty"
      return num2Ip num
    catch e
      throw new Error "Error generating IP (pool_counter=#{pool_counter}) : \
                       #{e.message}"

  __unitTestUtil__: (value) ->
    pool_counter = value

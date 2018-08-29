[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)

# Tcp Proxy

Proxy for tunneling TCP connection through Kumori's platform channels

## Description

This module proxifies a legacy tcp server connections through Kumori's channels (see [Kumori's documentation](https://github.com/kumori-systems/documentation) for more information about channels and Kumori's _service application model_).


## Table of Contents

* [Installation](#installation)
* [Usage](#usage)
* [License](#license)

## Installation

Install it as a npm package

    npm install -g @kumori/tcp-proxy

## Usage

In general, we may have situations in which a component functionality is
actually provided by an existing server program, expecting access to IP
networks, and such that it is either costly, impractical or outright impossible
to carry out any sort of change in their code.

As was the case of the
[Http Proxy](https://github.com/kumori-systems/http-proxy), the component should
be properly specified, with the channels that make sense to how it is to be
connected, and the configuration needed for semantically consistent set up of
the legacy server.

Besides this configuration, however, we will need a way to convert the IP-based
configuration directly supported by the legacy server to interact with
other roles within the deployed service.

Just as in the case of the web server, the approach will require the component
module to act as an adapter, launching the legacy server to interact with the
+localhost+ network interface, through adequate network ports.

Unlike the case of the legacy web server, we now can have an arbitrary protocol
being spoken by the legacy server, thus we need a "neutral" solution. For
this case {ecloud} provides a *@kumori/tcp-proxy* module that can be used by the
adapter/component to tunnel IP protocols through {ecloud} channels transparently
to the legacy server code.

In this case, the channel protocol knows nothing about the higher level
protocol supported by the server, limiting itself to ship the bytes being
pushed back and forth by legacy pieces of software.

The following shows an example of how to generally set up this kind of legacy
support.

```coffeescript
Component = require 'component'
TcpProxy = require('@kumori/tcp-proxy').TcpProxy  #<1>
child = require 'child-process'

module.exports = class MyComponent extends Component
  ...
  run: () ->
    [server, parameters, channels] = @computeServerParametersAndChannels() #<2>

    @proxy = new TcpProxy @iid, @role, channels      #<3>

    @proxy.on 'ready', (@bindIp) =>                  #<4>
      @startLegacyServer server, bindIp, parameters

    @proxy.on 'error', (err) =>                      #<5>
      @processProxyError err

    @proxy.on 'change', (data) =>                    #<6>
      @reconfigLegacyServer server, bindIp, parameters, data

    @proxy.on 'close', () =>                         #<7>
      @stopLegacyServer server, parameters

  shutdown: ->
    @proxy.shutdown()                                #<8>
  ...
```

1. We now require the generic *@kumori/tcp-proxy* module.
2. Assuming method *computeServerParametersAndChannels* returns as in
    Http Proxy the server program and parameters to pass to it. But,
    in addition, it returns an object relating the component's channels to the
    legacy server ports/connections/bindings.
3. *TcpProxy* object initialization requires the role and ID of the instance,
    and the list of channels (with additional information) to be proxied.
4. *TcpProxy* object issues an event when it is ready to process requests,
    providing the local IP address to be assigned to the legacy server.
    For *TcpProxy* to function properly, legacy server must be bound to that
    IP.
5. *TcpProxy* object issues an event when an error occurs.
6. *TcpProxy* object issues an event, during its life cycle, when any change
    occurs that should result in a reconfiguration of the legacy server.
7. *TcpProxy* object issues an event when it's closed.
8. *TcpProxy* object finalization.

While method *computeServerParameters* is straightforward to write, needing only
to know how to start the legacy server, writing method
*computeServerParametersAndChannels* will require knowing how to configure
the *TcpProxy* object too.

### Configuring the TcpProxy object

*TcpProxy* object initialization requires an object relating the component's
channels to the legacy server ports/connections/bindings.

This object is a dictionary whose key is the channel name, and values contains:

- A reference to the channel object
- TCP port to be proxied
- In case of duplex channels, its operating mode (bind/connect)

Example configuration for a *TcpProxy* that proxies four channels:

```json
{
  'myDuplex1': {
    channel: myDuplex1,
    port: 9100,
    mode: 'bind'
  },
  'myDuplex2': {
    channel: myDuplex2,
    port: 9100,
    mode: 'connect'
  },
  'myRequest3': {
    channel: myRequest3,
    port: 9200
  },
  'myReply4': {
    channel: myReply4,
    port: 9200
  }
}
```

### Ready event

When *TcpProxy* object is ready to process requests, a 'ready' event is
emitted,

Data associated with this event is the local IP address to be used by the
legacy server.

Typically, this IP address is used when starting the legacy server with
duplex/bind or a reply channels.
Typically, this information is not used with duplex/connect or a request
channels.

```coffeescript
@proxy.on 'ready', (bindIp) =>
  @_startLegacyServer bindIp, ...
```

### Error event

*TcpProxy* object can issue error events, basically during the creation of
internal connections initializing the proxy.

```coffeescript
@proxy.on 'error', (err) =>
  ...
```

### Change event

During its life cycle, *TcpProxy* object emits `change` events when any change
occurs, which may result in a reconfiguration of the legacy server.

Data associated with this event will vary depending on the channel that caused
it.

```coffeescript
@proxy.on 'change', (data) ->
  @reconfigLegacyServer server, bindIp, parameters, data
```


#### Request

When a request channel is proxied, a TCP port is opened in a local IP address.
A `change` event is issued when *TcpProxy* is ready and listening on this
port. An event is issued too, when the port is closed (this happens when the
instance is shutting down, so usually an action on the legacy server is not
required). Event data contains parameters that legacy server could need to be
reconfigured:
- Listening (true/false)
- Channel name
- IP
- Port

For example:

```coffeescript
{
  channel: 'myRequest3',
  listening: true,
  ip: ip:'127.0.0.7',
  port: 9300
}
```

#### Reply

Never issues `change` events.

#### Duplex

When the set of instances attached to the _complete_ connector (duplex
channels) changes, *TcpProxy* issues a `change` event.
Event data is a list of current members with the information that the legacy
server could need to be reconfigured:
- Channel name
- Instance ID
- IP
- Port

For example:

```coffeescript
{
  channel: 'myDuplex1',
  members: [
    {iid:'A_10', ip:'127.0.0.7', port:9100},
    {iid:'A_11', ip:'127.0.0.8', port:9100},
    {iid:'A_12', ip:'127.0.0.9', port:9100}
  ]
]
```

### Close event

After *TcpProxy.shutdown()* method is invoked, a 'close' event is emitted when
operation is finished.

```coffeescript
@proxy.on 'close', () =>
  ...
```

## License

MIT © Kumori Systems
import { EventEmitter } from 'events'
import { Parser } from './util'

interface Channels {
    [key: string]: any
}

export declare class ProxyTcp extends EventEmitter {

    constructor(iid: string, role: string, channels: Channels, parser?: Parser)

    shutdown(): void
}
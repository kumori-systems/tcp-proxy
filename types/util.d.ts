export declare class Parser {
    encode(text: string): string
    decode(text: string): string
}

export declare class Logger {
    error(text: string): void;
    warn(text: string): void;
    info(text: string): void;
    debug(text: string): void;
    silly(text: string): void;
}

export declare function getDefaultParser(): Parser;

export declare function getDefaultLogger(): Logger;
import type { LoggerService, LogLevel } from "@nestjs/common";

import Logger from "./Logger.js";

type Method = "trace" | "debug" | "info" | "warn" | "error" | "fatal";

const logLevelValues: Record<LogLevel, number> = {
    verbose: 0,
    debug: 1,
    log: 2,
    warn: 3,
    error: 4,
    fatal: 5,
};

/** A Nest system logger that preserves Nest contexts and literal route braces. */
export default class NestLogger implements LoggerService {
    readonly #loggers = new Map<string, Logger>();
    #levels = new Set<LogLevel>(["verbose", "debug", "log", "warn", "error", "fatal"]);

    log(message: unknown, ...optionalParams: unknown[]): void {
        if (this.#isLevelEnabled("log")) this.#write("info", message, optionalParams);
    }

    error(message: unknown, ...optionalParams: unknown[]): void {
        if (!this.#isLevelEnabled("error")) return;

        const { context, messages, stack } = splitErrorArguments(message, optionalParams);
        const logger = this.#forContext(context);
        for (const item of messages) {
            if (item instanceof Error) logger.error(item);
            else if (stack == null) logger.error(item);
            else {
                const error = new Error(typeof item === "string" ? item : String(item));
                error.stack = stack;
                logger.error(error);
            }
        }
    }

    warn(message: unknown, ...optionalParams: unknown[]): void {
        if (this.#isLevelEnabled("warn")) this.#write("warn", message, optionalParams);
    }

    debug(message: unknown, ...optionalParams: unknown[]): void {
        if (this.#isLevelEnabled("debug")) this.#write("debug", message, optionalParams);
    }

    verbose(message: unknown, ...optionalParams: unknown[]): void {
        if (this.#isLevelEnabled("verbose")) this.#write("debug", message, optionalParams);
    }

    fatal(message: unknown, ...optionalParams: unknown[]): void {
        if (this.#isLevelEnabled("fatal")) this.#write("fatal", message, optionalParams);
    }

    setLogLevels(levels: LogLevel[]): void {
        this.#levels = new Set(levels);
    }

    #isLevelEnabled(level: LogLevel): boolean {
        if (this.#levels.size === 0) return false;
        if (this.#levels.has(level)) return true;

        let highestConfiguredLevel = -Infinity;
        for (const configuredLevel of this.#levels) {
            highestConfiguredLevel = Math.max(highestConfiguredLevel, logLevelValues[configuredLevel]);
        }
        return logLevelValues[level] >= highestConfiguredLevel;
    }

    #write(method: Method, message: unknown, optionalParams: unknown[]): void {
        const { context, messages } = splitArguments(message, optionalParams);
        const logger = this.#forContext(context);
        for (const item of messages) logger[method](item);
    }

    #forContext(context: string | undefined): Logger {
        const category = context ?? "Nest";
        let logger = this.#loggers.get(category);
        if (logger == null) {
            logger = new Logger(context == null ? "Nest" : ["Nest", context]);
            this.#loggers.set(category, logger);
        }
        return logger;
    }
}

function splitArguments(message: unknown, optionalParams: unknown[]): {
    context: string | undefined;
    messages: unknown[];
} {
    const params = [...optionalParams];
    const last = params[params.length - 1];
    const context = typeof last === "string" ? (params.pop() as string) : undefined;
    return { context, messages: [message, ...params] };
}

function splitErrorArguments(message: unknown, optionalParams: unknown[]): {
    context: string | undefined;
    messages: unknown[];
    stack: string | undefined;
} {
    if (optionalParams.length === 1) {
        const value = optionalParams[0];
        if (value === undefined) {
            return { context: undefined, messages: [message], stack: undefined };
        }
        if (typeof value === "string" && isStack(value)) {
            return { context: undefined, messages: [message], stack: value };
        }
        return {
            context: typeof value === "string" ? value : undefined,
            messages: typeof value === "string" ? [message] : [message, value],
            stack: undefined,
        };
    }

    const { context, messages } = splitArguments(message, optionalParams);
    const last = messages[messages.length - 1];
    if (messages.length > 1 && (typeof last === "string" || last === undefined)) {
        return { context, messages: messages.slice(0, -1), stack: typeof last === "string" ? last : undefined };
    }
    return { context, messages, stack: undefined };
}

function isStack(value: string): boolean {
    return /^(.)+\n\s+at .+:\d+:\d+/.test(value);
}

---
name: setup-logger
description: Set up or migrate standardized TypeScript logging in Node.js and Bun applications using LogTape, with colored local output, production JSON Lines on container stdout, optional OpenTelemetry trace correlation, rich error stacks, and operation context such as Vespa preset IDs. Use when adding a logger, replacing Pino or pino-pretty, standardizing a Logger class, or improving Loki and trace correlation.
---

# Setup Logger

Establish one consistent LogTape setup while preserving the target project's useful logging API and domain context.

## Inspect before changing

1. Read the package manifest, lockfile, runtime entry points, environment configuration, container commands, and existing logger implementation and tests.
2. Find all logger construction and call patterns. Identify child/bound loggers, serializers, redaction, custom levels, destinations, request context, and process or worker boundaries.
3. Find the OpenTelemetry bootstrap. Do not assume `@opentelemetry/api` is installed.
4. Find how container output reaches Loki. Keep this skill's production output on stdout; do not add an OTLP log exporter.
5. Preserve observable project-specific behavior unless it conflicts with the requirements below.

## Use the canonical implementation

Read and copy [`assets/Logger.ts`](assets/Logger.ts). Treat it as the behavioral baseline, then adapt import paths, file naming, and environment types to the project.

For NestJS applications, also read and copy [`assets/NestLogger.ts`](assets/NestLogger.ts). Pass `new NestLogger()` as Nest's system logger. Do not forward Nest's final `context` argument as a structured property: the adapter turns it into a `Nest.<context>` logger category. This keeps startup logs compact and searchable. The canonical `Logger` also escapes literal braces before handing arbitrary messages to LogTape; this is required for Nest route messages such as `Mapped {/healthcheck, GET} route`, because LogTape otherwise interprets the route as a missing placeholder and renders `undefined`.

```ts
configureLogger();
const app = await NestFactory.create(AppModule, {
  logger: new NestLogger(),
});
```

Keep these interfaces where existing projects use them:

- `new Logger("component")`
- `logger.debug/info/warn/error(message, context)`
- object-only and `Error`-only calls

Configure logging once in the application entry point before normal work begins. Do not configure LogTape inside reusable libraries.

Install `@logtape/logtape` with the project's existing package manager. The asset targets LogTape 2.3 or newer. Do not install `@logtape/pretty`, `@logtape/otel`, or OpenTelemetry packages for logging.

## Enforce output behavior

- For `NODE_ENV=production`, write newline-delimited JSON to `process.stdout`.
- For `NODE_ENV=test`, disable logs by default.
- For every other `NODE_ENV`, write human-readable output with ANSI colors. Honor `NO_COLOR`.
- Keep small structured property objects on the same local output line; indent only values that actually span multiple lines.
- Use `debug` as the local minimum level and `info` as the production minimum level.
- Keep structured properties at the JSON root so Loki can parse and filter them directly.
- Reserve `@timestamp`, `level`, `message`, and `logger` for the formatter.
- Keep high-cardinality values out of indexed Loki labels. Emit them as structured JSON fields.

Do not choose formatting from TTY detection alone: local Docker output is often non-TTY but should remain human-readable and colored unless `NO_COLOR` is set.

## Preserve errors

Pass actual `Error` objects to the logger; do not reduce them to strings. Preserve `Error.cause` and `AggregateError.errors` through LogTape's serialization.

Add the OpenTelemetry exception fields when an error is present:

- `exception.type`
- `exception.message`
- `exception.stacktrace` when available

Verify stacks appear in both local output and production JSON for these forms:

- `logger.error(error)`
- `logger.error("message", error)`
- `logger.error("message", { error })`
- `logger.error("message", { err: error })`

## Add optional trace correlation

Keep the logger independent of OpenTelemetry. The canonical implementation accepts a synchronous trace-context provider and works without one.

If `@opentelemetry/api` already exists and tracing is initialized, wire a provider from the application bootstrap:

```ts
import { context, isSpanContextValid, trace } from "@opentelemetry/api";
import { configureLogger } from "./Logger.js";

configureLogger({
  getTraceContext() {
    const spanContext = trace.getSpan(context.active())?.spanContext();
    if (spanContext == null || !isSpanContextValid(spanContext)) return undefined;

    return {
      trace_id: spanContext.traceId,
      span_id: spanContext.spanId,
      trace_flags: spanContext.traceFlags.toString(16).padStart(2, "0"),
    };
  },
});
```

If OpenTelemetry is absent, call `configureLogger()` without a provider. Do not install or dynamically import OpenTelemetry. Never let trace lookup failures break application logging.

Use exactly `trace_id`, `span_id`, and `trace_flags` in production JSON. Do not index trace or span IDs as Loki stream labels; retain them as structured metadata/queryable JSON fields.

## Propagate operation context

Use `withLogContext()` around a request, job, queue item, or similar operation so nested asynchronous logs inherit correlation fields. Propagate required values explicitly through message, queue, worker, and subprocess payloads, then re-establish the context on the receiving side.

For Vespa projects:

- Preserve the existing camel-case fields `presetId`, `queueId`, and `ownerId`.
- Establish `presetId` and `queueId` once around preset processing rather than adding them to selected log calls only.
- Keep these values as structured JSON fields, not indexed Loki labels.
- Treat the logger in `vespa-aggregator/src/helpers/Logger.ts` as migration evidence for call compatibility and trace-field names, not as the implementation to copy.

## Migrate in place

Infer the migration from the project rather than applying a fixed Pino rewrite:

1. Replace logger setup and dependencies while minimizing call-site changes.
2. Translate child/bound logger state into component categories or `withLogContext()` as appropriate.
3. Preserve any real redaction or serialization behavior; do not retain incidental Pino mechanics.
4. Remove `pino`, `pino-pretty`, transports, scripts, and configuration only after no runtime or development path uses them.
5. Do not add dedicated tests for the logger. If existing tests depend on Pino implementation details, update only those tests as needed to keep them behavior-focused.

## Verify

Use the project's formatter, type checker, existing tests, and lint commands. It is not necessary to write tests for the logger. Verify with targeted manual checks that:

- production emits one valid JSON object per line with flattened context;
- development output is human-readable and contains ANSI color unless `NO_COLOR` is set;
- test logging is silent;
- all supported error forms include messages and stack traces;
- trace fields appear inside an active traced operation and are absent otherwise;
- logging works when OpenTelemetry is not installed;
- operation context survives awaited asynchronous work;
- worker and subprocess receivers re-establish explicitly propagated context.
- arbitrary messages containing literal braces survive unchanged, including Nest route mapping messages;
- Nest system logs use their context as the logger category and do not repeat a `component` property block.

Inspect representative local and production output manually. Ensure no secrets, authorization headers, tokens, or full sensitive request bodies were introduced during migration.

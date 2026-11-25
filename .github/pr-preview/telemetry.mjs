import { AsyncLocalStorage } from 'node:async_hooks';
import { spawnSync } from 'node:child_process';
import { basename } from 'node:path';

const active = new AsyncLocalStorage();

function actionsExporter() {
  return {
    export(spans, done) {
      for (const span of spans) {
        const { traceId, spanId } = span.spanContext();
        const [seconds, nanoseconds] = span.duration;
        console.error('iDocs preview OTel', JSON.stringify({ name: span.name, kind: span.kind, traceId, spanId,
          parentSpanId: span.parentSpanContext?.spanId, durationMs: seconds * 1000 + nanoseconds / 1e6, attributes: span.attributes }));
      }
      done({ code: 0 });
    },
    async shutdown() {},
  };
}

async function flush(provider, processor, maxWait) {
  let timer;
  try {
    const deadline = new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Trace flush timed out')), maxWait); });
    const finish = processor ? processor.forceFlush().then(() => provider.shutdown()) : provider.shutdown();
    await Promise.race([finish, deadline]);
  } catch {
    console.warn('iDocs preview traces did not flush within the shutdown budget.');
  } finally {
    clearTimeout(timer);
  }
}

export async function withPreviewTrace(name, operation, { exporter, maxWait = 2000, env = process.env } = {}) {
  if (env.DISABLE_TELEMETRY === '1' || env.DO_NOT_TRACK === '1' || env.OTEL_SDK_DISABLED === 'true') return operation();
  const { ROOT_CONTEXT, SpanKind, SpanStatusCode, trace } = await import('@opentelemetry/api');
  const { TracerProvider, SimpleSpanProcessor } = await import('@opentelemetry/sdk-trace');
  if (!exporter && (env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT || env.OTEL_EXPORTER_OTLP_ENDPOINT) && env.OTEL_TRACES_EXPORTER !== 'none') {
    const { OTLPTraceExporter } = await import('@opentelemetry/exporter-trace-otlp-proto');
    exporter = new OTLPTraceExporter({ timeoutMillis: 1200 });
  }
  if (!exporter && env.GITHUB_ACTIONS === 'true' && env.OTEL_TRACES_EXPORTER !== 'none') exporter = actionsExporter();
  const processor = exporter ? new SimpleSpanProcessor({ exporter }) : null;
  const provider = new TracerProvider({ spanProcessors: processor ? [processor] : [] });
  const tracer = provider.getTracer('idocs-pr-preview');
  const span = tracer.startSpan(name, { kind: SpanKind.INTERNAL, attributes: { 'process.executable.name': name, 'process.pid': process.pid } }, ROOT_CONTEXT);
  let code = 0;
  try {
    return await active.run({ tracer, context: trace.setSpan(ROOT_CONTEXT, span), SpanKind, SpanStatusCode }, operation);
  } catch (error) {
    code = 1;
    span.setAttribute('error.type', 'PreviewCommandError');
    span.setStatus({ code: SpanStatusCode.ERROR });
    throw error;
  } finally {
    span.setAttribute('process.exit.code', code);
    span.end();
    await flush(provider, processor, maxWait);
  }
}

export function spawnPreview(command, args, options) {
  const scope = active.getStore();
  if (!scope) return spawnSync(command, args, options);
  const name = basename(command);
  const span = scope.tracer.startSpan(name, { kind: scope.SpanKind.CLIENT, attributes: { 'process.executable.name': name } }, scope.context);
  try {
    const result = spawnSync(command, args, options);
    if (result.pid > 0) span.setAttribute('process.pid', result.pid);
    span.setAttribute('process.exit.code', result.status ?? 1);
    if (result.status !== 0 || result.error) {
      const errorType = result.error?.code === 'ETIMEDOUT' ? 'SubprocessTimeout' : result.error ? 'SubprocessError' : 'SubprocessExit';
      span.setAttribute('error.type', errorType);
      span.setStatus({ code: scope.SpanStatusCode.ERROR });
    }
    return result;
  } catch (error) {
    span.setAttributes({ 'process.exit.code': 1, 'error.type': 'SubprocessError' });
    span.setStatus({ code: scope.SpanStatusCode.ERROR });
    throw error;
  } finally {
    span.end();
  }
}

export function execPreview(command, args, options) {
  const result = spawnPreview(command, args, options);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${basename(command)} exited unsuccessfully (${result.signal ?? result.status})`);
  return result.stdout;
}

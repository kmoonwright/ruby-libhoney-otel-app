# Ruby OpenTelemetry + Libhoney Demo

Demonstrates how to:
- Send traces to Honeycomb using OpenTelemetry SDK
- Send log events using libhoney that attach to active spans
- Route telemetry through an OpenTelemetry Collector

## Quick Start

**Set your Honeycomb API key:**
```bash
export HONEYCOMB_API_KEY="your-api-key-here"
```

### Direct to Honeycomb
```bash
./start.sh
```

### Through Collector (recommended)
```bash
./collector.sh start
USE_COLLECTOR=true ./start.sh
```

## What You'll See in Honeycomb

**Trace hierarchy:**
- `demo-workflow` (root)
  - `httpbin-request` (manual span)
    - `HTTP GET` (auto-instrumented)

**Log events attached to spans:**
- `preparing_http_request` → attaches to root
- `http_request_starting` → attaches to `httpbin-request`
- `http_request_completed` → attaches to `httpbin-request`

Each event includes: `name`, `message`, `trace.trace_id`, `trace.parent_id`, `meta.annotation_type`, and custom fields.

**Key insights:**
- Libhoney events attach to the currently active span. Use `tracer.in_span()` to control which span logs attach to.
- Exception logs include full stack traces for debugging
- `at_exit` hook ensures telemetry is flushed even on unexpected errors

## Architecture

### Direct Mode
```
app.rb → OTLP → api.honeycomb.io (traces)
app.rb → libhoney → api.honeycomb.io (logs)
```

### Collector Mode
```
app.rb → collector:4318 (OTLP receiver) → api.honeycomb.io
app.rb → collector:8080 (libhoney receiver) → api.honeycomb.io
```

## Configuration

### Required Environment Variables

```bash
export HONEYCOMB_API_KEY="your-api-key-here"  # Get from https://ui.honeycomb.io/account
```

### Optional Environment Variables

```bash
export OTEL_SERVICE_NAME="my-service"         # Default: tiny-ruby-otel-libhoney-demo
export USE_COLLECTOR="true"                   # Default: false
export OTEL_EXPORTER_OTLP_ENDPOINT="..."      # Override default endpoint
```

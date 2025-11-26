# frozen_string_literal: true

require "libhoney"
require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/all"

# Configure OpenTelemetry (uses env vars: OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_EXPORTER_OTLP_HEADERS, OTEL_SERVICE_NAME)
OpenTelemetry::SDK.configure do |c|
  c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "tiny-ruby-otel-libhoney-demo")
  c.use_all  # Enable auto-instrumentation
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::OTLP::Exporter.new
    )
  )
end

tracer = OpenTelemetry.tracer_provider.tracer("demo.tracer")

# Configure libhoney (logs use same dataset as traces)
use_collector = ENV["USE_COLLECTOR"] == "true"
$libhoney = Libhoney::Client.new(
  writekey: ENV.fetch("HONEYCOMB_API_KEY"),
  dataset: ENV.fetch("OTEL_SERVICE_NAME", "tiny-ruby-otel-libhoney-demo"),
  api_host: use_collector ? "http://localhost:8080" : "https://api.honeycomb.io/"
)

# Send libhoney event with automatic trace correlation
require 'net/http'

def send_event(name, **fields)
  event = $libhoney.event
  event.add_field("name", name)
  fields.each { |k, v| event.add_field(k.to_s, v) }
  
  # Add trace context for correlation
  if (ctx = OpenTelemetry::Trace.current_span.context)&.valid?
    event.add_field("trace.trace_id", ctx.hex_trace_id)
    event.add_field("trace.parent_id", ctx.hex_span_id)
    event.add_field("trace.trace_flags", ctx.trace_flags.sampled? ? "01" : "00")
    event.add_field("meta.annotation_type", "span_event")
  end
  
  event.send
end

# Flush telemetry on exit (even on exceptions)
at_exit do
  $libhoney.close(true)
  OpenTelemetry.tracer_provider.shutdown
end

begin
  tracer.in_span("demo-workflow") do
    uri = URI('https://httpbin.org/delay/1')
    send_event("preparing_http_request", message: "About to make HTTP request", url: uri.to_s)

    begin
      tracer.in_span("httpbin-request", kind: :client) do |span|
        span.set_attribute("http.url", uri.to_s)
        span.set_attribute("http.method", "GET")
        
        send_event("http_request_starting", message: "Sending HTTP GET request", url: uri.to_s)
        
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 3) do |http|
          response = http.request(Net::HTTP::Get.new(uri))
          send_event("http_request_completed", 
            message: "Received HTTP response",
            status_code: response.code.to_i,
            response_size: response.body.length
          )
        end
      end
    rescue StandardError => e
      send_event("http_request_error", 
        message: "HTTP request failed: #{e.message}", 
        error: true,
        exception_class: e.class.name,
        exception_backtrace: e.backtrace&.first(10)&.join("\n")
      )
    end
  end
rescue StandardError => e
  # Catch any unhandled exceptions at the top level
  send_event("application_error",
    message: "Unhandled exception: #{e.message}",
    error: true,
    exception_class: e.class.name,
    exception_backtrace: e.backtrace&.join("\n")
  )
  raise  # Re-raise after logging
end

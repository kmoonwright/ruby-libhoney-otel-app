#!/bin/bash
set -e

# Configuration
USE_COLLECTOR="${USE_COLLECTOR:-false}"
OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-tiny-ruby-otel-libhoney-demo}"

# Validate API key
if [ -z "$HONEYCOMB_API_KEY" ]; then
    echo "ERROR: HONEYCOMB_API_KEY environment variable is required"
    echo "Usage: HONEYCOMB_API_KEY='your-key' ./start.sh"
    exit 1
fi

# Configure endpoints based on mode
if [ "$USE_COLLECTOR" = "true" ]; then
    export OTEL_EXPORTER_OTLP_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}"
    unset OTEL_EXPORTER_OTLP_HEADERS  # Collector adds auth headers
else
    export OTEL_EXPORTER_OTLP_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-https://api.honeycomb.io}"
    export OTEL_EXPORTER_OTLP_HEADERS="x-honeycomb-team=${HONEYCOMB_API_KEY}"
fi

export OTEL_SERVICE_NAME
export HONEYCOMB_API_KEY
export USE_COLLECTOR

# Run application
[ ! -f "Gemfile.lock" ] && bundle install
bundle exec ruby app.rb



#!/bin/bash

# Helper script to manage the OpenTelemetry Collector

# Detect which docker compose command to use
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "ERROR: Neither 'docker-compose' nor 'docker compose' found"
    echo "Please install Docker Desktop or Docker Compose"
    exit 1
fi

ACTION="${1:-help}"

case "$ACTION" in
    start)
        echo "Starting OpenTelemetry Collector..."
        $DOCKER_COMPOSE up -d
        echo "Collector started. Checking status..."
        sleep 2
        $DOCKER_COMPOSE ps
        ;;
    
    stop)
        echo "Stopping OpenTelemetry Collector..."
        $DOCKER_COMPOSE down
        ;;
    
    restart)
        echo "Restarting OpenTelemetry Collector..."
        $DOCKER_COMPOSE restart
        ;;
    
    logs)
        echo "Showing collector logs..."
        $DOCKER_COMPOSE logs -f otel-collector
        ;;
    
    status)
        echo "Collector status:"
        $DOCKER_COMPOSE ps
        ;;
    
    test)
        echo "Testing collector endpoint..."
        curl -s http://localhost:13133/health | jq . || curl -s http://localhost:13133/health
        ;;
    
    help|*)
        echo "OpenTelemetry Collector Management"
        echo ""
        echo "Usage: ./collector.sh [command]"
        echo ""
        echo "Commands:"
        echo "  start    - Start the collector (requires HONEYCOMB_API_KEY env var)"
        echo "  stop     - Stop the collector"
        echo "  restart  - Restart the collector"
        echo "  logs     - Show collector logs"
        echo "  status   - Show collector status"
        echo "  test     - Test collector health endpoint"
        echo "  help     - Show this help message"
        echo ""
        echo "Examples:"
        echo "  export HONEYCOMB_API_KEY='your-key'"
        echo "  ./collector.sh start"
        ;;
esac


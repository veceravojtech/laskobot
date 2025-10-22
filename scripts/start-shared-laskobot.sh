#!/bin/bash

###############################################################################
# Start Shared Laskobot Instance for Multi-Agent Support
#
# This script starts the laskobot HTTP server in a mode that allows multiple
# workers to connect and share the same instance via session-based routing.
#
# Usage:
#   ./scripts/start-shared-laskobot.sh [options]
#
# Options:
#   -p, --port PORT      HTTP port to listen on (default: 3100)
#   -w, --ws-port PORT   WebSocket port for browser extension (default: 8765)
#   -d, --daemon         Run in background
#   -s, --systemd        Setup systemd service
#   --pm2                Setup PM2 service
#   -h, --help           Show this help
###############################################################################

set -e

# Default configuration
HTTP_PORT=3100
WS_PORT=8765
RUN_DAEMON=false
SETUP_SYSTEMD=false
SETUP_PM2=false

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}→${NC} $1"
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [options]

Start shared laskobot HTTP server for multi-agent support.

Options:
    -p, --port PORT      HTTP port to listen on (default: 3100)
    -w, --ws-port PORT   WebSocket port for browser extension (default: 8765)
    -d, --daemon         Run in background
    -s, --systemd        Setup systemd service
    --pm2                Setup PM2 service
    -h, --help           Show this help

Examples:
    # Start on default port 3100
    $(basename "$0")

    # Start on custom port
    $(basename "$0") --port 3200

    # Run in background
    $(basename "$0") --daemon

    # Setup systemd service
    $(basename "$0") --systemd

    # Setup PM2 service
    $(basename "$0") --pm2

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            HTTP_PORT="$2"
            shift 2
            ;;
        -w|--ws-port)
            WS_PORT="$2"
            shift 2
            ;;
        -d|--daemon)
            RUN_DAEMON=true
            shift
            ;;
        -s|--systemd)
            SETUP_SYSTEMD=true
            shift
            ;;
        --pm2)
            SETUP_PM2=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

print_header "Laskobot Shared Instance Startup"

# Check if project is built
if [ ! -f "$PROJECT_ROOT/dist/index-http.js" ]; then
    print_error "Build not found. Building project..."
    cd "$PROJECT_ROOT"
    npm run build
    print_success "Build complete"
else
    print_success "Build found"
fi

# Setup systemd service
if [ "$SETUP_SYSTEMD" = true ]; then
    print_info "Setting up systemd service..."

    SERVICE_FILE="/etc/systemd/system/laskobot-shared.service"

    cat << EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Laskobot Shared HTTP Server for Multi-Agent
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_ROOT
ExecStart=/usr/bin/node $PROJECT_ROOT/dist/index-http.js --port $HTTP_PORT
Environment="NODE_ENV=production"
Environment="BROWSER_MCP_WS_PORT=$WS_PORT"
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable laskobot-shared.service
    sudo systemctl start laskobot-shared.service

    print_success "Systemd service created and started"
    print_info "Check status: sudo systemctl status laskobot-shared.service"
    print_info "View logs: sudo journalctl -u laskobot-shared.service -f"
    exit 0
fi

# Setup PM2 service
if [ "$SETUP_PM2" = true ]; then
    print_info "Setting up PM2 service..."

    # Check if PM2 is installed
    if ! command -v pm2 &> /dev/null; then
        print_error "PM2 not found. Installing PM2..."
        npm install -g pm2
        print_success "PM2 installed"
    fi

    # Stop existing instance if any
    pm2 delete laskobot-shared 2>/dev/null || true

    # Start with PM2
    cd "$PROJECT_ROOT"
    pm2 start dist/index-http.js \
        --name laskobot-shared \
        -- --port "$HTTP_PORT"

    # Save PM2 config
    pm2 save

    print_success "PM2 service created and started"
    print_info "Check status: pm2 status laskobot-shared"
    print_info "View logs: pm2 logs laskobot-shared"
    print_info "Setup auto-start: pm2 startup"
    exit 0
fi

# Check if port is already in use
if lsof -Pi :$HTTP_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    print_error "Port $HTTP_PORT is already in use"
    print_info "Check what's using it: sudo lsof -i :$HTTP_PORT"
    exit 1
fi

print_success "Port $HTTP_PORT is available"

# Start the server
print_header "Starting Laskobot HTTP Server"
print_info "HTTP Port: $HTTP_PORT"
print_info "WebSocket Port: $WS_PORT"
print_info "Project Root: $PROJECT_ROOT"

cd "$PROJECT_ROOT"

if [ "$RUN_DAEMON" = true ]; then
    print_info "Starting in background..."

    # Create logs directory
    mkdir -p "$PROJECT_ROOT/logs"

    # Start in background
    BROWSER_MCP_WS_PORT=$WS_PORT \
    nohup node dist/index-http.js --port "$HTTP_PORT" \
        > logs/laskobot-http.log 2>&1 &

    PID=$!
    echo $PID > logs/laskobot-http.pid

    # Wait a moment and check if still running
    sleep 2
    if ps -p $PID > /dev/null; then
        print_success "Server started in background (PID: $PID)"
        print_info "Log file: $PROJECT_ROOT/logs/laskobot-http.log"
        print_info "PID file: $PROJECT_ROOT/logs/laskobot-http.pid"
        print_info "Stop with: kill $PID"
    else
        print_error "Server failed to start"
        print_info "Check logs: tail -f $PROJECT_ROOT/logs/laskobot-http.log"
        exit 1
    fi
else
    print_info "Starting in foreground..."
    print_info "Press Ctrl+C to stop"
    echo ""

    BROWSER_MCP_WS_PORT=$WS_PORT \
    exec node dist/index-http.js --port "$HTTP_PORT"
fi

print_header "Server Information"
echo ""
print_success "Laskobot HTTP server is running!"
echo ""
echo "  HTTP Endpoint:      http://localhost:$HTTP_PORT/mcp"
echo "  WebSocket Port:     $WS_PORT"
echo "  Session Endpoint:   http://localhost:$HTTP_PORT/sessions (if implemented)"
echo ""
echo "Worker Configuration:"
echo "  - Each worker should connect to: http://localhost:$HTTP_PORT/mcp"
echo "  - Each worker MUST use unique 'x-instance-id' header"
echo ""
echo "Example:"
echo "  curl -X POST http://localhost:$HTTP_PORT/mcp \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -H 'x-instance-id: worker-001' \\"
echo "    -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}'"
echo ""

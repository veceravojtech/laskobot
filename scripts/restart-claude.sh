#!/bin/bash

echo "🔄 Restarting MCP servers..."

# Kill only MCP server processes (not Claude)
echo "Stopping MCP servers..."
pkill -9 -f "node.*index-unified.js"

sleep 3

# Check if Claude is running
if ! pgrep -f "claude --dangerously-skip-permissions" > /dev/null; then
    echo "⚠️  Claude Desktop is not running"
    echo "   Please start Claude manually first"
    exit 1
fi

echo "✅ Claude Desktop is running"
echo "Waiting for MCP server to restart..."
sleep 5

# Check if MCP server is running
if ss -tlnp 2>/dev/null | grep -q 8765; then
    echo "✅ MCP server is running on port 8765"

    # Show which process owns the port
    SERVER_PID=$(ss -tlnp 2>/dev/null | grep 8765 | grep -oP 'pid=\K[0-9]+' | head -1)
    if [ -n "$SERVER_PID" ]; then
        echo "   Server PID: $SERVER_PID"
    fi
else
    echo "❌ MCP server not running on port 8765"
    echo "   Check Claude Desktop logs for MCP startup errors"
    exit 1
fi

echo ""
echo "Next steps:"
echo "1. Check extension is connected in Chrome (chrome://extensions)"
echo "2. Click 'Reload' on BrowserMCP Enhanced extension"
echo "3. Try your browser commands again"

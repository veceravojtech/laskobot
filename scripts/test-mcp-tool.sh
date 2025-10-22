#!/bin/bash
# Helper script to test MCP tools

SESSION_ID="$1"
TOOL_NAME="$2"
PARAMS="$3"

if [ -z "$SESSION_ID" ] || [ -z "$TOOL_NAME" ]; then
    echo "Usage: $0 <session-id> <tool-name> [params-json]"
    exit 1
fi

if [ -z "$PARAMS" ]; then
    PARAMS="{}"
fi

curl -X POST http://localhost:3100/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H "mcp-session-id: $SESSION_ID" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":$(date +%s),\"method\":\"tools/call\",\"params\":{\"name\":\"$TOOL_NAME\",\"arguments\":$PARAMS}}"

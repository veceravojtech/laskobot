# Multi-Agent Configuration Guide

## Quick Start

### 1. Start Shared Laskobot Instance

```bash
# From laskobot directory
cd /home/console/PhpstormProjects/mcp/laskobot

# Build if not already built
npm run build

# Start HTTP server on port 3100
node dist/index-http.js --port 3100
```

Expected output:
```
[BrowserMCP HTTP] Server listening on http://localhost:3100/mcp
[BrowserMCP HTTP] Version: 1.32.0
[BrowserMCP HTTP] Session-based multi-instance routing enabled
```

### 2. Configure Workers

Each worker needs to connect with a unique session ID via HTTP headers.

---

## MCP Client Configuration Examples

### TypeScript/Node.js Client

```typescript
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { SSEClientTransport } from "@modelcontextprotocol/sdk/client/sse.js";

// Worker 1 - Analyzer
const analyzerClient = new Client(
  {
    name: "worker-analyzer",
    version: "1.0.0",
  },
  {
    capabilities: {},
  }
);

const analyzerTransport = new SSEClientTransport(
  new URL("http://localhost:3100/mcp"),
  {
    headers: {
      "x-instance-id": "worker-analyzer-001",
      "Content-Type": "application/json"
    }
  }
);

await analyzerClient.connect(analyzerTransport);

// Worker 2 - Backend
const backendClient = new Client(
  {
    name: "worker-backend",
    version: "1.0.0",
  },
  {
    capabilities: {},
  }
);

const backendTransport = new SSEClientTransport(
  new URL("http://localhost:3100/mcp"),
  {
    headers: {
      "x-instance-id": "worker-backend-001",
      "Content-Type": "application/json"
    }
  }
);

await backendClient.connect(backendTransport);
```

### Claude Desktop Configuration

If you're using Claude Desktop with custom workers:

**Worker 1 Config:** `~/.config/worker-analyzer/mcp_servers.json`
```json
{
  "mcpServers": {
    "laskobot": {
      "command": "node",
      "args": [
        "-e",
        "const { Client } = require('@modelcontextprotocol/sdk/client/index.js'); const { SSEClientTransport } = require('@modelcontextprotocol/sdk/client/sse.js'); const transport = new SSEClientTransport(new URL('http://localhost:3100/mcp'), { headers: { 'x-instance-id': 'worker-analyzer-001' } }); process.stdin.pipe(transport.writable); transport.readable.pipe(process.stdout);"
      ]
    }
  }
}
```

**Worker 2 Config:** `~/.config/worker-backend/mcp_servers.json`
```json
{
  "mcpServers": {
    "laskobot": {
      "command": "node",
      "args": [
        "-e",
        "const { Client } = require('@modelcontextprotocol/sdk/client/index.js'); const { SSEClientTransport } = require('@modelcontextprotocol/sdk/client/sse.js'); const transport = new SSEClientTransport(new URL('http://localhost:3100/mcp'), { headers: { 'x-instance-id': 'worker-backend-001' } }); process.stdin.pipe(transport.writable); transport.readable.pipe(process.stdout);"
      ]
    }
  }
}
```

### Python Client

```python
import asyncio
import aiohttp
from mcp.client.session import ClientSession
from mcp.client.sse import sse_client

async def create_worker(worker_id: str):
    """Create an MCP client for a worker"""

    headers = {
        "x-instance-id": worker_id,
        "Content-Type": "application/json"
    }

    async with aiohttp.ClientSession() as http_session:
        async with sse_client(
            url="http://localhost:3100/mcp",
            headers=headers
        ) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()

                # List available tools
                tools = await session.list_tools()
                print(f"Worker {worker_id} - Available tools:", tools)

                # Call a tool
                result = await session.call_tool("browser_navigate", {
                    "url": "https://example.com"
                })
                print(f"Worker {worker_id} - Result:", result)

# Create multiple workers
async def main():
    workers = [
        create_worker("worker-analyzer-001"),
        create_worker("worker-backend-001"),
        create_worker("worker-frontend-001")
    ]

    await asyncio.gather(*workers)

asyncio.run(main())
```

---

## Session ID Naming Convention

**Recommended format:** `worker-<type>-<number>`

Examples:
- `worker-analyzer-001`
- `worker-backend-001`
- `worker-frontend-001`
- `worker-scraper-001`
- `worker-test-001`

**Important:**
- Must be unique across all workers
- Should be consistent (same worker = same ID)
- Can be any string, but descriptive names help debugging

---

## Environment Variables

### Laskobot HTTP Server

```bash
# Port (alternative to --port flag)
export BROWSER_MCP_HTTP_PORT=3100

# WebSocket port for browser extension
export BROWSER_MCP_WS_PORT=8765

# Daemon URL (if using daemon transport)
export BROWSER_MCP_DAEMON_URL=http://127.0.0.1:8765

# Enable debug mode
export BROWSER_MCP_ENABLE_DEBUG=1

# Hot reload for development
export HOT_RELOAD=true
export HOT_RELOAD_WATCH_PATH=/path/to/laskobot/src
```

Start with environment variables:
```bash
BROWSER_MCP_HTTP_PORT=3100 node dist/index-http.js
```

### Worker Environment

Each worker can use these variables:
```bash
# Worker identification
export MCP_WORKER_ID=worker-analyzer-001

# Laskobot endpoint
export LASKOBOT_HTTP_URL=http://localhost:3100/mcp

# Timeout settings
export BROWSER_MCP_COMMAND_TIMEOUT=45000
```

---

## Tab Management for Multi-Agent

### Strategy 1: Tab Pools (Recommended)

Assign tab ranges to each worker:

```javascript
// Worker configuration
const workerTabConfig = {
  'worker-analyzer-001': {
    tabStart: 0,
    tabEnd: 9,
    currentTab: 0
  },
  'worker-backend-001': {
    tabStart: 10,
    tabEnd: 19,
    currentTab: 10
  },
  'worker-frontend-001': {
    tabStart: 20,
    tabEnd: 29,
    currentTab: 20
  }
};

// Get next available tab for this worker
function getNextTab(workerId) {
  const config = workerTabConfig[workerId];
  const tab = config.currentTab;
  config.currentTab = (config.currentTab + 1 - config.tabStart) %
                      (config.tabEnd - config.tabStart + 1) +
                      config.tabStart;
  return tab;
}
```

### Strategy 2: Dedicated Tabs

Each worker always uses its assigned tab:

```javascript
const workerTabs = {
  'worker-analyzer-001': 0,
  'worker-backend-001': 1,
  'worker-frontend-001': 2
};

// Always use the same tab
const tabId = workerTabs[workerId];
```

### Strategy 3: Dynamic Allocation

Let workers create new tabs as needed:

```javascript
// Worker creates its own tab
const result = await client.callTool('browser_tab', {
  action: 'new',
  url: 'https://example.com'
});

const myTabId = result.tabId;
// Store myTabId for subsequent operations
```

---

## Testing Multi-Agent Setup

### Test Script

Create `test-multi-agent.sh`:

```bash
#!/bin/bash

echo "=== Testing Multi-Agent Laskobot Setup ==="

# 1. Check if laskobot is running
echo -e "\n1. Checking if laskobot HTTP server is running..."
curl -s http://localhost:3100/mcp > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ Laskobot HTTP server is running"
else
    echo "✗ Laskobot HTTP server is NOT running"
    echo "  Start it with: node dist/index-http.js --port 3100"
    exit 1
fi

# 2. Test worker 1 connection
echo -e "\n2. Testing Worker 1 (Analyzer) connection..."
RESPONSE=$(curl -s -X POST http://localhost:3100/mcp \
  -H "Content-Type: application/json" \
  -H "x-instance-id: worker-analyzer-test" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}')

if echo "$RESPONSE" | grep -q "browser_navigate"; then
    echo "✓ Worker 1 can list tools"
else
    echo "✗ Worker 1 failed to list tools"
    echo "  Response: $RESPONSE"
fi

# 3. Test worker 2 connection
echo -e "\n3. Testing Worker 2 (Backend) connection..."
RESPONSE=$(curl -s -X POST http://localhost:3100/mcp \
  -H "Content-Type: application/json" \
  -H "x-instance-id: worker-backend-test" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}')

if echo "$RESPONSE" | grep -q "browser_navigate"; then
    echo "✓ Worker 2 can list tools"
else
    echo "✗ Worker 2 failed to list tools"
    echo "  Response: $RESPONSE"
fi

# 4. Test concurrent connections
echo -e "\n4. Testing concurrent worker connections..."
curl -s -X POST http://localhost:3100/mcp \
  -H "Content-Type: application/json" \
  -H "x-instance-id: worker-concurrent-1" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' > /dev/null &

curl -s -X POST http://localhost:3100/mcp \
  -H "Content-Type: application/json" \
  -H "x-instance-id: worker-concurrent-2" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' > /dev/null &

curl -s -X POST http://localhost:3100/mcp \
  -H "Content-Type: application/json" \
  -H "x-instance-id: worker-concurrent-3" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' > /dev/null &

wait
echo "✓ Concurrent workers completed"

echo -e "\n=== Multi-Agent Setup Test Complete ==="
```

Run:
```bash
chmod +x test-multi-agent.sh
./test-multi-agent.sh
```

---

## Monitoring and Debugging

### Check Active Sessions

After implementing the `/sessions` endpoint (see MULTI_AGENT_ARCHITECTURE.md):

```bash
curl http://localhost:3100/sessions | jq
```

Expected output:
```json
{
  "totalSessions": 3,
  "sessions": [
    {
      "sessionId": "worker-analyzer-001",
      "createdAt": 1730000000000,
      "currentTabId": "0",
      "hasWebSocket": true
    },
    {
      "sessionId": "worker-backend-001",
      "createdAt": 1730000000100,
      "currentTabId": "1",
      "hasWebSocket": true
    },
    {
      "sessionId": "worker-frontend-001",
      "createdAt": 1730000000200,
      "currentTabId": "2",
      "hasWebSocket": true
    }
  ]
}
```

### Server Logs

```bash
# If running directly
node dist/index-http.js --port 3100 2>&1 | tee laskobot-http.log

# If using systemd
journalctl -u laskobot-shared.service -f

# If using PM2
pm2 logs laskobot-shared
```

### Worker Connection Test

```bash
# Test individual worker
curl -X POST http://localhost:3100/mcp \
  -H "Content-Type: application/json" \
  -H "x-instance-id: test-worker-001" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list"
  }' | jq
```

Expected:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "name": "browser_navigate",
        "description": "Navigate browser...",
        ...
      },
      ...
    ]
  }
}
```

---

## Production Deployment

### Using Systemd

**Service file:** `/etc/systemd/system/laskobot-shared.service`
```ini
[Unit]
Description=Laskobot Shared HTTP Server for Multi-Agent
After=network.target

[Service]
Type=simple
User=console
WorkingDirectory=/home/console/PhpstormProjects/mcp/laskobot
ExecStart=/usr/bin/node dist/index-http.js --port 3100
Environment="NODE_ENV=production"
Environment="BROWSER_MCP_WS_PORT=8765"
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Setup:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable laskobot-shared.service
sudo systemctl start laskobot-shared.service
sudo systemctl status laskobot-shared.service
```

### Using PM2

```bash
# Install PM2
npm install -g pm2

# Start laskobot
pm2 start dist/index-http.js \
  --name laskobot-shared \
  -- --port 3100

# Save PM2 config
pm2 save

# Setup auto-start on boot
pm2 startup
```

### Using Docker

**Dockerfile:**
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --production

COPY dist ./dist
COPY chrome-extension ./chrome-extension

EXPOSE 3100
EXPOSE 8765

CMD ["node", "dist/index-http.js", "--port", "3100"]
```

**Build and run:**
```bash
docker build -t laskobot-shared .

docker run -d \
  --name laskobot-shared \
  -p 3100:3100 \
  -p 8765:8765 \
  --restart unless-stopped \
  laskobot-shared
```

---

## Troubleshooting

### Workers Can't Connect

**Check 1:** Is laskobot running?
```bash
curl http://localhost:3100/mcp
```

**Check 2:** Are workers using correct headers?
```bash
# Test with curl
curl -X POST http://localhost:3100/mcp \
  -H "x-instance-id: test-123" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

**Check 3:** Firewall blocking?
```bash
sudo ufw status
sudo ufw allow 3100/tcp
```

### Session Isolation Not Working

**Symptom:** Workers see each other's state

**Cause:** Same session ID used by multiple workers

**Fix:** Ensure unique `x-instance-id` for each worker

```bash
# Verify session IDs are different
curl http://localhost:3100/sessions | jq '.sessions[].sessionId'
```

### High Memory Usage

**Symptom:** Memory grows with each worker

**Expected:** ~12MB per worker session

**Check:**
```bash
# If using PM2
pm2 monit

# If using systemd
systemctl status laskobot-shared.service

# Check memory
ps aux | grep "node.*index-http"
```

**Solutions:**
- Implement session cleanup (see architecture doc)
- Restart service periodically
- Set memory limits with systemd or Docker

---

## Best Practices

1. **Use descriptive session IDs** - helps debugging
2. **Implement tab pools** - avoids conflicts
3. **Monitor active sessions** - detect leaks early
4. **Use health checks** - auto-restart on failure
5. **Log worker activity** - track which worker did what
6. **Test with 2-3 workers first** - validate before scaling
7. **Document worker configurations** - maintain consistency
8. **Implement graceful shutdown** - clean up sessions properly

---

## Next Steps

1. ✅ Start shared laskobot instance
2. ✅ Configure first worker with unique session ID
3. ✅ Test worker can list tools and execute commands
4. ✅ Add second worker with different session ID
5. ✅ Verify session isolation (workers don't interfere)
6. ✅ Implement tab management strategy
7. ✅ Add monitoring and health checks
8. ✅ Deploy to production (systemd/PM2/Docker)
9. ✅ Scale to N workers as needed

## Support

For issues or questions:
- Check logs: `journalctl -u laskobot-shared.service -f`
- Test connectivity: `curl http://localhost:3100/mcp`
- Verify sessions: `curl http://localhost:3100/sessions`
- Review architecture: See `MULTI_AGENT_ARCHITECTURE.md`

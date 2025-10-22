# Session Monitoring Enhancement

This document shows how to add session monitoring endpoints to the laskobot HTTP server to track active workers and debug multi-agent setups.

## Implementation

Add the following code to `src/index-http.ts` to enable session monitoring:

### 1. Session List Endpoint

Add this handler before the `/mcp` route handler (around line 404):

```typescript
// Session monitoring endpoint
if (parsedUrl.pathname === "/sessions" && req.method === 'GET') {
  const sessionList = Array.from(sessions.entries()).map(([id, state]) => {
    const record = instanceRegistry.get(id);
    return {
      sessionId: id,
      createdAt: record?.createdAt,
      currentTabId: record?.context.currentTabId,
      hasWebSocket: record?.context.hasWs(),
      wsState: record?.context.getWebSocketOrNull()?.readyState,
      runId: state.runId,
      daemonQueueLength: record?.context.daemonMessageCount || 0
    };
  });

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    totalSessions: sessions.size,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    sessions: sessionList
  }, null, 2));
  return;
}
```

### 2. Health Check Endpoint

Add health check endpoint:

```typescript
// Health check endpoint
if (parsedUrl.pathname === "/health" && req.method === 'GET') {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'ok',
    version: packageJSON.version,
    uptime: process.uptime(),
    activeSessions: sessions.size,
    memory: {
      rss: Math.round(process.memoryUsage().rss / 1024 / 1024) + ' MB',
      heapUsed: Math.round(process.memoryUsage().heapUsed / 1024 / 1024) + ' MB',
      heapTotal: Math.round(process.memoryUsage().heapTotal / 1024 / 1024) + ' MB'
    }
  }, null, 2));
  return;
}
```

### 3. Session Details Endpoint

Get details for specific session:

```typescript
// Session details endpoint
if (parsedUrl.pathname.startsWith("/session/") && req.method === 'GET') {
  const sessionId = decodeURIComponent(parsedUrl.pathname.replace("/session/", ""));
  const record = sessionRegistry.get(sessionId);
  const session = sessions.get(sessionId);

  if (!record || !session) {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Session not found' }));
    return;
  }

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    sessionId,
    createdAt: record.createdAt,
    uptime: Date.now() - record.createdAt,
    currentTabId: record.context.currentTabId,
    hasWebSocket: record.context.hasWs(),
    wsState: record.context.getWebSocketOrNull()?.readyState,
    runId: session.runId,
    daemonQueueLength: record.context.daemonMessageCount,
    connectionInfo: record.context.getConnectionInfo()
  }, null, 2));
  return;
}
```

### 4. Session Cleanup Task

Add periodic session cleanup (add after server setup, around line 470):

```typescript
// Periodic session cleanup
const SESSION_TIMEOUT = 30 * 60 * 1000; // 30 minutes
const CLEANUP_INTERVAL = 5 * 60 * 1000; // 5 minutes

setInterval(async () => {
  const now = Date.now();
  let cleanedCount = 0;

  for (const [sessionId, record] of instanceRegistry.entries()) {
    // Check if session is stale
    if (now - record.createdAt > SESSION_TIMEOUT) {
      const session = sessions.get(sessionId);

      // Only cleanup if session has no active WebSocket
      if (session && !record.context.hasWs()) {
        console.error(`[BrowserMCP HTTP] Cleaning up stale session: ${sessionId}`);

        try {
          await instanceRegistry.release(sessionId);
          sessions.delete(sessionId);
          cleanedCount++;
        } catch (error) {
          console.warn(`[BrowserMCP HTTP] Error cleaning session ${sessionId}:`, error);
        }
      }
    }
  }

  if (cleanedCount > 0) {
    console.error(`[BrowserMCP HTTP] Cleaned up ${cleanedCount} stale session(s)`);
    console.error(`[BrowserMCP HTTP] Active sessions: ${sessions.size}`);
  }
}, CLEANUP_INTERVAL);
```

### 5. Session Metrics Logging

Add periodic metrics logging:

```typescript
// Periodic metrics logging
const METRICS_INTERVAL = 60 * 1000; // 1 minute

setInterval(() => {
  const memUsage = process.memoryUsage();

  console.error('[BrowserMCP HTTP] Metrics:', {
    activeSessions: sessions.size,
    uptime: Math.round(process.uptime()),
    memory: {
      rss: Math.round(memUsage.rss / 1024 / 1024) + 'MB',
      heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024) + 'MB'
    }
  });
}, METRICS_INTERVAL);
```

## Usage Examples

### Check All Sessions

```bash
curl http://localhost:3100/sessions | jq
```

Output:
```json
{
  "totalSessions": 3,
  "uptime": 3600,
  "memory": {
    "rss": 125829120,
    "heapTotal": 85491712,
    "heapUsed": 72453984,
    "external": 2345678
  },
  "sessions": [
    {
      "sessionId": "worker-analyzer-001",
      "createdAt": 1730000000000,
      "currentTabId": "0",
      "hasWebSocket": true,
      "wsState": 1,
      "runId": "run-abc123",
      "daemonQueueLength": 0
    },
    {
      "sessionId": "worker-backend-001",
      "createdAt": 1730000000100,
      "currentTabId": "1",
      "hasWebSocket": true,
      "wsState": 1,
      "runId": "run-def456",
      "daemonQueueLength": 2
    },
    {
      "sessionId": "worker-frontend-001",
      "createdAt": 1730000000200,
      "currentTabId": "2",
      "hasWebSocket": false,
      "wsState": null,
      "runId": "run-ghi789",
      "daemonQueueLength": 0
    }
  ]
}
```

### Check Specific Session

```bash
curl http://localhost:3100/session/worker-analyzer-001 | jq
```

Output:
```json
{
  "sessionId": "worker-analyzer-001",
  "createdAt": 1730000000000,
  "uptime": 60000,
  "currentTabId": "0",
  "hasWebSocket": true,
  "wsState": 1,
  "runId": "run-abc123",
  "daemonQueueLength": 0,
  "connectionInfo": {
    "connected": true,
    "connectionAttempts": 0,
    "lastConnectionTime": 1730000000000,
    "currentTabId": "0",
    "wsState": 1
  }
}
```

### Health Check

```bash
curl http://localhost:3100/health
```

Output:
```json
{
  "status": "ok",
  "version": "1.32.0",
  "uptime": 3600,
  "activeSessions": 3,
  "memory": {
    "rss": "120 MB",
    "heapUsed": "69 MB",
    "heapTotal": "81 MB"
  }
}
```

## Monitoring Dashboard

Create a simple monitoring dashboard:

### monitor-sessions.sh

```bash
#!/bin/bash

# Simple session monitoring dashboard

clear

while true; do
    clear
    echo "==================================="
    echo "  Laskobot Session Monitor"
    echo "==================================="
    echo ""

    # Fetch session data
    DATA=$(curl -s http://localhost:3100/sessions)

    # Parse and display
    echo "Total Sessions: $(echo "$DATA" | jq -r '.totalSessions')"
    echo "Uptime: $(echo "$DATA" | jq -r '.uptime') seconds"
    echo "Memory RSS: $(echo "$DATA" | jq -r '.memory.rss / 1024 / 1024 | floor') MB"
    echo ""
    echo "Active Sessions:"
    echo "----------------"

    echo "$DATA" | jq -r '.sessions[] | "  \(.sessionId)
    • Created: \(.createdAt)
    • Tab: \(.currentTabId // "none")
    • WS: \(if .hasWebSocket then "connected" else "disconnected" end)
    • Queue: \(.daemonQueueLength)
    "'

    echo ""
    echo "Press Ctrl+C to exit"
    echo "Refreshing in 5 seconds..."

    sleep 5
done
```

Usage:
```bash
chmod +x monitor-sessions.sh
./monitor-sessions.sh
```

## Grafana Integration (Optional)

For production monitoring, expose metrics in Prometheus format:

### metrics.ts

```typescript
// Add to src/metrics.ts
export function getMetrics(sessions: Map<string, SessionState>, instanceRegistry: InstanceRegistry): string {
  const metrics: string[] = [];

  // Active sessions gauge
  metrics.push(`# HELP laskobot_active_sessions Number of active MCP sessions`);
  metrics.push(`# TYPE laskobot_active_sessions gauge`);
  metrics.push(`laskobot_active_sessions ${sessions.size}`);

  // Memory metrics
  const mem = process.memoryUsage();
  metrics.push(`# HELP laskobot_memory_rss_bytes Resident set size in bytes`);
  metrics.push(`# TYPE laskobot_memory_rss_bytes gauge`);
  metrics.push(`laskobot_memory_rss_bytes ${mem.rss}`);

  metrics.push(`# HELP laskobot_memory_heap_used_bytes Heap used in bytes`);
  metrics.push(`# TYPE laskobot_memory_heap_used_bytes gauge`);
  metrics.push(`laskobot_memory_heap_used_bytes ${mem.heapUsed}`);

  // Uptime
  metrics.push(`# HELP laskobot_uptime_seconds Server uptime in seconds`);
  metrics.push(`# TYPE laskobot_uptime_seconds counter`);
  metrics.push(`laskobot_uptime_seconds ${Math.floor(process.uptime())}`);

  // Per-session metrics
  for (const [sessionId, _] of sessions) {
    const record = instanceRegistry.get(sessionId);
    if (record) {
      const hasWs = record.context.hasWs() ? 1 : 0;
      metrics.push(`laskobot_session_websocket{session="${sessionId}"} ${hasWs}`);

      const queueLen = record.context.daemonMessageCount;
      metrics.push(`laskobot_session_queue_length{session="${sessionId}"} ${queueLen}`);
    }
  }

  return metrics.join('\n') + '\n';
}
```

### Add metrics endpoint

```typescript
// In index-http.ts
import { getMetrics } from './metrics';

// Add before /mcp route
if (parsedUrl.pathname === "/metrics" && req.method === 'GET') {
  const metricsText = getMetrics(sessions, instanceRegistry);

  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end(metricsText);
  return;
}
```

Access metrics:
```bash
curl http://localhost:3100/metrics
```

Configure Prometheus to scrape:
```yaml
scrape_configs:
  - job_name: 'laskobot'
    static_configs:
      - targets: ['localhost:3100']
```

## Alert Rules

Set up alerts for common issues:

### Stale Sessions Alert

```typescript
// Alert if sessions without WebSocket connection for > 10 minutes
const ALERT_THRESHOLD = 10 * 60 * 1000;

setInterval(() => {
  const now = Date.now();

  for (const [sessionId, record] of instanceRegistry.entries()) {
    if (!record.context.hasWs() && (now - record.createdAt > ALERT_THRESHOLD)) {
      console.error(`[ALERT] Session ${sessionId} has no WebSocket for ${Math.round((now - record.createdAt) / 60000)} minutes`);
    }
  }
}, 60000); // Check every minute
```

### High Memory Alert

```typescript
const MEMORY_THRESHOLD = 1024 * 1024 * 1024; // 1GB

setInterval(() => {
  const mem = process.memoryUsage();

  if (mem.heapUsed > MEMORY_THRESHOLD) {
    console.error(`[ALERT] High memory usage: ${Math.round(mem.heapUsed / 1024 / 1024)}MB`);
  }
}, 60000);
```

## Best Practices

1. **Enable monitoring endpoints** before deploying to production
2. **Set up alerting** for stale sessions and high memory
3. **Monitor metrics regularly** - check /health every minute
4. **Log session lifecycle** - creation, activity, cleanup
5. **Implement gradeful degradation** - limit max sessions if memory high
6. **Archive session logs** for debugging multi-agent issues
7. **Use structured logging** for easier parsing and analysis

## Next Steps

1. Implement basic `/sessions` and `/health` endpoints
2. Test with multiple workers
3. Set up monitoring dashboard
4. Configure alerts for production
5. Integrate with existing monitoring stack (optional)

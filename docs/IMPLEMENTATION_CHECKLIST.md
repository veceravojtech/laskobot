# Multi-Agent Implementation Checklist

Quick checklist for implementing shared laskobot architecture for multi-agent support.

## Phase 1: Basic Setup ✓ Ready

### 1.1 Verify Prerequisites
- [ ] Laskobot project is built (`npm run build`)
- [ ] `dist/index-http.js` exists
- [ ] Node.js version 18+ installed
- [ ] Port 3100 is available (or choose alternative)

```bash
# Check build
ls -la dist/index-http.js

# Check port availability
lsof -i :3100

# Check Node version
node --version
```

### 1.2 Start Shared Instance
- [ ] Run `./scripts/start-shared-laskobot.sh`
- [ ] OR run `node dist/index-http.js --port 3100`
- [ ] Verify server started successfully
- [ ] Test with curl

```bash
# Start server
./scripts/start-shared-laskobot.sh --port 3100

# Test
curl http://localhost:3100/mcp
```

## Phase 2: Configure Workers

### 2.1 Worker 1 - Analyzer
- [ ] Create unique session ID: `worker-analyzer-001`
- [ ] Configure to connect to `http://localhost:3100/mcp`
- [ ] Set header: `x-instance-id: worker-analyzer-001`
- [ ] Test connection
- [ ] Verify can list tools

```bash
# Test worker 1
curl -X POST http://localhost:3100/mcp \
  -H "Content-Type: application/json" \
  -H "x-instance-id: worker-analyzer-001" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

### 2.2 Worker 2 - Backend
- [ ] Create unique session ID: `worker-backend-001`
- [ ] Configure to connect to `http://localhost:3100/mcp`
- [ ] Set header: `x-instance-id: worker-backend-001`
- [ ] Test connection
- [ ] Verify can list tools

```bash
# Test worker 2
curl -X POST http://localhost:3100/mcp \
  -H "Content-Type: application/json" \
  -H "x-instance-id: worker-backend-001" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

### 2.3 Additional Workers
- [ ] Create unique session ID for each: `worker-<name>-<number>`
- [ ] Configure each with same endpoint
- [ ] Ensure unique `x-instance-id` headers
- [ ] Test each worker independently

## Phase 3: Session Isolation Testing

### 3.1 Test Isolation
- [ ] Start Worker 1 and navigate to URL A
- [ ] Start Worker 2 and navigate to URL B
- [ ] Verify Worker 1 still on URL A
- [ ] Verify Worker 2 still on URL B
- [ ] Workers don't interfere with each other

### 3.2 Test Concurrent Operations
- [ ] Both workers execute browser commands simultaneously
- [ ] No cross-contamination of state
- [ ] Each worker maintains its own context

### 3.3 Test Tab Management
- [ ] Assign tab pools (Worker 1: tabs 0-9, Worker 2: tabs 10-19, etc.)
- [ ] OR assign dedicated tabs (Worker 1: tab 0, Worker 2: tab 1, etc.)
- [ ] Verify tab isolation works

## Phase 4: Monitoring (Optional)

### 4.1 Add Session Endpoint
- [ ] Implement `/sessions` endpoint (see SESSION_MONITORING.md)
- [ ] Test: `curl http://localhost:3100/sessions`
- [ ] Verify shows all active sessions

### 4.2 Add Health Endpoint
- [ ] Implement `/health` endpoint (see SESSION_MONITORING.md)
- [ ] Test: `curl http://localhost:3100/health`
- [ ] Verify shows server health

### 4.3 Add Session Cleanup
- [ ] Implement periodic session cleanup
- [ ] Configure timeout (default: 30 minutes)
- [ ] Test stale session removal

## Phase 5: Production Deployment

### 5.1 Choose Deployment Method

**Option A: Systemd Service**
- [ ] Run `./scripts/start-shared-laskobot.sh --systemd`
- [ ] Verify service started: `sudo systemctl status laskobot-shared`
- [ ] Test auto-restart: `sudo systemctl restart laskobot-shared`
- [ ] Enable on boot: `sudo systemctl enable laskobot-shared`

**Option B: PM2 Service**
- [ ] Run `./scripts/start-shared-laskobot.sh --pm2`
- [ ] Verify service started: `pm2 status laskobot-shared`
- [ ] Test auto-restart: `pm2 restart laskobot-shared`
- [ ] Enable on boot: `pm2 startup`

**Option C: Docker**
- [ ] Build Docker image (see MULTI_AGENT_CONFIG.md)
- [ ] Run container with port mappings
- [ ] Test connectivity
- [ ] Configure auto-restart policy

### 5.2 Configure Auto-Restart
- [ ] Setup monitoring/health checks
- [ ] Configure restart policy
- [ ] Test automatic recovery from crashes

### 5.3 Setup Logging
- [ ] Configure log rotation
- [ ] Set up centralized logging (optional)
- [ ] Test log accessibility

```bash
# Systemd logs
sudo journalctl -u laskobot-shared.service -f

# PM2 logs
pm2 logs laskobot-shared

# Direct logs
tail -f logs/laskobot-http.log
```

## Phase 6: Worker Integration

### 6.1 Update Worker Configurations
- [ ] Update each worker's MCP configuration
- [ ] Set correct endpoint URL
- [ ] Set unique session IDs
- [ ] Test each worker independently

### 6.2 Deploy Workers
- [ ] Start workers one by one
- [ ] Verify each connects successfully
- [ ] Monitor for conflicts or issues
- [ ] Check laskobot logs for session creation

### 6.3 Enable All Workers
- [ ] Start all workers simultaneously
- [ ] Verify all connect successfully
- [ ] Test concurrent operations
- [ ] Monitor resource usage

## Phase 7: Validation

### 7.1 Functional Testing
- [ ] Each worker can list tools
- [ ] Each worker can execute browser commands
- [ ] Workers maintain isolated state
- [ ] Tab management works correctly
- [ ] No cross-worker interference

### 7.2 Performance Testing
- [ ] Monitor CPU usage
- [ ] Monitor memory usage (~12MB per worker expected)
- [ ] Check for memory leaks
- [ ] Verify acceptable response times

### 7.3 Stability Testing
- [ ] Run for extended period (24+ hours)
- [ ] Monitor for crashes
- [ ] Verify session cleanup works
- [ ] Check for resource accumulation

## Troubleshooting Guide

### Issue: Server won't start
- [ ] Check port is available: `lsof -i :3100`
- [ ] Check build exists: `ls dist/index-http.js`
- [ ] Check logs for errors
- [ ] Try alternative port

### Issue: Workers can't connect
- [ ] Verify server is running
- [ ] Check firewall rules
- [ ] Verify URL format is correct
- [ ] Check headers are set correctly
- [ ] Test with curl first

### Issue: Workers interfere with each other
- [ ] Verify unique session IDs
- [ ] Check tab assignments
- [ ] Review session isolation
- [ ] Add debugging logs

### Issue: Memory keeps growing
- [ ] Implement session cleanup
- [ ] Check for session leaks
- [ ] Monitor active sessions: `curl http://localhost:3100/sessions`
- [ ] Restart service if needed

### Issue: Stale sessions accumulating
- [ ] Implement session timeout
- [ ] Add periodic cleanup task
- [ ] Monitor session ages
- [ ] Restart service periodically

## Success Criteria

### Minimum Viable Setup ✓
- [x] HTTP server running on port 3100
- [ ] At least 2 workers connected with unique session IDs
- [ ] Workers can execute browser commands independently
- [ ] No cross-worker interference observed
- [ ] Setup is stable for at least 1 hour

### Production Ready
- [ ] HTTP server deployed as systemd/PM2 service
- [ ] Auto-restart configured
- [ ] Logging configured and working
- [ ] 3+ workers running successfully
- [ ] Session monitoring implemented
- [ ] Stable for 24+ hours
- [ ] Memory usage within acceptable limits
- [ ] Documentation complete

### Advanced (Optional)
- [ ] Metrics endpoint implemented
- [ ] Grafana dashboard configured
- [ ] Alerting setup
- [ ] Load balancing configured (if needed)
- [ ] Backup/failover strategy implemented

## Reference Documents

- **Architecture:** `MULTI_AGENT_ARCHITECTURE.md`
- **Configuration:** `docs/MULTI_AGENT_CONFIG.md`
- **Monitoring:** `docs/SESSION_MONITORING.md`
- **Startup Script:** `scripts/start-shared-laskobot.sh`

## Quick Reference Commands

```bash
# Start server
./scripts/start-shared-laskobot.sh --port 3100

# Start as daemon
./scripts/start-shared-laskobot.sh --daemon

# Setup systemd
./scripts/start-shared-laskobot.sh --systemd

# Setup PM2
./scripts/start-shared-laskobot.sh --pm2

# Test worker connection
curl -X POST http://localhost:3100/mcp \
  -H "x-instance-id: test-worker" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'

# Check sessions (after implementing endpoint)
curl http://localhost:3100/sessions | jq

# Check health (after implementing endpoint)
curl http://localhost:3100/health

# Check systemd status
sudo systemctl status laskobot-shared

# Check PM2 status
pm2 status laskobot-shared

# View logs
sudo journalctl -u laskobot-shared -f  # systemd
pm2 logs laskobot-shared               # PM2
tail -f logs/laskobot-http.log         # direct
```

## Support

If you encounter issues:
1. Check this checklist for common problems
2. Review architecture documentation
3. Check server logs for errors
4. Test with curl before debugging workers
5. Verify session IDs are unique
6. Monitor resource usage

---

**Last Updated:** 2025-10-21
**Version:** 1.0

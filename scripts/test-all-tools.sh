#!/bin/bash
# Comprehensive tool testing script

SESSION_ID=$(cat /tmp/mcp-session-id.txt)
RESULTS_FILE="/tmp/mcp-test-results.txt"

echo "==================================" > $RESULTS_FILE
echo "LASKOBOT MCP TOOL TEST RESULTS" >> $RESULTS_FILE
echo "Session: $SESSION_ID" >> $RESULTS_FILE
echo "==================================" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

test_tool() {
    local tool_name=$1
    local args_json=$2
    local test_name=$3

    echo "Testing: $test_name"
    echo "------- $test_name -------" >> $RESULTS_FILE

    cat > /tmp/test.json << EOF
{"jsonrpc":"2.0","id":$RANDOM,"method":"tools/call","params":{"name":"$tool_name","arguments":$args_json}}
EOF

    RESPONSE=$(curl -s -X POST http://localhost:3100/mcp \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/json, text/event-stream' \
        -H "mcp-session-id: $SESSION_ID" \
        -d @/tmp/test.json)

    if echo "$RESPONSE" | grep -q '"result"'; then
        echo "✅ PASSED: $test_name" >> $RESULTS_FILE
        echo "$RESPONSE" | grep -o '"text":"[^"]*"' | head -3 >> $RESULTS_FILE
    elif echo "$RESPONSE" | grep -q '"error"'; then
        echo "❌ FAILED: $test_name" >> $RESULTS_FILE
        echo "$RESPONSE" | grep -o '"message":"[^"]*"' >> $RESULTS_FILE
    else
        echo "⚠️  UNKNOWN: $test_name" >> $RESULTS_FILE
        echo "$RESPONSE" | head -200 >> $RESULTS_FILE
    fi
    echo "" >> $RESULTS_FILE
    sleep 0.5
}

echo "Starting comprehensive tool tests..."

# Test browser_type
test_tool "browser_type" '{"ref":"ref18","element":"username field","text":"testuser123"}' "browser_type - type in input"

# Test browser_screenshot
test_tool "browser_screenshot" '{"quality":"medium"}' "browser_screenshot - capture viewport"

# Test browser_scroll
test_tool "browser_scroll" '{"to":"bottom","steps":2,"delayMs":300}' "browser_scroll - scroll to bottom"

# Test browser_extract_html
test_tool "browser_extract_html" '{"selector":".product-title","mode":"simple","attrs":["textContent"]}' "browser_extract_html - extract product titles"

# Test browser_fill_form
test_tool "browser_fill_form" '{"fields":{"username":"john","email":"john@test.com","password":"test123"}}' "browser_fill_form - fill multiple fields"

# Test browser_tab with list
test_tool "browser_tab" '{"action":"list"}' "browser_tab - list tabs"

# Test browser_hover
test_tool "browser_hover" '{"ref":"ref7","element":"hover button"}' "browser_hover - hover over button"

# Test browser_select_option
test_tool "browser_select_option" '{"ref":"ref19","element":"country select","values":["us"]}' "browser_select_option - select option"

# Test browser_press_key
test_tool "browser_press_key" '{"key":"Tab"}' "browser_press_key - press Tab key"

# Test browser_wait
test_tool "browser_wait" '{"time":0.5}' "browser_wait - wait 0.5 seconds"

# Test browser_execute_js (safe mode)
test_tool "browser_execute_js" '{"code":"return await api.getText(\"h1\")"}' "browser_execute_js - safe mode getText"

# Test browser_get_console_logs
test_tool "browser_get_console_logs" '{"limit":10}' "browser_get_console_logs - get recent logs"

# Test browser_debugger
test_tool "browser_debugger" '{"action":"get_data","type":"console","limit":5}' "browser_debugger - get console data"

echo "" >> $RESULTS_FILE
echo "==================================" >> $RESULTS_FILE
echo "TEST SUMMARY" >> $RESULTS_FILE
echo "==================================" >> $RESULTS_FILE
PASSED=$(grep -c "✅ PASSED" $RESULTS_FILE)
FAILED=$(grep -c "❌ FAILED" $RESULTS_FILE)
UNKNOWN=$(grep -c "⚠️  UNKNOWN" $RESULTS_FILE)
echo "Passed: $PASSED" >> $RESULTS_FILE
echo "Failed: $FAILED" >> $RESULTS_FILE
echo "Unknown: $UNKNOWN" >> $RESULTS_FILE

cat $RESULTS_FILE
echo ""
echo "Full results saved to: $RESULTS_FILE"

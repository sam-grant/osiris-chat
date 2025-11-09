#!/bin/bash
# Osiris Chat Debug Script - System diagnostics and health checks

echo "=========================================="
echo "Osiris Chat - System Diagnostics"
echo "=========================================="
echo "Timestamp: $(date)"
echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo ""

echo "=========================================="
echo "1. Service Status (systemd)"
echo "=========================================="
for service in search-mcp osiris-http ollama; do
    echo "--- $service.service ---"
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo "Status: RUNNING"
        systemctl status $service --no-pager -l | head -8
    else
        echo "Status: NOT RUNNING (or not installed)"
    fi
    echo ""
done

echo "=========================================="
echo "2. Running Processes"
echo "=========================================="
echo "--- Ollama ---"
ps aux | grep '[o]llama serve' || echo "Not running"
echo ""
echo "--- Search Proxy ---"
ps aux | grep '[s]earch-proxy.py' || echo "Not running"
echo ""
echo "--- HTTP Server (port 8000) ---"
ps aux | grep '[h]ttp.server 8000' || echo "Not running"
echo ""

echo "=========================================="
echo "3. Network Ports"
echo "=========================================="
echo "Checking listening ports..."
for port in 8000 8001 11434; do
    echo -n "Port $port: "
    if lsof -i :$port | grep -q LISTEN; then
        lsof -i :$port | grep LISTEN | awk '{print $1, $2, $9}'
    else
        echo "NOT LISTENING"
    fi
done
echo ""

echo "=========================================="
echo "4. API Health Checks"
echo "=========================================="

echo "--- Ollama API (http://localhost:11434) ---"
if curl -s --max-time 5 http://localhost:11434/api/version > /dev/null 2>&1; then
    echo "Status: RESPONDING"
    echo "Version: $(curl -s http://localhost:11434/api/version | python3 -c 'import sys,json; print(json.load(sys.stdin).get("version","unknown"))' 2>/dev/null || echo 'unknown')"
    echo "Models:"
    curl -s http://localhost:11434/api/tags | python3 -c 'import sys,json; [print(f"  - {m[\"name\"]}") for m in json.load(sys.stdin).get("models",[])]' 2>/dev/null || echo "  Could not list models"
else
    echo "Status: NOT RESPONDING"
fi
echo ""

echo "--- Search Proxy API (http://localhost:8001) ---"
if curl -s --max-time 5 http://localhost:8001/healthcheck > /dev/null 2>&1; then
    echo "Status: RESPONDING"
    echo "Testing weather query..."
    result=$(curl -s --max-time 10 -X POST http://localhost:8001/context \
        -H "Content-Type: application/json" \
        -d '{"prompt":"weather in London"}' 2>/dev/null)
    if echo "$result" | grep -q "context"; then
        echo "  ✓ Weather API working"
    else
        echo "  ✗ Weather API error"
    fi
else
    echo "Status: NOT RESPONDING"
fi
echo ""

echo "=========================================="
echo "5. File Checks"
echo "=========================================="
cd /home/sam/osiris-chat 2>/dev/null || cd $(dirname "$0")
echo "Working directory: $(pwd)"
echo ""
echo "Key files:"
for file in search-proxy.py html/osiris-chat.html pyproject.toml systemd/search-mcp.service; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (MISSING)"
    fi
done
echo ""
echo "Virtual environment:"
if [ -d "venv" ]; then
    echo "  ✓ venv/ exists"
    if [ -f "venv/bin/python3" ]; then
        echo "  ✓ Python: $(venv/bin/python3 --version 2>&1)"
    fi
else
    echo "  ✗ venv/ not found (run ./setup-venv.sh)"
fi
echo ""

echo "=========================================="
echo "6. Recent Logs"
echo "=========================================="
echo "--- Search Proxy (last 10 lines) ---"
if [ -f /tmp/osiris-search.log ]; then
    tail -10 /tmp/osiris-search.log
elif sudo journalctl -u search-mcp -n 10 --no-pager > /dev/null 2>&1; then
    sudo journalctl -u search-mcp -n 10 --no-pager
else
    echo "No logs found"
fi
echo ""

echo "--- HTTP Server (last 5 lines) ---"
if [ -f /tmp/osiris-http.log ]; then
    tail -5 /tmp/osiris-http.log
else
    echo "No logs found"
fi
echo ""

echo "=========================================="
echo "7. Network Connectivity"
echo "=========================================="
echo "Testing external API endpoints..."
echo -n "DuckDuckGo: "
if curl -s --max-time 5 "https://html.duckduckgo.com/html/" > /dev/null 2>&1; then
    echo "✓ Reachable"
else
    echo "✗ Not reachable"
fi

echo -n "OpenMeteo (weather): "
if curl -s --max-time 5 "https://api.open-meteo.com/v1/forecast?latitude=51.5&longitude=0&current=temperature_2m" > /dev/null 2>&1; then
    echo "✓ Reachable"
else
    echo "✗ Not reachable"
fi

echo -n "Wikipedia: "
if curl -s --max-time 5 "https://en.wikipedia.org/w/api.php" > /dev/null 2>&1; then
    echo "✓ Reachable"
else
    echo "✗ Not reachable"
fi
echo ""

echo "=========================================="
echo "8. System Resources"
echo "=========================================="
echo "Memory usage:"
free -h | grep -E "Mem:|Swap:"
echo ""
echo "Disk usage:"
df -h . | tail -1
echo ""

echo "=========================================="
echo "Summary & Recommendations"
echo "=========================================="
echo ""

# Check if everything is running
ollama_ok=false
search_ok=false
http_ok=false

curl -s --max-time 5 http://localhost:11434/api/version > /dev/null 2>&1 && ollama_ok=true
curl -s --max-time 5 http://localhost:8001/healthcheck > /dev/null 2>&1 && search_ok=true
lsof -i :8000 | grep -q LISTEN && http_ok=true

if $ollama_ok && $search_ok && $http_ok; then
    echo "✓ ALL SERVICES OPERATIONAL"
    echo ""
    echo "Access the chat at:"
    echo "  http://localhost:8000/osiris-chat.html"
    echo "  http://$(hostname -I | awk '{print $1}'):8000/osiris-chat.html"
else
    echo "⚠ ISSUES DETECTED"
    echo ""
    $ollama_ok || echo "  ✗ Ollama not responding - start with: ollama serve"
    $search_ok || echo "  ✗ Search proxy not responding - check: sudo systemctl status search-mcp"
    $http_ok || echo "  ✗ HTTP server not running - start with: ./start-all.sh"
    echo ""
    echo "Quick fixes:"
    echo "  ./start-all.sh          # Start all services"
    echo "  ./stop-all.sh           # Stop all services"
    echo "  ./install-systemd.sh    # Install systemd services"
fi
echo ""
echo "=========================================="
echo "Debug complete: $(date)"
echo "=========================================="

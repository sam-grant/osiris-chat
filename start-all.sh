#!/bin/bash
# Quick start script for Osiris Chat (development mode)

cd "$(dirname "$0")"

echo "Starting Osiris Chat services..."
echo ""

# Check if venv exists
if [ ! -d "venv" ]; then
    echo "Virtual environment not found. Running setup..."
    ./setup-venv.sh
    echo ""
fi

# Check if search proxy is already running
if lsof -i :8001 > /dev/null 2>&1; then
    echo "Search proxy already running on port 8001. Stopping old instance..."
    pkill -f "python.*search-proxy.py"
    sleep 1
fi

# Start search proxy in background
echo "Starting search proxy on port 8001..."
venv/bin/python3 search-proxy.py > /tmp/osiris-search.log 2>&1 &
SEARCH_PID=$!
sleep 2

# Check if it started
if ps -p $SEARCH_PID > /dev/null; then
    echo "  ✓ Search proxy started (PID: $SEARCH_PID)"
else
    echo "  ✗ Search proxy failed to start. Check /tmp/osiris-search.log"
    exit 1
fi

# Check if HTTP server is already running
if lsof -i :8000 > /dev/null 2>&1; then
    echo "HTTP server already running on port 8000. Stopping old instance..."
    pkill -f "python.*http.server 8000"
    sleep 1
fi

# Start HTTP server in background
echo "Starting HTTP server on port 8000..."
cd html
python3 -m http.server 8000 --bind 0.0.0.0 > /tmp/osiris-http.log 2>&1 &
HTTP_PID=$!
cd ..
sleep 1

# Check if it started
if ps -p $HTTP_PID > /dev/null; then
    echo "  ✓ HTTP server started (PID: $HTTP_PID)"
else
    echo "  ✗ HTTP server failed to start. Check /tmp/osiris-http.log"
    kill $SEARCH_PID 2>/dev/null
    exit 1
fi

# Check Ollama
echo "Checking Ollama..."
if curl -s http://localhost:11434/api/version > /dev/null 2>&1; then
    echo "  ✓ Ollama is running"
else
    echo "  ✗ Ollama not detected. Start it with: ollama serve"
fi

echo ""
echo "=================================="
echo "✓ Osiris Chat is ready!"
echo "=================================="
echo ""
echo "Open: http://localhost:8000/osiris-chat.html"
echo "Or:   http://$(hostname -I | awk '{print $1}'):8000/osiris-chat.html"
echo ""
echo "Logs:"
echo "  Search: /tmp/osiris-search.log"
echo "  HTTP:   /tmp/osiris-http.log"
echo ""
echo "To stop: ./stop-all.sh"
echo ""

# Save PIDs
echo "$SEARCH_PID" > /tmp/osiris-search.pid
echo "$HTTP_PID" > /tmp/osiris-http.pid

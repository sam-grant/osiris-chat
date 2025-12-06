#!/bin/bash

echo "=================================="
echo "⭐ Starting all services..."
echo "=================================="
echo ""

# Check Ollama
echo "👀 Checking Ollama..."
if curl -s http://localhost:11434/api/version > /dev/null 2>&1; then
    echo "  ✅ Ollama is running"
else
    ollama serve > ollama.log 2>&1 &
    sleep 2 
    echo "  ✅ Ollama started"
fi
echo ""


# Check if HTTP server is already running
echo "👀 Checking HTTP server..."
if lsof -i :8000 > /dev/null 2>&1; then
    echo "⭐ HTTP server running on port 8000. Stopping old instance..."
    pkill -f "python.*http.server 8000"
    sleep 1
fi

# Start HTTP server in background
echo "⭐ Starting HTTP server on port 8000..."
python3 -m http.server 8000 > http-server.log 2>&1 &
HTTP_PID=$!
sleep 1

# Check if it started
if ps -p $HTTP_PID > /dev/null; then
    echo "  ✅ HTTP server started (PID: $HTTP_PID)"
else
    echo "  ❌ HTTP server failed to start. Check http-server.log"
    kill $SEARCH_PID 2>/dev/null
    exit 1
fi

echo ""
echo "=================================="
echo "✅ Ready!"
echo ""
echo "  http://localhost:8000/chat.html"
echo ""
echo "Logs:"
echo "  - Ollama: ollama.log"
echo "  - HTTP server: http-server.log"
echo ""
echo "=================================="

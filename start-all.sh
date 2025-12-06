#!/bin/bash

echo "=================================="
echo "⭐ Starting all services..."
echo "=================================="
echo ""

# Setup logs
echo "👀 Checking logs directory..."
if [ ! -d logs ]; then
    mkdir logs
    echo "✅ Created logs directory"
fi
echo ""

# Check Ollama
echo "👀 Checking Ollama..."
if curl -s http://localhost:11434/api/version > /dev/null 2>&1; then
    echo "  ✅ Ollama is running"
else
    echo "  ⭐ Ollama not detected. Starting..."
    export OLLAMA_MODELS=~/.ollama/models # careful, systemd tries to use /usr/share/ollama/
    if [ ! -d ~/.ollama/models ]; then
        echo "  ⭐ Ollama models directory not found. Creating ~/.ollama/models..."
        mkdir -p ~/.ollama/models
    fi
    OLLAMA_HOST=0.0.0.0:11434 OLLAMA_ORIGINS="*" ollama serve > logs/ollama.log 2>&1 &
    sleep 2 
    echo "  ✅ Ollama started"
fi
echo ""

# Activate virtual environment
echo "👀 Checking virtual environment..."
if [ ! -d "venv" ]; then
    echo "⭐ Virtual environment not found. Running setup..."
    ./setup-venv.sh
else
    echo "  ✅ Virtual environment found"
fi
source venv/bin/activate    
echo "  ✅ Activated virtual environment..."
echo ""

# Check if search proxy is already running
echo "👀 Checking search proxy..."
if lsof -i :8001 > /dev/null 2>&1; then
    echo "⭐ Search proxy running on port 8001. Stopping old instance..."
    pkill -f "python.*backend/search-proxy.py"
    sleep 1
fi
# Start search proxy in background
echo "⭐ Starting search proxy on port 8001..."
venv/bin/python3 backend/search-proxy.py > logs/search-proxy.log 2>&1 &
SEARCH_PID=$!
sleep 2

# Check if it started
if ps -p $SEARCH_PID > /dev/null; then
    echo "  ✅ Search proxy started (PID: $SEARCH_PID)"
else
    echo "  ❌ Search proxy failed to start. Check logs/search-proxy.log"
    exit 1
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
cd frontend
../venv/bin/python3 -m http.server 8000 --bind 0.0.0.0 > ../logs/http-server.log 2>&1 &
HTTP_PID=$!
cd ..
sleep 1

# Check if it started
if ps -p $HTTP_PID > /dev/null; then
    echo "  ✅ HTTP server started (PID: $HTTP_PID)"
else
    echo "  ❌ HTTP server failed to start. Check logs/http-server.log"
    kill $SEARCH_PID 2>/dev/null
    exit 1
fi

echo ""
echo "=================================="
echo "✅ Ready!"
echo ""
echo "Open:"
echo "  http://localhost:8000/chat.html"
# Get local network IP (excluding VPN)
LOCAL_IP=$(python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    s.connect(('192.168.1.1', 1))  # Connect to common gateway
    ip = s.getsockname()[0]
    # Only show if it's a typical LAN IP (192.168.x.x or 10.x.x.x but not VPN)
    if ip.startswith('192.168.') or (ip.startswith('10.') and not ip.startswith('10.8.')):
        print(ip)
except:
    pass
finally:
    s.close()
" 2>/dev/null)
if [ -n "$LOCAL_IP" ]; then
    echo "Or"
    echo "  http://${LOCAL_IP}:8000/chat.html"
fi
echo ""
echo "Logs:"
echo "  - Ollama: logs/ollama.log"
echo "  - HTTP server: logs/http-server.log"
echo "  - Search proxy: logs/search-proxy.log"
echo "=================================="

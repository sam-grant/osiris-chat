#!/bin/bash
# Stop all Osiris chat services

echo "Stopping all services..."

# Stop systemd services if running
echo "Stopping search-mcp service..."
sudo systemctl stop search-mcp 2>/dev/null || echo "  (service not running)"

echo "Stopping osiris-http service..."
sudo systemctl stop osiris-http 2>/dev/null || echo "  (service not running)"

# Kill any running Python HTTP servers on port 8000
echo "Stopping HTTP server on port 8000..."
pkill -f "python3 -m http.server 8000" 2>/dev/null || echo "  (not running)"

# Kill any running search-proxy processes
echo "Stopping search-proxy..."
pkill -f "search-proxy.py" 2>/dev/null || echo "  (not running)"

# Don't stop Ollama as it might be used for other things
echo "Note: Ollama service left running (may be used by other applications)"

echo ""
echo "✓ All Osiris services stopped"
echo ""
echo "To restart:"
echo "  sudo systemctl start search-mcp"
echo "  python3 -m http.server 8000 --bind 0.0.0.0"

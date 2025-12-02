#!/bin/bash
echo "=================================="
echo "⭐ Stopping all services..."
echo "=================================="
echo ""

echo "👀 Stop Ollama service? It may be used by other applications."
read -p "Type 'yes' to stop Ollama, or press Enter to skip: " user_input
if [ "$user_input" == "yes" ]; then
    if pkill -f "ollama" 2>/dev/null; then
        echo "  ✅ Ollama service stopped."
    else
        echo "  ⭐ Ollama service was not running."
    fi
else
    echo "  ⭐ Skipping Ollama service stop."
fi

# Kill any running Python HTTP servers on port 8000
echo "⭐ Stopping HTTP server on port 8000..."
if pkill -f "python3 -m http.server 8000" 2>/dev/null; then 
    echo "  ✅ HTTP server stopped."
else
    echo "  ⭐ HTTP server was not running."
fi

echo ""
echo "=================================="
echo "✅ All services stopped"
echo "=================================="

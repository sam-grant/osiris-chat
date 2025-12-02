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

echo ""
echo "=================================="
echo "✅ All services stopped"
echo "=================================="

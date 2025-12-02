#!/bin/bash

echo ""
echo "=================================="
echo "⭐ Starting all services..."
echo "=================================="
echo ""

# Setup logs
if [ ! -d logs ]; then
    mkdir logs
    echo "✅ Created logs directory"
fi

# Check Ollama
echo "Checking Ollama..."
if curl -s http://localhost:11434/api/version > /dev/null 2>&1; then
    echo "  ✅ Ollama is running"
else
    echo "  ⭐ Ollama not detected. Starting..."
    export OLLAMA_MODELS=~/.ollama/models # careful, systemd tries to use /usr/share/ollama/
    if [ ! -d ~/.ollama/models ]; then
        echo "  ⭐ Ollama models directory not found. Creating ~/.ollama/models..."
        mkdir -p ~/.ollama/models
    fi
    OLLAMA_HOST=0.0.0.0:11434 ollama serve > logs/ollama.log 2>&1 &
    sleep 2 
    echo "  ✅ Ollama started"
fi

echo ""
echo "=================================="
echo "✅ Ready!"
echo ""
echo "Logs:"
echo "  - Ollama: logs/ollama.log"
echo "=================================="
echo ""

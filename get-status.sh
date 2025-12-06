#!/bin/bash

echo "=========================================="
echo " ⭐ Getting status"
echo "=========================================="
echo ""

files_ok=false
ollama_ok=false
http_ok=false
search_proxy_ok=false

# Check services
echo "Services:"
echo -n "  Ollama (11434): "
curl -s --max-time 3 http://localhost:11434/api/version > /dev/null 2>&1 && echo "✅" && ollama_ok=true || echo "❌" 
echo -n "  HTTP Server (8000): "
curl -s --max-time 3 http://localhost:8000 > /dev/null 2>&1 && echo "✅" && http_ok=true || echo "❌"
echo -n "  Search Proxy (8001): "
curl -s --max-time 3 http://localhost:8001/healthcheck > /dev/null 2>&1 && echo "✅" && search_proxy_ok=true || echo "❌"
echo ""

# Check files
echo "Files:"
for file in frontend/ollama-chat.html frontend/app.js backend/search-proxy.py backend/search.py backend/requirements.txt; do
    [ -f "$file" ] && echo "  ✅ $file" && files_ok=true || echo "  ❌ $file (missing)"
done
echo ""

# Check venv
echo "Environment:"
[ -d "venv" ] && echo "  ✅ venv/" || echo "  ❌ venv/ (run ./setup-venv.sh)"
echo ""

echo "=========================================="
if $files_ok && $ollama_ok && $http_ok && $search_proxy_ok; then
    echo "✅ All services running"
    echo ""
    echo "Access: http://localhost:8000/ollama-chat.html"
else
    echo "❌ Issues detected:"
    $ollama_ok || echo "  - Ollama not running"
    $http_ok || echo "  - HTTP server not running"
    $search_proxy_ok || echo "  - Search proxy not running"
    $files_ok || echo "  - Missing required files"
fi
echo "=========================================="

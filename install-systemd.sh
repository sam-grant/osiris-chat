#!/usr/bin/env bash
set -euo pipefail

echo "Installing Osiris systemd services..."
echo ""

# Install search-mcp service
SEARCH_SRC="$(pwd)/systemd/search-mcp.service"
SEARCH_DST="/etc/systemd/system/search-mcp.service"

if [ -f "$SEARCH_SRC" ]; then
  echo "Installing search-mcp.service..."
  sudo cp "$SEARCH_SRC" "$SEARCH_DST"
else
  echo "Warning: $SEARCH_SRC not found"
fi

# Install osiris-http service  
HTTP_SRC="$(pwd)/systemd/osiris-http.service"
HTTP_DST="/etc/systemd/system/osiris-http.service"

if [ -f "$HTTP_SRC" ]; then
  echo "Installing osiris-http.service..."
  sudo cp "$HTTP_SRC" "$HTTP_DST"
else
  echo "Warning: $HTTP_SRC not found"
fi

echo ""
echo "Reloading systemd..."
sudo systemctl daemon-reload

echo "Enabling and starting services..."
sudo systemctl enable --now search-mcp.service
sudo systemctl enable --now osiris-http.service

echo ""
echo "Service status:"
echo "==============="
sudo systemctl status search-mcp.service --no-pager -l | head -10
echo ""
sudo systemctl status osiris-http.service --no-pager -l | head -10

echo ""
echo "✓ Installation complete!"
echo ""
echo "To uninstall:"
echo "  sudo systemctl disable --now search-mcp osiris-http"
echo "  sudo rm /etc/systemd/system/{search-mcp,osiris-http}.service"
echo "  sudo systemctl daemon-reload"

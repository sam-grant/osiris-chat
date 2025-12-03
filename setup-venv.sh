#!/bin/bash
# Setup script Python backend environment

set -e

echo "⭐ Creating Python virtual environment..."
python3 -m venv venv

echo "⭐Activating..."
source venv/bin/activate

echo "⭐ Upgrading pip..."
pip install --upgrade pip

echo "⭐ Installing dependencies from requirements.txt..."
pip install -r backend/requirements.txt

echo ""
echo "✅ Virtual environment setup complete!"
echo ""

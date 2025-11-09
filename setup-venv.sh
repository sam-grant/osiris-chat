#!/bin/bash
# Setup script for LLM search proxy environment

set -e

echo "Creating Python virtual environment..."
python3 -m venv venv

echo "Activating virtual environment..."
source venv/bin/activate

echo "Upgrading pip..."
pip install --upgrade pip

echo "Installing dependencies from pyproject.toml..."
pip install -e .

echo ""
echo "✓ Virtual environment setup complete!"
echo ""
echo "To activate the environment, run:"
echo "  source venv/bin/activate"
echo ""
echo "To run the search proxy:"
echo "  venv/bin/python3 search-proxy.py"

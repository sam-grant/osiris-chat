# Minimal Ollama chat example

A bare-bones web chat interface for Ollama.

## Demo

![First Chat](../docs/first_chat.png)

## What's included

- `chat.html` - Minimal HTML interface with basic styling
- `app.js` - Simple JavaScript for chat functionality
- `start-all.sh` - Script to start Ollama and HTTP server
- `stop-all.sh` - Script to stop all services

## Quick start

### 1. Prerequisites

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a model
ollama pull llama3.2:latest
```

### 2. Start services

```bash
./start-all.sh
```

### 3. Open chat

Navigate to `http://localhost:8000/chat.html`

## Stop services

```bash
./stop-all.sh
```

## Architecture

This is the minimum needed for a working Ollama web interface:
- Static HTML/JS frontend served by Python's built-in HTTP server
- Direct fetch requests from browser to Ollama API
- No backend, no frameworks, no build tools
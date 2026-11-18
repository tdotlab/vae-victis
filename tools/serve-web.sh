#!/usr/bin/env bash
# Serve build/web on http://localhost:8060 (single-threaded build: no special headers needed).
cd "$(dirname "$0")/../build/web" && exec python -m http.server "${1:-8060}"

#!/bin/sh
# Minflair — Unified widget toggle utility
WIDGET_ID="${1:-}"

if [ -z "$WIDGET_ID" ]; then
  echo "Usage: $(basename "$0") <widget_id>" >&2
  exit 1
fi

SOCKET_PATH="/tmp/quickshell_${WIDGET_ID}"

if [ -S "$SOCKET_PATH" ] && echo "" | socat - UNIX-CONNECT:"$SOCKET_PATH" 2>/dev/null; then
  exit 0
fi

# If socket exists but connection failed (stale socket), clean it up
if [ -S "$SOCKET_PATH" ]; then
  rm -f "$SOCKET_PATH"
fi

# Fallback to Quickshell IPC
qs ipc call widgets toggle "$WIDGET_ID" 2>/dev/null || true

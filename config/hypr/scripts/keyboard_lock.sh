#!/bin/bash

MODE="${1:-caps}"

if [ "$MODE" = "num" ]; then
  STATE_FILE="/tmp/numlock_state"
  PREV_STATE=$(cat "$STATE_FILE" 2>/dev/null)
  if [ -z "$PREV_STATE" ]; then
    PREV_STATE=$(cat /sys/class/leds/input*::numlock/brightness 2>/dev/null | head -n 1)
  fi

  NEW_STATE=""
  for i in {1..8}; do
    sleep 0.025
    CUR=$(cat /sys/class/leds/input*::numlock/brightness 2>/dev/null | head -n 1)
    if [ -n "$CUR" ] && [ "$CUR" != "$PREV_STATE" ]; then
      NEW_STATE="$CUR"
      break
    fi
  done

  if [ -z "$NEW_STATE" ]; then
    [ "$PREV_STATE" = "1" ] && NEW_STATE="0" || NEW_STATE="1"
  fi

  echo "$NEW_STATE" >"$STATE_FILE"

  if [ "$NEW_STATE" = "1" ]; then
    qs ipc call osd showMessage "Num Lock" "ON" "lock" 2>/dev/null || true
  else
    qs ipc call osd showMessage "Num Lock" "OFF" "lock" 2>/dev/null || true
  fi
else
  STATE_FILE="/tmp/capslock_state"
  PREV_STATE=$(cat "$STATE_FILE" 2>/dev/null)
  if [ -z "$PREV_STATE" ]; then
    PREV_STATE=$(cat /sys/class/leds/input*::capslock/brightness 2>/dev/null | head -n 1)
  fi

  NEW_STATE=""
  for i in {1..8}; do
    sleep 0.025
    CUR=$(cat /sys/class/leds/input*::capslock/brightness 2>/dev/null | head -n 1)
    if [ -n "$CUR" ] && [ "$CUR" != "$PREV_STATE" ]; then
      NEW_STATE="$CUR"
      break
    fi
  done

  if [ -z "$NEW_STATE" ]; then
    [ "$PREV_STATE" = "1" ] && NEW_STATE="0" || NEW_STATE="1"
  fi

  echo "$NEW_STATE" >"$STATE_FILE"

  if [ "$NEW_STATE" = "1" ]; then
    qs ipc call osd showMessage "Caps Lock" "ON" "caps-lock-filled" 2>/dev/null || true
  else
    qs ipc call osd showMessage "Caps Lock" "OFF" "caps-lock" 2>/dev/null || true
  fi
fi

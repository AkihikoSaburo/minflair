#!/bin/bash

MIN_BRIGHTNESS=5

CURRENT=$(brightnessctl -m | awk -F, '{print $4}' | tr -d '%')

case "$1" in
up)
  if [ "$CURRENT" -ge 100 ]; then
    exit 0
  fi
  brightnessctl set 5%+
  ;;
down)
  if [ "$CURRENT" -le "$MIN_BRIGHTNESS" ]; then
    exit 0
  elif [ $((CURRENT - 5)) -lt "$MIN_BRIGHTNESS" ]; then
    brightnessctl set "${MIN_BRIGHTNESS}%"
  else
    brightnessctl set 5%-
  fi
  ;;
esac

BRIGHTNESS=$(brightnessctl -m | awk -F, '{print $4}' | tr -d '%')

qs ipc call osd showBrightness "$BRIGHTNESS" 2>/dev/null || true

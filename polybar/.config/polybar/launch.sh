#!/usr/bin/env bash

# Terminate already running bar instances
killall -q polybar
# If all your bars have ipc enabled, you can also use 
# polybar-msg cmd quit

# Launch example bar
echo "---" | tee -a /tmp/polybar-example.log 
polybar main 2>&1 | tee -a /tmp/polybar-example.log & disown

echo "Bars launched..."

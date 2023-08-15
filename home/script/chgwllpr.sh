#!/bin/bash
swww img $(find ~/Pictures/wllppr/. -name '*.*g' | shuf -n1) --transition-step 144 --transition-fps 144 --transition-type center
# swaybg -i $(find ~/Pictures/wllppr/. -name "*.*g" | shuf -n1) -m fill

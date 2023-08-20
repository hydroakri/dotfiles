#!/bin/bash
swww img $(find ~/Pictures/wllppr/. -name '*.*g' | shuf -n1) --transition-step 144 --transition-type wipe --transition-angle 61.8
# swaybg -i $(find ~/Pictures/wllppr/. -name "*.*g" | shuf -n1) -m fill

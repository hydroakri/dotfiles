#!/bin/bash
current_hour=$(date +"%H")
if [ "$current_hour" -ge 6 ] && [ "$current_hour" -lt 18 ]; then
    wofi -s /home/$USER/.config/wofi/style-light.css
else
    wofi -s /home/$USER/.config/wofi/style-dark.css
fi
exit 0

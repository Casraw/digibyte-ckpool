#!/bin/bash

# Kurzes Delay, um sporadische Timeouts zu vermeiden
sleep 5

# Beispiel-Prüfung, ob digibyted noch läuft
if pgrep digibyted > /dev/null
then
  exit 0
else
  exit 1
fi

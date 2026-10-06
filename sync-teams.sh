#!/bin/sh
# Verteilt den gemeinsamen App-Code (index.html + Icons) in alle Team-Ordner.
# Pro Team bleiben config.js und manifest.webmanifest eigenständig.
# Vor jedem Push ausführen.
set -e
cd "$(dirname "$0")"
for team in steinhausen; do
  cp index.html "$team/index.html"
  mkdir -p "$team/icons" && cp icons/*.png "$team/icons/"
  echo "✓ $team"
done

#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'Run this on your Mac.'; exit 1; }
plist_path="$HOME/Library/LaunchAgents/dev.kurorekishi.sync.plist"
if [[ -f "$plist_path" ]]; then
  launchctl bootout "gui/$(id -u)" "$plist_path" || true
  rm "$plist_path"
fi
echo 'Automatic sync disabled. Repository files are preserved.'

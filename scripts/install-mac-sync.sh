#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Darwin ]] || { echo 'Run this installer on your Mac.'; exit 1; }
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
# Validate access once interactively before scheduling background fetches.
cd "$repo_dir"
git ls-remote --exit-code origin refs/heads/main >/dev/null
mkdir -p "$HOME/Library/LaunchAgents" "$repo_dir/.mac-sync"
plist_path="$HOME/Library/LaunchAgents/dev.kurorekishi.sync.plist"
if [[ -e "$plist_path" ]]; then
  echo "Already installed: $plist_path. Uninstall first to change its checkout."
  exit 1
fi
export CHRONICLE_REPO_DIR="$repo_dir" CHRONICLE_PLIST_PATH="$plist_path"
/usr/bin/python3 - <<'PY'
import os, plistlib
repo=os.environ['CHRONICLE_REPO_DIR']
with open(os.environ['CHRONICLE_PLIST_PATH'], 'wb') as f:
    plistlib.dump({
        'Label':'dev.kurorekishi.sync',
        'ProgramArguments':['/bin/bash',repo+'/scripts/sync-mac.sh'],
        'WorkingDirectory':repo,
        'StartInterval':60,
        'RunAtLoad':True,
        'StandardOutPath':repo+'/.mac-sync/sync.log',
        'StandardErrorPath':repo+'/.mac-sync/sync-error.log'
    }, f)
PY
launchctl bootstrap "gui/$(id -u)" "$plist_path"
echo 'Installed: fetch main every 60 seconds while logged in. See .mac-sync/*.log.'

#!/bin/sh
# One-shot setup for Andon (from a cloned repository).
#   ./setup.sh                ... build, install to /Applications, and
#                                 generate agent configs into build/config/
#   ./setup.sh --config-only  ... only generate the configs
#
# Config generation is delegated to generate-configs.sh. Your own config
# files (~/.claude/settings.json etc.) are never modified.
set -e

cd "$(dirname "$0")"

if [ "$1" != "--config-only" ]; then
    ./make-app.sh install
fi

./generate-configs.sh

cat <<EOF
  Launch the app: open /Applications/Andon.app
  To start at login, add it in System Settings > General > Login Items.
EOF

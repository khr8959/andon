#!/bin/sh
# Generate agent configs by expanding the path placeholder (/PATH/TO/andon)
# in examples/ to the actual install location. Never touches your own config
# files (~/.claude/settings.json etc.).
#
# This script lives both at the repository root and inside
# Andon.app/Contents/Resources, and works from either location:
#   from the repo : ./generate-configs.sh
#                   -> outputs to build/config/ (hooks point into the repo)
#   from the app  : /Applications/Andon.app/Contents/Resources/generate-configs.sh
#                   -> outputs to ~/Library/Application Support/Andon/config/
#                      (hooks point into the app bundle; no repo needed)
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
PLACEHOLDER="/PATH/TO/andon"

case "${ROOT}" in
    *"|"*)
        echo "Error: cannot generate configs because the path contains '|': ${ROOT}" >&2
        exit 1
        ;;
    *.app/Contents/Resources)
        OUT="${HOME}/Library/Application Support/Andon/config"
        ;;
    *)
        OUT="${ROOT}/build/config"
        ;;
esac

echo "==> Generating configs: ${OUT}"
rm -rf "${OUT}"
mkdir -p "${OUT}/antigravity-plugin"

for f in "${ROOT}"/examples/*; do
    sed "s|${PLACEHOLDER}|${ROOT}|g" "$f" > "${OUT}/$(basename "$f")"
done
for f in "${ROOT}"/antigravity-plugin/*; do
    sed "s|${PLACEHOLDER}|${ROOT}|g" "$f" > "${OUT}/antigravity-plugin/$(basename "$f")"
done

cat <<EOF

==> Done. Apply the configs for the agents you use:

  Claude Code : merge claude-settings-hooks.json into ~/.claude/settings.json
  Codex CLI   : merge codex-hooks.json into ~/.codex/hooks.json, then run
                /hooks inside interactive codex to trust the hook
  Cursor      : merge cursor-hooks.json into ~/.cursor/hooks.json
  Copilot CLI : copy copilot-hooks.json to ~/.copilot/hooks/andon.json
  Antigravity : register the poller with launchd (recommended; detects the
                red "waiting for approval" state):
                  cp "${OUT}/andon-agy-poller.plist" ~/Library/LaunchAgents/
                  launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/andon-agy-poller.plist
                Or use hooks instead (do not combine with the poller):
                  cd "${OUT}/antigravity-plugin" && agy plugin install .

  The generated configs reference scripts under this location by absolute path:
    ${ROOT}/hooks/
  If you move or delete it, re-run this script and re-apply the configs.
EOF

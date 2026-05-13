#!/usr/bin/env bash
## Install the headless Linux Godot build pinned by $GODOT_VERSION into
## /usr/local/bin/godot. Intended to run inside the CI workflow (ubuntu-latest)
## where the validate.yml `env:` block defines GODOT_VERSION as the single
## source of truth for the engine version. Fails loudly if GODOT_VERSION is
## unset so the script cannot be silently invoked without a pin.
set -euo pipefail

: "${GODOT_VERSION:?GODOT_VERSION must be set (e.g. 4.6.2-stable) — see validate.yml env block}"

GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"

wget -q "$GODOT_URL" -O /tmp/godot.zip
unzip -q /tmp/godot.zip -d /tmp/godot
sudo mv "/tmp/godot/Godot_v${GODOT_VERSION}_linux.x86_64" /usr/local/bin/godot
sudo chmod +x /usr/local/bin/godot
godot --version

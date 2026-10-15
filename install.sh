#!/usr/bin/env bash
# Install or update the widget and the service that keeps its quota files fresh.
set -euo pipefail
cd "$(dirname "$0")"

kpackagetool6 -t Plasma/Applet -u package >/dev/null 2>&1 || kpackagetool6 -t Plasma/Applet -i package
install -Dm755 service/claude-limits-update ~/.local/bin/claude-limits-update
install -Dm644 -t ~/.config/systemd/user service/claude-limits.service service/claude-limits.timer
systemctl --user daemon-reload
systemctl --user enable --now claude-limits.timer

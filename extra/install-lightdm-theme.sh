#!/usr/bin/env bash
# Deprecated wrapper — use apply-look.sh (single script for wallpaper + greeter).
exec "$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)/i3/.config/i3/apply-look.sh"

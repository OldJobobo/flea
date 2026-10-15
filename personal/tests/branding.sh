#!/usr/bin/env bash
# Inspect a transformed bundle using disposable settings, never the daily profile.
set -eu
cd "$(dirname "$0")/../.."
. tools/flea-sandbox-guard
bundle=${TICK_BUNDLE:-$(readlink -f .local-builds/current)}
build=$(python3 - "$bundle/manifest.json" <<'PY'
import json
import sys
from pathlib import Path
manifest = json.loads(Path(sys.argv[1]).read_text())
assert manifest["brand"]["name"] == "Tick", "A Tick bundle is required"
print(manifest["commit"][:12])
PY
)
fixture=$(mktemp -d "$FIXTURE_ROOT/tick-branding-XXXXXX")
sandbox_require "$fixture"
: > "$fixture/$SANDBOX_MARKER"
trap 'sandbox_remove "$fixture"' EXIT
mkdir -p "$fixture/config" "$fixture/home" "$fixture/state" "$fixture/settings" "$fixture/runtime"
chmod 700 "$fixture/runtime"
ln -s "$bundle/ui" "$fixture/config/flea"
ln -s "$(readlink -f "$bundle/ui/boot/Commons")" "$fixture/config/Commons"
ln -s "$(readlink -f "$bundle/ui/boot/Ui")" "$fixture/config/Ui"
cp personal/tests/branding.qml "$fixture/config/shell.qml"
set +e
output=$(env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    HOME="$fixture/home" XDG_STATE_HOME="$fixture/state" XDG_CONFIG_HOME="$fixture/settings" \
    XDG_DATA_HOME="$fixture/home/data" XDG_CACHE_HOME="$fixture/home/cache" XDG_RUNTIME_DIR="$fixture/runtime" \
    FLEA_BIN="$bundle/bin/flea" FLEA_UI="$bundle/ui" TICK_BUILD="$build" \
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic QT_FORCE_STDERR_LOGGING=1 \
    timeout 30 qs -p "$fixture/config" 2>&1)
status=$?
set -e
printf '%s\n' "$output"
[ "$status" -eq 143 ] || { echo "Tick branding: unexpected qs exit $status"; exit 1; }
printf '%s\n' "$output" | grep -qE 'TICK DONE checks=(3[0-9]|4[0-9]) failed=0'
if printf '%s\n' "$output" | grep -E 'TypeError|ReferenceError|WARN|ERROR|TICK FAIL' \
    | grep -vF '$HYPRLAND_INSTANCE_SIGNATURE is unset. Cannot connect to hyprland.' \
    | grep -vF 'This plugin does not support setting window masks'; then
    echo 'Tick branding: unexpected runtime diagnostic'; exit 1
fi
printf 'Tick branding: About, safety guards, theme-colored artwork and seven icon selections passed\n'

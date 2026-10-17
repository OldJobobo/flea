#!/usr/bin/env bash
# Real Glyphs, settings selector, lazy reader and custom-file reloads; no real user state.
set -eu
. "$(dirname "$0")/../tools/flea-sandbox-guard"
. "$(dirname "$0")/headless-commons.sh"
cd "$(dirname "$0")/.."
python3 -B tests/icon-geometry.py
command -v qs >/dev/null || { echo 'icon-packs: qs is required'; exit 1; }
bin=${FLEA_BIN:-$PWD/target/debug/flea}
[ -x "$bin" ] || { echo "icon-packs: build the backend first: $bin"; exit 1; }
fixture=$(mktemp -d "$FIXTURE_ROOT/flea-icon-packs-XXXXXX")
sandbox_require "$fixture"
: > "$fixture/$SANDBOX_MARKER"
trap 'sandbox_remove "$fixture"' EXIT
mkdir -p "$fixture/config" "$fixture/home" "$fixture/state" "$fixture/settings/flea/icons" "$fixture/runtime"
chmod 700 "$fixture/runtime"
ln -s "$PWD/ui" "$fixture/config/flea"
headless_commons "$fixture" || exit 1
ln -s "$(readlink -f ui/boot/Ui)" "$fixture/config/Ui"
run_probe() {
    local output status
    cp "$1" "$fixture/config/shell.qml"
    set +e
    output=$(env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
        HOME="$fixture/home" XDG_STATE_HOME="$fixture/state" XDG_CONFIG_HOME="$fixture/settings" \
        XDG_DATA_HOME="$fixture/home/data" XDG_CACHE_HOME="$fixture/home/cache" XDG_RUNTIME_DIR="$fixture/runtime" \
        FLEA_BIN="$bin" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic QT_FORCE_STDERR_LOGGING=1 \
        timeout 30 qs -p "$fixture/config" 2>&1)
    status=$?
    set -e
    printf '%s\n' "$output"
    [ "$status" -eq 143 ] || { echo "icon-packs: unexpected qs exit $status"; exit 1; }
    printf '%s\n' "$output" | grep -q "$2"
    if printf '%s\n' "$output" | grep -E 'TypeError|ReferenceError|WARN|ERROR|ICONPACKS FAIL' \
        | grep -vF '$HYPRLAND_INSTANCE_SIGNATURE is unset. Cannot connect to hyprland.' \
        | grep -vF 'This plugin does not support setting window masks'; then
        echo 'icon-packs: unexpected runtime diagnostic'; exit 1
    fi
}
run_probe tests/icon-packs.qml 'ICONPACKS DONE checks=58 failed=0'
python3 - "$fixture/state/flea/ui.json" <<'PY'
import json
import sys
from pathlib import Path
assert json.loads(Path(sys.argv[1]).read_text())["display"]["iconSet"] == "flea"
PY
for pack in tabler lucide iconoir heroicons phosphor feather; do
    XDG_STATE_HOME="$fixture/state" "$bin" --ui-state "{\"display\":{\"iconSet\":\"$pack\"}}" >/dev/null
    export ICON_PACK_STARTUP="$pack"
    run_probe tests/icon-packs-startup.qml 'ICONPACKS STARTUP ok=true'
done
printf 'icon-packs: 58 runtime checks, persisted selection and six next-process startups passed\n'

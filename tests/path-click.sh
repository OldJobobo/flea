#!/usr/bin/env bash
# Real pointer/key delivery into shipped path chrome; no real user settings or file operations.
set -eu
. "$(dirname "$0")/../tools/flea-sandbox-guard"
. "$(dirname "$0")/headless-commons.sh"
cd "$(dirname "$0")/.."
fixture=$(mktemp -d "$FIXTURE_ROOT/flea-path-click-XXXXXX")
sandbox_require "$fixture"
: > "$fixture/$SANDBOX_MARKER"
trap 'sandbox_remove "$fixture"' EXIT
mkdir -p "$fixture/config" "$fixture/home" "$fixture/state" "$fixture/settings" "$fixture/runtime"
chmod 700 "$fixture/runtime"
ln -s "$PWD/ui" "$fixture/config/flea"
headless_commons "$fixture" || exit 1
ln -s "$(readlink -f ui/boot/Ui)" "$fixture/config/Ui"
cp tests/path-click.qml "$fixture/config/shell.qml"
set +e
output=$(env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    HOME="$fixture/home" XDG_STATE_HOME="$fixture/state" XDG_CONFIG_HOME="$fixture/settings" \
    XDG_DATA_HOME="$fixture/home/data" XDG_CACHE_HOME="$fixture/home/cache" XDG_RUNTIME_DIR="$fixture/runtime" \
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic QT_FORCE_STDERR_LOGGING=1 \
    timeout 35 qs -p "$fixture/config" 2>&1)
status=$?
set -e
printf '%s\n' "$output"
[ "$status" -eq 143 ] || { echo "path-click: unexpected qs exit $status"; exit 1; }
printf '%s\n' "$output" | grep -qE 'PATHCLICK DONE checks=[1-9][0-9]+ failed=0'
if printf '%s\n' "$output" | grep -E 'TypeError|ReferenceError|WARN|ERROR|PATHCLICK FAIL' \
    | grep -vF '$HYPRLAND_INSTANCE_SIGNATURE is unset. Cannot connect to hyprland.' \
    | grep -vF 'This plugin does not support setting window masks'; then
    echo 'path-click: unexpected runtime diagnostic'; exit 1
fi
printf 'path-click: single-click editing, click-away focus, click-through, breadcrumbs and suggestions passed\n'

#!/usr/bin/env bash
# Tooltips in the real WindowBody, including its inactive full-window overlay layers.
set -eu
. "$(dirname "$0")/../tools/flea-sandbox-guard"
cd "$(dirname "$0")/.."
case "${1-}" in ""|--native) ;; *) echo 'usage: mouse-window.sh [--native]'; exit 2;; esac
fixture=$(mktemp -d "$FIXTURE_ROOT/flea-mouse-window-XXXXXX")
sandbox_require "$fixture"
: > "$fixture/$SANDBOX_MARKER"
trap 'sandbox_remove "$fixture"' EXIT
mkdir -p "$fixture"/{config,home,state,settings,data,cache,runtime,files}
chmod 700 "$fixture/runtime"
touch "$fixture/files"/{a,b,c}.txt
ln -s "$(readlink -f ui/boot/Commons)" "$fixture/config/Commons"
ln -s "$(readlink -f ui/boot/Ui)" "$fixture/config/Ui"
ln -s "$PWD/ui/boot/fleatab.qml" "$fixture/config/fleatab.qml"
cp tests/mouse-window.qml "$fixture/config/shell.qml"
platform=(env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen)
if [ "${1-}" = --native ]; then
    display=${WAYLAND_DISPLAY:?native mode requires WAYLAND_DISPLAY}
    [[ "$display" = /* ]] || display="${XDG_RUNTIME_DIR:?}/$display"
    platform=(env -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$display")
fi
set +e
output=$("${platform[@]}" HOME="$fixture/home" XDG_STATE_HOME="$fixture/state" XDG_CONFIG_HOME="$fixture/settings" \
    XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" XDG_RUNTIME_DIR="$fixture/runtime" \
    MOUSE_WINDOW_UI="$PWD/ui" FLEA_BIN="$PWD/target/debug/flea" FLEA_PATH="$fixture/files" \
    QT_QPA_PLATFORMTHEME=generic QT_FORCE_STDERR_LOGGING=1 \
    dbus-run-session -- bash -c 'timeout 25 qs -p "$1" > "$2" 2>&1' _ "$fixture/config" "$fixture/qs.log" 2>"$fixture/bus.log")
status=$?
set -e
output=$(<"$fixture/qs.log")
printf '%s\n' "$output"
[ "$status" -eq 143 ] || { echo "mouse-window: unexpected qs exit $status"; exit 1; }
printf '%s\n' "$output" | grep -qE 'MOUSEWINDOW DONE checks=[1-9][0-9]* failed=0'
if printf '%s\n' "$output" | grep -E 'TypeError|ReferenceError|WARN|ERROR|MOUSEWINDOW FAIL' \
    | grep -vF '$HYPRLAND_INSTANCE_SIGNATURE is unset. Cannot connect to hyprland.' \
    | grep -vF 'This plugin does not support setting window masks' \
    | grep -vF 'Failed to register with host portal QDBusError("org.freedesktop.portal.Error.Failed", "Could not register app ID: Connection already associated with an application ID")'; then
    echo 'mouse-window: unexpected runtime diagnostic'; exit 1
fi
printf 'mouse-window: real chrome/listing hints, overlay blocking and focus passed\n'

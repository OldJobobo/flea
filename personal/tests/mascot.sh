#!/usr/bin/env bash
# Exercise the Tick-only overlaid empty state, with disposable settings and no backend.
set -eu
cd "$(dirname "$0")/../.."
. tools/flea-sandbox-guard
bundle=${TICK_BUNDLE:-$(readlink -f .local-builds/current)}
test -f "$bundle/ui/TickIdleMotion.qml" || { echo 'Tick mascot: an animated Tick bundle is required'; exit 1; }
if [ -n "${TICK_MASCOT_CAPTURE:-}" ]; then
    capture=$(readlink -f "$TICK_MASCOT_CAPTURE")
    case "$capture" in "$PWD/.local-builds/"*) ;; *) echo 'Tick mascot: captures must stay under .local-builds'; exit 1;; esac
    test -d "$capture"
    export TICK_MASCOT_CAPTURE="$capture"
fi
fixture=$(mktemp -d "$FIXTURE_ROOT/tick-mascot-XXXXXX")
sandbox_require "$fixture"
: > "$fixture/$SANDBOX_MARKER"
trap 'sandbox_remove "$fixture"' EXIT
mkdir -p "$fixture"/{config,home,state,settings,runtime}
chmod 700 "$fixture/runtime"
ln -s "$bundle/ui" "$fixture/config/flea"
ln -s "$(readlink -f "$bundle/ui/boot/Commons")" "$fixture/config/Commons"
ln -s "$(readlink -f "$bundle/ui/boot/Ui")" "$fixture/config/Ui"
cp personal/tests/mascot.qml "$fixture/config/shell.qml"
set +e
output=$(env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    HOME="$fixture/home" XDG_STATE_HOME="$fixture/state" XDG_CONFIG_HOME="$fixture/settings" \
    XDG_DATA_HOME="$fixture/home/data" XDG_CACHE_HOME="$fixture/home/cache" XDG_RUNTIME_DIR="$fixture/runtime" \
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic QT_FORCE_STDERR_LOGGING=1 \
    timeout 25 qs -p "$fixture/config" 2>&1)
status=$?
set -e
printf '%s\n' "$output"
[ "$status" -eq 143 ] || { echo "Tick mascot: unexpected qs exit $status"; exit 1; }
printf '%s\n' "$output" | grep -qE 'MASCOT DONE checks=[1-9][0-9]* failed=0'
if printf '%s\n' "$output" | grep -E 'TypeError|ReferenceError|WARN|ERROR|MASCOT FAIL' \
    | grep -vF '$HYPRLAND_INSTANCE_SIGNATURE is unset. Cannot connect to hyprland.' \
    | grep -vF 'This plugin does not support setting window masks'; then
    echo 'Tick mascot: unexpected runtime diagnostic'; exit 1
fi
printf 'Tick mascot: arrival, three gestures, rest, hidden release and reduced motion passed\n'

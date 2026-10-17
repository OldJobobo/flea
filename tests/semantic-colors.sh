#!/usr/bin/env bash
# Real Qt palette/delegate proof in a guarded fixture; never touches live preferences.
set -eu
. "$(dirname "$0")/../tools/flea-sandbox-guard"
. "$(dirname "$0")/headless-commons.sh"
cd "$(dirname "$0")/.."
command -v qs >/dev/null || { echo 'semantic-colors: qs is required'; exit 1; }
sandbox_root_ok
root=$(mktemp -d "$FIXTURE_ROOT/flea-semantic-colors-XXXXXX")
sandbox_require "$root"
: > "$root/$SANDBOX_MARKER"
pids=()
cleanup() {
    local pid
    for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
    for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
    sandbox_remove "$root"
}
trap cleanup EXIT
mkdir -p "$root/home/.config" "$root/state" "$root/cache" "$root/data" "$root/runtime" "$root/config"
chmod 700 "$root/runtime"
ln -s "$PWD/ui" "$root/config/flea"
headless_commons "$root" "$root/config/Commons" || exit 1
ln -s "$(readlink -f ui/boot/Ui)" "$root/config/Ui"
cp tests/semantic-colors.qml "$root/config/shell.qml"
python3 -I - "$root/config/palettes.js" <<'PY'
import json, sys
from pathlib import Path
paths = sorted(Path('/usr/share/omarchy/themes').glob('*/colors.toml'))
paths += [Path('tests/fixtures/cool-dawn/colors.toml'), Path('tests/fixtures/sunset/colors.toml')]
assert len(paths) >= 2
with open(sys.argv[1], 'w') as out:
    out.write('var PALETTES = ' + json.dumps([{'name': p.parent.name, 'body': p.read_text()} for p in paths]) + '\n')
PY
code=0
env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/state" \
    XDG_CACHE_HOME="$root/cache" XDG_DATA_HOME="$root/data" XDG_RUNTIME_DIR="$root/runtime" \
    SEMANTIC_ROOT="$root" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
    QT_QUICK_BACKEND=software QT_QPA_UPDATE_IDLE_TIME=1 QT_FORCE_STDERR_LOGGING=1 \
    timeout 60 qs -p "$root/config" > "$root/output" 2>&1 || code=$?
# Retain evidence inside the checkout, not in an installed configuration directory.
mkdir -p target/semantic-checks
cp "$root/output" target/semantic-checks/qml.log
if [ -f "$root/proof.png" ]; then cp "$root/proof.png" target/semantic-checks/proof.png; fi
if [ "$code" -ne 0 ] || ! grep -qE 'SEMANTIC DONE checks=[1-9][0-9]* failed=0' "$root/output"; then
    printf 'semantic-colors: real Qt probe failed (exit %s)\n' "$code"
    tail -35 "$root/output"
    exit 1
fi
if grep -E 'SEMANTIC FAIL|TypeError|ReferenceError|ERROR|WARN' "$root/output" | grep -vF 'This plugin does not support setting window masks'; then
    echo 'semantic-colors: unexpected Qt diagnostic'
    exit 1
fi
grep 'SEMANTIC DONE' "$root/output"
binary="$PWD/target/debug/flea"
[ -x "$binary" ] || { echo 'semantic-colors: run cargo build first for persistence probes'; exit 1; }
mkdir -p "$root/state/flea" "$root/writer"
HOME="$root/home" XDG_STATE_HOME="$root/state" "$binary" --ui-state '{"display":{"semanticColors":false,"textSize":{"mode":16}}}' > "$root/initial.json"
cp tests/semantic-state.qml "$root/config/shell.qml"
cp tests/semantic-state.qml "$root/writer/shell.qml"
ln -s "$PWD/ui" "$root/writer/flea"
ln -s "$root/config/Commons" "$root/writer/Commons"
ln -s "$(readlink -f ui/boot/Ui)" "$root/writer/Ui"
launch_state() {
    env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
        HOME="$root/home" XDG_CONFIG_HOME="$root/home/.config" XDG_STATE_HOME="$root/state" \
        XDG_CACHE_HOME="$root/cache" XDG_DATA_HOME="$root/data" XDG_RUNTIME_DIR="$root/runtime" \
        FLEA_BIN="$binary" SEMANTIC_WRITER="$2" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
        QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1 timeout 30 qs -p "$1"
}
wait_line() {
    local attempt
    for ((attempt=0; attempt<300; attempt++)); do
        if grep -q "$2" "$1"; then return 0; fi
        sleep 0.05
    done
    echo "semantic-colors: missing $2"
    tail -20 "$1"
    return 1
}
launch_state "$root/config" 0 > "$root/reader.log" 2>&1 & pids+=("$!")
wait_line "$root/reader.log" 'SEMANTIC_STATE READY'
launch_state "$root/writer" 1 > "$root/writer.log" 2>&1 & pids+=("$!")
wait_line "$root/reader.log" 'SEMANTIC_STATE ON'
wait_line "$root/writer.log" 'SEMANTIC_STATE ON'
HOME="$root/home" XDG_STATE_HOME="$root/state" "$binary" --ui-state > "$root/saved.json"
python3 -I - "$root/saved.json" <<'PY'
import json, sys
display = json.load(open(sys.argv[1]))['display']
assert display['semanticColors'] is True
assert display['textSize']['mode'] == 16
PY
HOME="$root/home" XDG_STATE_HOME="$root/state" "$binary" --ui-state '{"display":{"semanticColors":false}}' > "$root/restored.json"
wait_line "$root/reader.log" 'SEMANTIC_STATE OFF DONE'
wait_line "$root/writer.log" 'SEMANTIC_STATE OFF DONE'
for pid in "${pids[@]}"; do wait "$pid"; done
pids=()
cp "$root/reader.log" target/semantic-checks/state-reader.log
cp "$root/writer.log" target/semantic-checks/state-writer.log
if grep -E 'FAIL|WARN|ERROR|TypeError|ReferenceError' "$root/reader.log" "$root/writer.log"; then exit 1; fi
echo 'SEMANTIC_STATE PASS QML save, sibling preservation, next-process read and two-window live refresh'

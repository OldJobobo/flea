#!/usr/bin/env bash
# Palette-driven SVGs in the actual shipped image slots; no live user state.
set -eu
. "$(dirname "$0")/../tools/flea-sandbox-guard"
cd "$(dirname "$0")/.."
bin=${FLEA_BIN:-$PWD/target/debug/flea}
[ -x "$bin" ] || { echo "adaptive-icons: build the backend first: $bin"; exit 1; }
command -v qs >/dev/null || { echo 'adaptive-icons: qs is required'; exit 1; }
fixture="$FIXTURE_ROOT/flea-adaptive-icons-$$"
sandbox_make "$fixture"
trap 'sandbox_remove "$fixture"' EXIT
mkdir -p "$fixture"/{config,home,state,settings,runtime,data,empty}
chmod 700 "$fixture/runtime"
ln -s "$PWD/ui" "$fixture/config/flea"
ln -s "$(readlink -f ui/boot/Commons)" "$fixture/config/Commons"
ln -s "$(readlink -f ui/boot/Ui)" "$fixture/config/Ui"
ln -s "$PWD/tests/js" "$fixture/config/testjs"
python3 - "$fixture" <<'PY'
from pathlib import Path
import struct,sys,zlib
root=Path(sys.argv[1]); theme=root/'home/.local/state/omarchy/current/theme';theme.mkdir(parents=True)
(theme.parent/'theme.name').write_text('Graphite\n')
(theme/'colors.toml').write_text('background = "#171b22"\nforeground = "#dce3ed"\naccent = "#85a9e8"\nselection = "#344660"\n')
icons=root/'data/icons/Preserve';(icons/'scalable/apps').mkdir(parents=True)
(icons/'index.theme').write_text('[Icon Theme]\nName=Preserve\nDirectories=scalable/apps\n[scalable/apps]\nSize=64\nType=Scalable\nMinSize=1\nMaxSize=512\n')
(icons/'scalable/apps/keep-brand.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64"><circle cx="32" cy="32" r="28" fill="#f04470"/></svg>')
def chunk(kind,body):
 return struct.pack('>I',len(body))+kind+body+struct.pack('>I',zlib.crc32(kind+body)&0xffffffff)
(root/'thumb.png').write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',1,1,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b'\x00\xff\xff\xff'))+chunk(b'IEND',b''))
PY
for mode in normal restart catalogue; do
    restart=''; [ "$mode" != restart ] || restart=1
    probe=tests/adaptive-icons.qml
    [ "$mode" != catalogue ] || probe=tests/adaptive-render.qml
    cp "$probe" "$fixture/config/shell.qml"
    set +e
    output=$(env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u FLEA_QT_THEME \
        HOME="$fixture/home" XDG_STATE_HOME="$fixture/state" XDG_CONFIG_HOME="$fixture/settings" \
        XDG_DATA_HOME="$fixture/data" XDG_DATA_DIRS="$fixture/empty" XDG_CACHE_HOME="$fixture/home/cache" XDG_RUNTIME_DIR="$fixture/runtime" \
        FLEA_BIN="$bin" QS_ICON_THEME=Preserve ADAPTIVE_ICON_RESTART="$restart" ADAPTIVE_ICON_THUMB="$fixture/thumb.png" \
        QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic QT_QUICK_BACKEND=software QT_FORCE_STDERR_LOGGING=1 \
        timeout 45 qs -p "$fixture/config" 2>&1)
    status=$?
    set -e
    printf '%s\n' "$output"
    [ "$status" -eq 143 ] || { echo "adaptive-icons: unexpected qs exit $status"; exit 1; }
    printf '%s\n' "$output" | grep -qE 'ADAPTIVEICONS DONE checks=[1-9][0-9]* failed=0'
    if printf '%s\n' "$output" | grep -E 'TypeError|ReferenceError|WARN|ERROR|ADAPTIVEICONS FAIL' \
        | grep -vF '$HYPRLAND_INSTANCE_SIGNATURE is unset. Cannot connect to hyprland.' \
        | grep -vF 'This plugin does not support setting window masks'; then
        echo 'adaptive-icons: unexpected runtime diagnostic'; exit 1
    fi
done
printf 'adaptive-icons: real SVG decoding, theme watch, cache reuse, hidden idleness, fallback, row budgets and persistence passed\n'

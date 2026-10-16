#!/usr/bin/env bash
# Actual installed-theme metadata and shipped list/column/grid renderers, in disposable state.
set -eu
. "$(dirname "$0")/../tools/flea-sandbox-guard"
cd "$(dirname "$0")/.."
bin=${FLEA_BIN:-$PWD/target/debug/flea}
[ -x "$bin" ] || { echo "desktop-icons: build the backend first: $bin"; exit 1; }
fixture=$(mktemp -d "$FIXTURE_ROOT/flea-desktop-icons-XXXXXX")
sandbox_require "$fixture"
: > "$fixture/$SANDBOX_MARKER"
trap 'sandbox_remove "$fixture"' EXIT
mkdir -p "$fixture/config" "$fixture/home" "$fixture/state" "$fixture/settings" "$fixture/runtime" "$fixture/empty"
chmod 700 "$fixture/runtime"
ln -s "$PWD/ui" "$fixture/config/flea"
ln -s "$(readlink -f ui/boot/Commons)" "$fixture/config/Commons"
ln -s "$(readlink -f ui/boot/Ui)" "$fixture/config/Ui"
cp tests/desktop-icons.qml "$fixture/config/shell.qml"
python3 - "$fixture" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); icons=root/'data #?'/ 'icons'
metadata='[Icon Theme]\nName={name}\n{extra}Directories=scalable/places,scalable/mimetypes\n[scalable/places]\nSize=48\nType=Scalable\nMinSize=1\nMaxSize=512\n[scalable/mimetypes]\nSize=48\nType=Scalable\nMinSize=1\nMaxSize=512\n'
for name,extra in [('Child','Inherits=Parent\n'),('Parent','Hidden=true\n'),('Blue','')]:
 base=icons/name;base.mkdir(parents=True)
 (base/'index.theme').write_text(metadata.format(name=name,extra=extra))
for name,kind,icon,color in [('Child','places','folder','#d44757'),('Parent','mimetypes','text-x-generic','#74ab50'),('Blue','places','folder','#378bce'),('Blue','mimetypes','text-x-generic','#378bce')]:
 path=icons/name/'scalable'/kind/(icon+'.svg');path.parent.mkdir(parents=True,exist_ok=True)
 path.write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="'+color+'" d="M2 4h8l3 3h9v14H2z"/></svg>')
# A real PNG in the second theme exercises raster decoding as well as SVG.
import struct,zlib
def chunk(kind,body):
 return struct.pack('>I',len(body))+kind+body+struct.pack('>I',zlib.crc32(kind+body)&0xffffffff)
body=(b'\x00'+bytes([55,139,206])*24)*24
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',24,24,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(body))+chunk(b'IEND',b'')
(icons/'Blue/scalable/places/folder.svg').unlink()
(icons/'Blue/scalable/places/folder.png').write_bytes(png)
current=root/'home/.local/state/omarchy/current/theme';current.mkdir(parents=True)
(current/'icons.theme').write_text('Child\n')
(current/'colors.toml').write_text('background = "#202326"\nforeground = "#f4f4f4"\naccent = "#8ba9be"\n')
PY
for mode in normal restart ${DESKTOP_ICON_REAL_THEMES:-}; do
    restart=''; theme=''; datasystem="$fixture/empty"
    case "$mode" in
        normal) ;;
        restart) restart=1 ;;
        *) theme="$mode"; datasystem=/usr/share ;;
    esac
    set +e
    output=$(env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u QS_ICON_THEME -u FLEA_QT_THEME \
        HOME="$fixture/home" XDG_STATE_HOME="$fixture/state" XDG_CONFIG_HOME="$fixture/settings" \
        XDG_DATA_HOME="$fixture/data #?" XDG_DATA_DIRS="$datasystem" XDG_CACHE_HOME="$fixture/home/cache" XDG_RUNTIME_DIR="$fixture/runtime" \
        FLEA_BIN="$bin" DESKTOP_ICON_RESTART="$restart" DESKTOP_ICON_REAL_THEME="$theme" DESKTOP_ICON_THUMB="$fixture/data #?/icons/Blue/scalable/places/folder.png" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic QT_FORCE_STDERR_LOGGING=1 \
        timeout 45 qs -p "$fixture/config" 2>&1)
    status=$?
    set -e
    printf '%s\n' "$output"
    [ "$status" -eq 143 ] || { echo "desktop-icons: unexpected qs exit $status"; exit 1; }
    printf '%s\n' "$output" | grep -qE 'DESKTOPICONS DONE checks=[1-9][0-9]* failed=0'
    if printf '%s\n' "$output" | grep -E 'TypeError|ReferenceError|WARN|ERROR|DESKTOPICONS FAIL' \
        | grep -vF '$HYPRLAND_INSTANCE_SIGNATURE is unset. Cannot connect to hyprland.' \
        | grep -vF 'This plugin does not support setting window masks'; then
        echo 'desktop-icons: unexpected runtime diagnostic'; exit 1
    fi
done
python3 - "$fixture/state/flea/ui.json" <<'PY'
import json,os,sys
from pathlib import Path
display=json.loads(Path(sys.argv[1]).read_text())['display']
real=os.environ.get('DESKTOP_ICON_REAL_THEMES','').split()
assert display['fileIconTheme']=='theme:'+(real[-1] if real else 'Blue')
assert display['iconSet']=='feather'
PY
printf 'desktop-icons: rendering, inheritance, live system changes, fallback, idle/row budgets and restart persistence passed\n'

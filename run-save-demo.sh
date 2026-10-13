#!/usr/bin/env bash
# A simulated browser save request. No portal installation; only test-owned folders can be created here.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
. "$repo/tools/flea-sandbox-guard"
root="$FIXTURE_ROOT/flea-save-folder-demo-$$"
sandbox_make "$root"
mkdir -p "$root/home/Downloads" "$root/state/flea" "$root/cache" "$root/config/fontconfig" "$root/data"
printf 'Synthetic sample file.\n' > "$root/home/Downloads/example.txt"
printf '{"pickerView":"list","display":{"textSize":{"mode":14}},"places":{"favourites":[],"showNetwork":false,"showDevices":false,"showTrash":false}}\n' > "$root/state/flea/ui.json"
cp -RL "$repo/ui" "$root/ui"
/usr/bin/python3 - "$root" <<'PY'
from pathlib import Path
import subprocess, sys
root = Path(sys.argv[1])
font = subprocess.check_output(['fc-match','-f','%{file}','monospace'], text=True)
family = subprocess.check_output(['fc-match','-f','%{family[0]}','monospace'], text=True)
from xml.sax.saxutils import escape
(root / 'config/fontconfig/fonts.conf').write_text('<fontconfig><dir>' + escape(str(Path(font).parent)) + '</dir><match target="pattern"><test name="family" qual="any"><string>monospace</string></test><edit name="family" mode="prepend_first" binding="strong"><string>' + escape(family) + '</string></edit></match></fontconfig>')
p = root / 'ui/boot/picker.qml'
boot = p.read_text().replace('//@ pragma ShellId fleapicker', '//@ pragma ShellId flea-save-folder-test')
boot = boot.rstrip()[:-1] + '''
    Timer {
        interval: 100; repeat: true
        running: Quickshell.env("FLEA_FOLDER_DEMO_OPEN") === "1"
        onTriggered: if (chooser.item && chooser.item.pickerWin.canCreateFolder) {
            chooser.item.pickerWin.startNewFolder(); stop()
        }
    }
}
'''
p.write_text(boot)
# Privacy-only demo changes: omit machine devices and forbid creation outside the synthetic home.
p = root / 'ui/PickerPlaces.qml'
p.write_text(p.read_text().replace('root.placeEntries.concat(network.entries, devices.entries, phones.entries)', 'root.placeEntries'))
p = root / 'ui/PickerNewFolder.qml'
import json
home = str(root / 'home')
p.write_text(p.read_text().replace('&& root.picker.path.charAt(0) === "/"', '&& (root.picker.path === ' + json.dumps(home) + ' || root.picker.path.indexOf(' + json.dumps(home + '/') + ') === 0)'))
PY
export HOME="$root/home" XDG_STATE_HOME="$root/state" XDG_CACHE_HOME="$root/cache"
export XDG_CONFIG_HOME="$root/config" XDG_DATA_HOME="$root/data" FONTCONFIG_FILE=/etc/fonts/fonts.conf
export FLEA_BIN="$repo/target/debug/flea" FLEA_UI="$root/ui" QSG_RHI_BACKEND=vulkan
export FLEA_PICKER
FLEA_PICKER=$(/usr/bin/python3 - "$root/home/Downloads" <<'PY'
import json,sys
print(json.dumps({'mode':'save','title':'Save file — new folder test','app':'Isolated save test','folder':sys.argv[1],'name':'sample-download.zip'}))
PY
)
printf 'Isolated fixture: %s\nReply file: %s/reply.json\n' "$root" "$root"
# Saving confirms a path in reply.json; there is no browser to write a downloaded file.
exec "$FLEA_BIN" --pick "$root/reply.json"

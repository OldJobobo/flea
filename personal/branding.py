"""Deterministic personal-only UI overlay; upstream source and engine identities stay intact."""
from pathlib import Path
import hashlib
import json
import re

from common import Refusal

NAME = "Tick"
APP_ID = "com.oldjobobo.tick"
# Only presentation strings in these files are rewritten. Import aliases, commands,
# diagnostic matching and the intentionally named Flea icon family remain untouched.
COPY_FILES = (
    "Favourites.qml", "ShareLink.qml", "TrashMonitor.qml", "TrashView.qml", "RunCard.qml",
    "PermissionsDialog.qml", "PickerSelection.qml", "ConvertDialog.qml", "PickerPlaces.qml",
    "PickerNewFolder.qml", "PickerListing.qml", "PickerWindow.qml", "PaneWire.qml",
    "js/Errors.js", "js/Eject.js", "js/Markdown.js", "js/Flash.js", "js/Mounts.js",
    "js/Update.js", "js/Settings.js", "js/Menu.js",
)
LITERAL = re.compile(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')


def presentation(text):
    def replace(match):
        token = match.group()
        if token.startswith(("//", "/*")) or "Flea" not in token:
            return token
        # These are references to the original icon artwork, not the application name.
        if "Flea icons" in token:
            return token
        return re.sub(r"\bFlea\b", NAME, token)
    return LITERAL.sub(replace, text)


def apply(stage, commit):
    stage = Path(stage)
    assets = stage / "personal/branding"
    if not assets.is_dir():
        return None  # Clean upstream contribution builds are deliberately not Tick.
    sources = {}
    def save(leaf, text):
        path = stage / leaf
        if not path.is_file() or path.is_symlink():
            raise Refusal(f"Tick overlay expected a regular source file: {leaf}")
        sources[leaf] = hashlib.sha256(path.read_bytes()).hexdigest()
        path.write_text(text)
    def once(leaf, old, new):
        path = stage / leaf
        text = path.read_text()
        if text.count(old) != 1:
            raise Refusal(f"Tick overlay drift in {leaf}; review upstream before building")
        # Preserve the original hash when more than one reviewed edit lands in a file.
        previous = sources.get(leaf)
        save(leaf, text.replace(old, new))
        if previous:
            sources[leaf] = previous
    for leaf in COPY_FILES:
        save("ui/" + leaf, presentation((stage / "ui" / leaf).read_text()))
    once("ui/boot/shell.qml", "//@ pragma AppId com.thisisgm.flea", "//@ pragma AppId " + APP_ID)
    once("ui/boot/shell.qml", 'title: "Flea"', 'title: "Tick"')
    once("ui/boot/picker.qml", "//@ pragma AppId com.thisisgm.flea.picker", "//@ pragma AppId " + APP_ID + ".picker")
    once("ui/Ipc.qml", "function ready(): bool { return true }",
         "function ready(): bool { return true }\n        function brandTitle(): string { return root.fleaWindow.title }")

    # A single filled main shape replaces the shelf spiral without adding row objects.
    mark = json.loads((assets / "mark.json").read_text())
    if mark["grid"] != 24 or not mark["path"].startswith("M"):
        raise Refusal("Tick mark has the wrong geometry contract")
    once("ui/js/Icons.js", '"shelf": "M21 21H3V3h18v14H7V7h10v6h-6"', '"shelf": ' + json.dumps(mark["path"]))
    once("ui/js/IconPacks.js", 'return has(pack, name) && pack.paint === "fill"',
         'return name === "shelf" || (has(pack, name) && pack.paint === "fill")')
    template = (assets / "TickMark.qml").read_text()
    if template.count("@PATH@") != 1:
        raise Refusal("Tick mark template is invalid")
    save("ui/FleaMark.qml", template.replace("@PATH@", json.dumps(mark["path"])))
    once("shelf/FleaShelfMark.qml", 'PathSvg { path: "M21 21H3V3h18v14H7V7h10v6h-6" }',
         'PathSvg { path: ' + json.dumps(mark["path"]) + ' }')
    once("shelf/FleaShelfMark.qml", 'strokeColor: root.color\n      fillColor: "transparent"',
         'strokeColor: "transparent"\n      fillColor: root.color\n      fillRule: ShapePath.WindingFill')
    once("shelf/FleaShelfMark.qml", 'readonly property real inkOrigin: 2', 'readonly property real inkOrigin: 1')
    once("shelf/FleaShelfMark.qml", 'readonly property real inkExtent: 20', 'readonly property real inkExtent: 22')

    about = (stage / "ui/js/SettingsAbout.js").read_text()
    anchor = "var PACKAGES = "
    if about.count(anchor) != 1:
        raise Refusal("Tick About helper seam changed upstream")
    helpers = about[about.index(anchor):]
    save("ui/js/SettingsAbout.js", (assets / "SettingsAbout.js").read_text().replace("@COMMIT@", commit[:12]) + "\n" + helpers)
    save("ui/UpdateCheck.qml", (assets / "UpdateCheck.qml").read_text())
    # The switch is absent, and this guard also protects stale programmatic callers.
    original = (stage / "ui/DefaultClaim.qml").read_text()
    if original.count("    function toggle() {") != 1 or original.count("\n    // False when a read") != 1:
        raise Refusal("Tick default-action guard changed upstream")
    start = original.index("    function toggle() {")
    end = original.index("\n    // False when a read", start)
    save("ui/DefaultClaim.qml", original[:start] + "    function toggle() {}\n" + original[end:])

    for leaf in ("shelf/Model.js", "shelf/ShelfActions.qml"):
        save(leaf, presentation((stage / leaf).read_text()))
    manifest = json.loads((stage / "shelf/manifest.json").read_text())
    manifest["name"] = "Tick shelf"
    manifest["barWidget"]["displayName"] = "Tick shelf"
    save("shelf/manifest.json", json.dumps(manifest, indent=2) + "\n")
    return {"name": NAME, "app_id": APP_ID, "overlay_version": 1, "source_files": sources}

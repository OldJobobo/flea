#!/usr/bin/env python3
"""Regenerate the bundled Tabler Outline pack from its pinned upstream release."""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import re
from urllib.request import urlopen
import xml.etree.ElementTree as ET

VERSION = "v3.49.0"
ROOT = Path(__file__).resolve().parent.parent
BASE = f"https://raw.githubusercontent.com/tabler/tabler-icons/{VERSION}"
# Flea's semantic names are stable; packs translate geometry, never action or MIME names.
NAMES = {
    "info": "info-circle", "pin": "pin", "star": "star", "globe": "world",
    "file": "file", "folder": "folder", "folders-first": "sort-descending-2",
    "file-text": "file-text", "code": "code", "image": "photo", "film": "movie",
    "music": "music", "archive": "archive", "type": "typography", "terminal": "terminal",
    "table": "table", "presentation": "presentation", "house": "home", "download": "download",
    "folder-git-2": "folder-code", "server": "server", "plus": "plus", "history": "history",
    "drive": "database", "smartphone": "device-mobile", "camera": "camera", "eject": "player-eject",
    "play": "player-play", "pause": "player-pause", "search": "search", "filter": "filter",
    "folder-open": "folder-open", "app-window": "app-window", "undo": "arrow-back-up",
    "rename": "pencil", "file-plus": "file-plus", "folder-plus": "folder-plus", "trash": "trash",
    "eye": "eye", "eye-off": "eye-off", "chevron-right": "chevron-right", "chevron-left": "chevron-left",
    "arrow-left": "arrow-left", "arrow-up": "arrow-up", "list": "list", "columns": "columns-3",
    "preview": "layout-sidebar-right", "dual": "layout-columns", "grid": "layout-grid",
    "symlink": "arrow-up-right", "alert": "alert-triangle", "lock": "lock", "key": "key",
    "archive-out": "file-zip", "network": "sitemap", "check": "check", "tag": "tag",
    "minus": "minus", "maximize": "maximize", "x": "x", "sliders": "adjustments",
    "move-horizontal": "arrows-horizontal", "sort": "sort-descending", "volume": "volume",
    "volume-x": "volume-off", "scissors": "cut", "copy": "copy", "clipboard": "clipboard",
    "keyboard": "keyboard", "contrast": "contrast", "pointer": "pointer",
}


def download(path):
    with urlopen(f"{BASE}/{path}", timeout=30) as response:
        return response.read().decode("utf-8")


def geometry(svg):
    root = ET.fromstring(svg)
    if root.attrib.get("viewBox") != "0 0 24 24":
        raise ValueError("Tabler source no longer uses the expected grid")
    paths = []
    for element in root:
        tag = element.tag.rsplit("}", 1)[-1]
        if tag != "path":
            raise ValueError(f"Unreviewed SVG element: {tag}")
        if element.attrib.get("fill") == "none" and element.attrib.get("stroke") == "none":
            continue
        path = element.attrib["d"]
        # A relative first move is relative to 0,0 in each source path, not the preceding subpath.
        if path.startswith("m"):
            match = re.match(r"m\s*([-+\d.eE]+)[,\s]+([-+\d.eE]+)(.*)", path)
            if not match:
                raise ValueError("Unreviewed relative move")
            x, y, tail = match.groups()
            if re.match(r"\s*[-+\d.]", tail):
                tail = "l" + tail
            path = f"M{x} {y}{tail}"
        paths.append(path)
    if not paths:
        raise ValueError("Empty source icon")
    return " ".join(paths)


def main():
    def icon(item):
        name, source = item
        return name, {"path": geometry(download(f"icons/outline/{source}.svg"))}
    with ThreadPoolExecutor(max_workers=8) as pool:
        icons = dict(pool.map(icon, NAMES.items()))
    pack = {"version": 1, "grid": 24, "style": "round", "name": "Tabler Outline",
            "source": f"https://github.com/tabler/tabler-icons/tree/{VERSION}",
            "license": "MIT", "sources": NAMES, "icons": icons}
    destination = ROOT / "ui/icons"
    destination.mkdir(exist_ok=True)
    (destination / "tabler.json").write_text(json.dumps(pack, indent=2) + "\n")
    (destination / "TABLER-LICENSE").write_text(download("LICENSE"))
    print(f"Imported {len(icons)} Tabler Outline marks from {VERSION}")


if __name__ == "__main__":
    main()

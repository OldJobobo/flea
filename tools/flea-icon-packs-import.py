#!/usr/bin/env python3
"""Regenerate additional bundled packs from digest-pinned upstream archives."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import tarfile
from urllib.request import urlopen

from icon_geometry import geometry

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "tools/icon-pack-sources.json"
MAX_ARCHIVE = 100_000_000


def archive(source, cached):
    if cached.is_file():
        data = cached.read_bytes()
    else:
        url = f"https://codeload.github.com/{source['repository']}/tar.gz/refs/tags/{source['ref']}"
        with urlopen(url, timeout=90) as response:
            data = response.read(MAX_ARCHIVE + 1)
    if len(data) > MAX_ARCHIVE or hashlib.sha256(data).hexdigest() != source["archive_sha256"]:
        raise ValueError("Upstream archive does not match its reviewed digest")
    return tarfile.open(fileobj=io.BytesIO(data), mode="r:gz")


def convert(name, source, cache):
    # Archives are read in memory, never extracted, and symlink members are never followed.
    with archive(source, cache / f"{name}.tar.gz") as tar:
        members = {member.name.split("/", 1)[1]: member for member in tar
                   if member.isfile() and "/" in member.name}
        def read(path):
            member = members[path]
            if member.size > 524288:
                raise ValueError("Unexpectedly large source asset")
            return tar.extractfile(member).read().decode("utf-8")
        icons = {}
        for semantic, icon in source["sources"].items():
            try:
                icons[semantic] = geometry(read(source["prefix"] + icon + ".svg"), source["paint"])
            except ValueError as error:
                raise ValueError(f"{name}/{icon} ({semantic}): {error}") from error
        license_text = read(source["license_path"])
    pack = {"version": 1, "grid": 24, "style": "round", "paint": source["paint"],
            "name": source["name"], "source": f"https://github.com/{source['repository']}/tree/{source['ref']}",
            "archive_sha256": source["archive_sha256"], "license": source["license"],
            "sources": source["sources"], "icons": icons}
    destination = ROOT / "ui/icons"
    (destination / f"{name}.json").write_text(json.dumps(pack, indent=2) + "\n")
    (destination / f"{name.upper()}-LICENSE").write_text(license_text)
    print(f"Imported {len(icons)} {source['name']} marks from {source['ref']}")


def main():
    sources = json.loads(SOURCES.read_text())
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packs", nargs="*", help="Pack IDs; default: all additional packs")
    parser.add_argument("--cache", type=Path, default=ROOT / ".local-builds/icon-sources",
                        help="Optional directory of previously downloaded <id>.tar.gz archives")
    args = parser.parse_args()
    for name in args.packs or sources:
        if name not in sources:
            parser.error(f"Unknown pack: {name}")
        convert(name, sources[name], args.cache)


if __name__ == "__main__":
    main()

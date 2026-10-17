"""Vendor reviewed static vector pieces from the supplied animation ZIP; never execute it."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import math
import re
import stat
import sys
import xml.etree.ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parent.parent
PARTS = ["body", "antenna-left", "antenna-right"] + [
    f"{pair}-{side}-{joint}"
    for pair in ("front", "middle", "back")
    for side in ("left", "right")
    for joint in ("upper", "lower")
]


def geometry(data):
    if len(data) > 32768 or b"<!DOCTYPE" in data or b"<!ENTITY" in data:
        raise ValueError("Unreviewed SVG size or entity declaration")
    svg = ET.fromstring(data)
    if svg.attrib.get("viewBox") != "0 0 24 24":
        raise ValueError("Expected the supplied 24-unit coordinate system")
    paths = []
    allowed = {"svg": {"viewBox", "width", "height"}, "g": {"fill", "fill-rule"}, "path": {"d"}}
    for node in svg.iter():
        tag = node.tag.rsplit("}", 1)[-1]
        if tag not in allowed or set(node.attrib) - allowed[tag]:
            raise ValueError("Only reviewed static path geometry is accepted")
        if tag == "g" and node.attrib.get("fill-rule", "nonzero") != "nonzero":
            raise ValueError("Unexpected compound-path fill rule")
        if tag == "path":
            path = node.attrib["d"]
            if not path.startswith("M") or not re.fullmatch(r"[MmLlHhVvCcSsQqTtAaZz0-9eE+.,\s-]+", path):
                raise ValueError("Unreviewed SVG path")
            paths.append(path)
    if not paths:
        raise ValueError("SVG contains no paths")
    return " ".join(paths)


def motions(data):
    spec = json.loads(data)
    if set(spec) != {"thinking", "searching", "sleepy", "waving", "surprised", "error"}:
        raise ValueError("Expected the six supplied extra states")
    result = {}
    for name, clip in spec.items():
        keys, duration = clip["keys"], clip["duration_seconds"]
        if not isinstance(duration, (int, float)) or not math.isfinite(duration) or not 1 <= duration <= 10:
            raise ValueError("Unreviewed clip duration")
        if not 2 <= len(keys) <= 32 or any(len(key) != 9 for key in keys):
            raise ValueError("Invalid pose keyframes")
        if any(not isinstance(v, (int, float)) or not math.isfinite(v) or abs(v) > 90 for key in keys for v in key):
            raise ValueError("Invalid pose value")
        if keys[0] != [0,0,0,0,1,1,0,0,0] or keys[-1] != [1,0,0,0,1,1,0,0,0]:
            raise ValueError("Clip must start and end at neutral")
        if any(a[0] >= b[0] for a, b in zip(keys, keys[1:])) or any(not .5 <= key[i] <= 1.5 for key in keys for i in (4, 5)):
            raise ValueError("Invalid key timing or scale")
        result[name] = {"duration": round(duration * 1000), "keys": keys}
    return result


def main():
    archive = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "personal/branding/tick-mascot-animation-sources.zip"
    destination = ROOT / "personal/branding/mascot"
    if not destination.resolve().is_relative_to(ROOT):
        raise ValueError("Animation assets must stay inside the checkout")
    values, paths, hashes = {}, {}, {}
    with ZipFile(archive) as source:
        infos = source.infolist()
        if sum(info.file_size for info in infos) > 32 * 1024 * 1024:
            raise ValueError("Animation archive is unexpectedly large")
        if len({info.filename for info in infos}) != len(infos):
            raise ValueError("Duplicate archive entries")
        for info in infos:
            name = PurePosixPath(info.filename)
            if name.is_absolute() or ".." in name.parts or stat.S_ISLNK(info.external_attr >> 16):
                raise ValueError("Unsafe archive member")
        for name in PARTS:
            leaf = f"assets/{name}.svg"
            member = f"tick-animations/{leaf}"
            if source.getinfo(member).file_size > 32768:
                raise ValueError("Unexpectedly large vector piece")
            data = source.read(member)
            paths[name] = geometry(data)
            values[leaf] = data
            hashes[leaf] = hashlib.sha256(data).hexdigest()
        if source.getinfo("tick-animations/TickMascot.qml").file_size > 32768:
            raise ValueError("Unexpectedly large source component")
        original = source.read("tick-animations/TickMascot.qml")
        values["supplied/TickMascot.qml"] = original
        hashes["supplied/TickMascot.qml"] = hashlib.sha256(original).hexdigest()
        if source.getinfo("tick-animations/motion-spec.json").file_size > 32768:
            raise ValueError("Unexpectedly large motion specification")
        spec_data = source.read("tick-animations/motion-spec.json")
        clips = motions(spec_data)
        values["motion-spec.json"] = spec_data
        hashes["motion-spec.json"] = hashlib.sha256(spec_data).hexdigest()
    values["TickMotions.js"] = (".pragma library\n\n// Exact supplied extra keyframes and native durations.\nvar CLIPS = "
                                + json.dumps(clips, separators=(",", ":")) + "\n").encode()
    values["TickParts.js"] = (".pragma library\n\n// Exact supplied SVG geometry; semantic color is applied by the QML rig.\nvar PATHS = "
                              + json.dumps(paths, indent=2) + "\n").encode()
    values["source.json"] = (json.dumps({"archive": archive.name, "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
                                       "files": hashes}, indent=2) + "\n").encode()
    for leaf, data in values.items():
        output = destination / leaf
        if not output.resolve().is_relative_to(ROOT):
            raise ValueError("Asset path resolves outside the checkout")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(data)
    print(f"Imported {len(paths)} vector pieces and {len(clips)} extra clips; no supplied code was executed.")


if __name__ == "__main__":
    main()

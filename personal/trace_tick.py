"""Derive Tick's scalable mark from the supplied PNG, preserving the original."""
from pathlib import Path
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from icon_geometry import absolute, number  # noqa: E402


def main():
    source = ROOT / "personal/Refined monochrome Tick with segmented antennae.png"
    work = ROOT / ".local-builds/tick-branding"
    work.mkdir(parents=True, exist_ok=True)
    mask, traced = work / "trace.pbm", work / "traced.svg"
    subprocess.run(["magick", str(source), "-alpha", "extract", "-threshold", "60%",
                    "-define", "connected-components:area-threshold=1200",
                    "-define", "connected-components:mean-color=true", "-connected-components", "8",
                    "-negate", str(mask)], check=True)
    subprocess.run(["potrace", str(mask), "-s", "--tight", "-t", "20", "-a", "1", "-O", "1.5",
                    "-o", str(traced)], check=True)
    svg = ET.fromstring(traced.read_text())
    _, _, width, height = map(float, svg.attrib["viewBox"].split())
    group = svg.find("{*}g")
    match = re.fullmatch(r"translate\(([-\d.]+),([-\d.]+)\) scale\(([-\d.]+),([-\d.]+)\)", group.attrib["transform"])
    if not match:
        raise ValueError("Unrecognized Potrace transform")
    tx, ty, sx, sy = map(float, match.groups())
    scale = 22 / max(width, height)
    ox, oy = (24 - width * scale) / 2, (24 - height * scale) / 2
    paths = []
    for node in group:
        tokens = absolute(node.attrib["d"]).split()
        transformed = []
        axis = 0
        for token in tokens:
            command = token[0] if token[0] in "MLCZ" else ""
            if command:
                if command not in "MLCZ":
                    raise ValueError("Unreviewed trace command")
                axis = 0
                token = token[1:]
            if token:
                value = float(token)
                value = (value * sx + tx) * scale + ox if axis == 0 else (value * sy + ty) * scale + oy
                transformed.append(command + number(value))
                axis = 1 - axis
            else:
                transformed.append(command)
        paths.append(" ".join(transformed))
    path = " ".join(paths)
    destination = ROOT / "personal/branding"
    destination.mkdir(exist_ok=True)
    (destination / "mark.json").write_text(json.dumps({"grid": 24, "path": path}, indent=2) + "\n")
    (destination / "tick.svg").write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">\n'
        '  <title>Tick</title>\n'
        '  <rect width="24" height="24" rx="4" fill="#202326"/>\n'
        f'  <path fill="#f4f4f4" fill-rule="nonzero" d="{path}"/>\n</svg>\n')
    print("Derived Tick vector artwork; original PNG is unchanged.")


if __name__ == "__main__":
    main()

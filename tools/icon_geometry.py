"""Reviewed SVG primitives to absolute, normalized Flea path data (stdlib only)."""
import math
import re
import xml.etree.ElementTree as ET

TOKEN = re.compile(r"[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?")
COUNTS = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "T": 2, "A": 7}


def number(value):
    if not math.isfinite(value):
        raise ValueError("Non-finite coordinate")
    return format(value if value else 0, ".9g")


def absolute(path, scale=1):
    """Normalize every command, including implicit lineto tails and arc endpoints."""
    if TOKEN.sub("", path).strip(" \t\r\n,"):
        raise ValueError("Unrecognized SVG path token")
    tokens = TOKEN.findall(path)
    result, current, origin = [], [0, 0], [0, 0]
    command, index = "", 0
    while index < len(tokens):
        if tokens[index].isalpha():
            command = tokens[index]
            index += 1
            if command.upper() == "Z":
                result.append("Z")
                current = origin[:]
                command = ""
                continue
        upper = command.upper()
        count = COUNTS.get(upper)
        if not count or index + count > len(tokens):
            raise ValueError("Incomplete SVG path")
        values = list(map(float, tokens[index:index + count]))
        index += count
        relative = command.islower()
        if upper == "A":
            if values[0] < 0 or values[1] < 0 or values[3] not in (0, 1) or values[4] not in (0, 1):
                raise ValueError("Invalid SVG arc")
            if relative:
                values[5] += current[0]
                values[6] += current[1]
            current = values[5:7]
            output = [values[0] * scale, values[1] * scale, *values[2:5],
                      values[5] * scale, values[6] * scale]
        elif upper in ("H", "V"):
            axis = 0 if upper == "H" else 1
            if relative:
                values[0] += current[axis]
            current[axis] = values[0]
            output = [values[0] * scale]
        else:
            if relative:
                values = [value + current[i % 2] for i, value in enumerate(values)]
            current = values[-2:]
            if upper == "M":
                origin = current[:]
                command = "l" if relative else "L"
            output = [value * scale for value in values]
        result.append(upper + " ".join(number(value) for value in output))
    if not result or not result[0].startswith("M"):
        raise ValueError("Path must begin with a move")
    return " ".join(result)


def primitive(element):
    tag = element.tag.rsplit("}", 1)[-1]
    a = element.attrib
    def value(key, default=0):
        return float(a.get(key, default))
    if tag == "path":
        return a["d"]
    if tag == "line":
        return f"M{value('x1')} {value('y1')} L{value('x2')} {value('y2')}"
    if tag in ("polyline", "polygon"):
        return "M" + a["points"] + (" Z" if tag == "polygon" else "")
    if tag in ("circle", "ellipse"):
        cx, cy = value("cx"), value("cy")
        rx = value("r") if tag == "circle" else value("rx")
        ry = rx if tag == "circle" else value("ry")
        if rx <= 0 or ry <= 0:
            raise ValueError("Degenerate ellipse")
        return (f"M{cx + rx} {cy} A{rx} {ry} 0 1 0 {cx - rx} {cy} "
                f"A{rx} {ry} 0 1 0 {cx + rx} {cy} Z")
    if tag == "rect":
        x, y, w, h = value("x"), value("y"), value("width"), value("height")
        rx = value("rx", a.get("ry", 0))
        ry = value("ry", rx)
        if min(rx, ry, w, h) < 0:
            raise ValueError("Negative rectangle extent")
        rx, ry = min(rx, w / 2), min(ry, h / 2)
        if not rx or not ry:
            return f"M{x} {y} H{x + w} V{y + h} H{x} Z"
        return (f"M{x + rx} {y} H{x + w - rx} A{rx} {ry} 0 0 1 {x + w} {y + ry} "
                f"V{y + h - ry} A{rx} {ry} 0 0 1 {x + w - rx} {y + h} "
                f"H{x + rx} A{rx} {ry} 0 0 1 {x} {y + h - ry} "
                f"V{y + ry} A{rx} {ry} 0 0 1 {x + rx} {y} Z")
    raise ValueError(f"Unreviewed SVG element: {tag}")


def geometry(svg, paint="stroke"):
    root = ET.fromstring(svg)
    grid = list(map(float, root.attrib["viewBox"].split()))
    if grid not in ([0, 0, 24, 24], [0, 0, 256, 256]):
        raise ValueError("Unexpected source grid")
    paths, solids = [], []
    def visit(element, inherited):
        tag = element.tag.rsplit("}", 1)[-1]
        attrs = {**inherited, **element.attrib}
        if any(key in element.attrib for key in ("transform", "style", "clip-path", "mask", "opacity")):
            raise ValueError("Unreviewed SVG effect")
        if tag in ("title", "desc"):
            return
        if tag in ("svg", "g"):
            for child in element:
                visit(child, attrs)
            return
        fill, stroke = attrs.get("fill", "black"), attrs.get("stroke", "none")
        if fill == stroke == "none":
            return
        if paint == "fill" and (stroke != "none" or attrs.get("fill-rule", "nonzero") != "nonzero"):
            raise ValueError("Expected nonzero filled geometry")
        path = absolute(primitive(element), 24 / grid[2])
        if paint == "fill" or stroke != "none":
            paths.append(path)
        if paint == "stroke" and fill != "none":
            if attrs.get("fill-rule", "nonzero") != "nonzero":
                raise ValueError("Expected nonzero filled geometry")
            solids.append(path)
    visit(root, {})
    if not paths and not solids:
        raise ValueError("Empty source icon")
    icon = {"path": " ".join(paths) if paths else "M0 0"}
    if solids:
        icon["filled"] = " ".join(solids)
    return icon

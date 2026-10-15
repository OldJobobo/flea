"""Explicit, backed-up user integration; never calls upstream --default."""
from pathlib import Path
import base64
import hashlib
import json
import os
import shlex
import tempfile

from branding import APP_ID
from bundles import selected, validate
from common import ROOT, STORE, Refusal, atomic_json, read_json, require_stopped, run

DESKTOP_ID = APP_ID + ".desktop"
LEGACY_DESKTOP_ID = "com.oldjobobo.flea.desktop"
ICON = Path(__file__).resolve().parent / "branding/tick.svg"
BEGIN = "-- flea-custom: begin (managed by personal/flea-dev)"
END = "-- flea-custom: end"


def paths(home=None):
    home = Path.home() if home is None else Path(home)
    config = Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config")
    data = Path(os.environ.get("XDG_DATA_HOME") or home / ".local/share")
    portal = config / "xdg-desktop-portal/hyprland-portals.conf"
    if not portal.exists():
        portal = config / "xdg-desktop-portal/portals.conf"
    return {"launcher": home / ".local/bin/tick",
            "legacy_launcher": home / ".local/bin/flea-custom",
            "desktop": data / "applications" / DESKTOP_ID,
            "legacy_desktop": data / "applications" / LEGACY_DESKTOP_ID,
            "icon": data / "icons/hicolor/scalable/apps" / (APP_ID + ".svg"),
            "bindings": config / "hypr/bindings.lua", "portal": portal,
            "reveal": data / "dbus-1/services/org.freedesktop.FileManager1.service",
            "picker": data / "dbus-1/services/org.freedesktop.impl.portal.desktop.flea.service",
            "mime": config / "mimeapps.list"}


def capture(path):
    if path.is_symlink():
        raise Refusal(f"Refusing to replace a symlinked preference file: {path}")
    if not path.exists():
        return None
    if not path.is_file():
        raise Refusal(f"Not a regular file: {path}")
    return {"bytes": base64.b64encode(path.read_bytes()).decode(), "mode": path.stat().st_mode & 0o777}


def external_write(path, value, mode=0o600):
    # Only execute()'s explicitly confirmed user-level target set reaches this function.
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".flea-custom-", dir=path.parent)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "wb") as output:
            output.write(value)
            output.flush()
            os.fsync(output.fileno())
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def restore(path, original):
    if original is None:
        path.unlink(missing_ok=True)
    else:
        external_write(path, base64.b64decode(original["bytes"]), original["mode"])


def binding_block(shortcuts, picker):
    launch = shlex.quote(str(ROOT / "personal/tick"))
    lines = [BEGIN]
    if shortcuts:
        for chord, title, suffix in (("SUPER + SHIFT + F", "Tick file manager", ""),
                                      ("SUPER + ALT + SHIFT + F", "Tick file manager (cwd)",
                                       ' "$(omarchy-cmd-terminal-cwd)"')):
            command = json.dumps(f"{launch} --gui{suffix}", ensure_ascii=False)
            lines += [f'hl.unbind("{chord}")', f'o.bind("{chord}", "{title}", {{ launch = {command} }})']
    if picker:
        lines.append('o.window("com.oldjobobo.tick.picker", { tag = "+floating-window" })')
    return "\n".join([*lines, END]) + "\n"


def prefer_picker(text):
    lines = text.splitlines()
    output = []
    section = ""
    found = False
    has_section = False
    for line in lines:
        if line.strip().startswith("["):
            if section == "[preferred]" and not found:
                output.append("org.freedesktop.impl.portal.FileChooser=flea;gtk")
                found = True
            section = line.strip()
            has_section |= section == "[preferred]"
        if section == "[preferred]" and line.strip().startswith("org.freedesktop.impl.portal.FileChooser="):
            if not found:
                output.append("org.freedesktop.impl.portal.FileChooser=flea;gtk")
                found = True
        else:
            output.append(line)
    if not has_section:
        output += ["", "[preferred]"]
    if not found:
        output.append("org.freedesktop.impl.portal.FileChooser=flea;gtk")
    return "\n".join(output) + "\n"


def mime_target(args, target):
    alias = target["mime"]
    resolved = alias.resolve()
    explicit = getattr(args, "mime_target", None)
    if alias.is_symlink() and (explicit is None or Path(explicit).resolve() != resolved):
        raise Refusal(f"MIME preferences are symlinked to {resolved}. Authorize that exact target with --mime-target {resolved}; the symlink will be preserved.")
    if explicit is not None and Path(explicit).resolve() != resolved:
        raise Refusal("--mime-target must resolve to the existing MIME preference file.")
    return resolved


def directory_default(text):
    # Replace only this key in this section, retaining comments and other associations.
    lines = text.splitlines(keepends=True)
    start = [i for i, line in enumerate(lines) if line.strip() == "[Default Applications]"]
    newline = "\r\n" if "\r\n" in text else "\n"
    value = f"inode/directory={DESKTOP_ID}{newline}"
    if len(start) > 1:
        raise Refusal("Duplicate Default Applications sections; refusing an ambiguous MIME edit.")
    if not start:
        return text.rstrip("\r\n") + newline + f"[Default Applications]{newline}" + value
    first = start[0] + 1
    end = next((i for i in range(first, len(lines)) if lines[i].lstrip().startswith("[")), len(lines))
    matches = [i for i in range(first, end) if lines[i].split("=", 1)[0].strip() == "inode/directory"]
    if len(matches) > 1:
        raise Refusal("Duplicate directory defaults; refusing an ambiguous MIME edit.")
    if matches:
        lines[matches[0]] = value
    else:
        if end and not lines[end - 1].endswith(("\n", "\r")):
            lines[end - 1] += newline
        lines.insert(end, value)
    return "".join(lines)


def payloads(args, target):
    command = str(ROOT / "personal/tick")
    # Desktop and D-Bus Exec have their own quoting rules, not shell quoting.
    quoted = '"' + command.replace("\\", "\\\\").replace('"', '\\"').replace("%", "%%") + '"'
    wrapper = f'#!/bin/sh\nexec {shlex.quote(command)} "$@"\n'
    entry = (f"[Desktop Entry]\nType=Application\nName=Tick\nComment=Personal Flea fork for Omarchy\n"
             f"Exec=/usr/bin/env {quoted} --gui %f\nIcon={APP_ID}\nTerminal=false\n"
             f"Categories=System;FileTools;FileManager;\nMimeType=inode/directory;\nStartupWMClass={APP_ID}\n")
    values = {"launcher": (wrapper, 0o755), "legacy_launcher": (wrapper, 0o755),
              "desktop": (entry, 0o644), "legacy_desktop": (entry + "NoDisplay=true\n", 0o644),
              "icon": (ICON.read_text(), 0o644)}
    if args.shortcuts or args.picker:
        original = target["bindings"].read_text() if target["bindings"].exists() else ""
        if BEGIN in original or END in original:
            raise Refusal("A custom binding block already exists. Remove the recorded installation before changing options.")
        values["bindings"] = (original.rstrip("\n") + "\n\n" + binding_block(args.shortcuts, args.picker),
                              target["bindings"].stat().st_mode & 0o777 if target["bindings"].exists() else 0o600)
    for option, helper, name in (("reveal", "filemanager1", "org.freedesktop.FileManager1"),
                                  ("picker", "portal", "org.freedesktop.impl.portal.desktop.flea")):
        if getattr(args, option):
            values[option] = (f"# Tick user-level activation override\n[D-BUS Service]\nName={name}\nExec={quoted} --custom-service {helper}\n", 0o644)
    if args.picker:
        original = target["portal"].read_text() if target["portal"].exists() else ""
        values["portal"] = (prefer_picker(original), 0o600)
    result = {str(target[key]): {"bytes": text.encode(), "mode": mode} for key, (text, mode) in values.items()}
    if args.directory_default:
        path = mime_target(args, target)
        original = path.read_text() if path.exists() else ""
        result[str(path)] = {"bytes": directory_default(original).encode(),
                             "mode": path.stat().st_mode & 0o777 if path.exists() else 0o600}
    return result


def reload_hypr():
    run(["hyprctl", "reload"], capture=True)
    errors = run(["hyprctl", "configerrors"], capture=True)
    if errors:
        raise Refusal(f"Hyprland reported configuration errors:\n{errors}")


def install(args, target, values):
    require_stopped()
    validate(selected())
    record_path = STORE / "desktop.json"
    if record_path.exists():
        raise Refusal("Desktop installation is already recorded. Remove it before changing options.")
    previous_mime = run(["xdg-mime", "query", "default", "inode/directory"], capture=True) if args.directory_default else None
    if args.shortcuts or args.picker:
        errors = run(["hyprctl", "configerrors"], capture=True)
        if errors:
            raise Refusal("Resolve existing Hyprland config errors before installing overrides.")
    backups = {path: capture(Path(path)) for path in values}
    record = {"originals": backups, "installed": {}, "previous_mime": previous_mime,
              "shortcuts": args.shortcuts, "picker": args.picker, "directory_default": args.directory_default}
    # Recovery metadata is durable before any external file is changed.
    atomic_json(record_path, record)
    try:
        for path, value in values.items():
            external_write(Path(path), value["bytes"], value["mode"])
        if args.directory_default:
            # payloads() wrote the explicitly authorized resolved target, not its symlink.
            if run(["xdg-mime", "query", "default", "inode/directory"], capture=True) != DESKTOP_ID:
                raise Refusal("Directory default did not change to Tick.")
        if args.shortcuts or args.picker:
            reload_hypr()
        if args.picker:
            run(["systemctl", "--user", "try-restart", "xdg-desktop-portal.service"], capture=True)
        record["installed"] = {path: hashlib.sha256(Path(path).read_bytes()).hexdigest() for path in backups if Path(path).exists()}
        atomic_json(record_path, record)
    except Exception:
        for path, original in backups.items():
            restore(Path(path), original)
        if args.shortcuts or args.picker:
            reload_hypr()
        record_path.unlink()
        raise
    print("Installed and verified user-level routing. Stock Flea was not replaced.")
    if args.reveal or args.picker:
        print("D-Bus overrides take effect on next activation; close an existing stock service owner first.")


def remove():
    require_stopped()
    path = STORE / "desktop.json"
    record = read_json(path)
    if not record["installed"]:
        raise Refusal("An interrupted installation needs manual recovery using desktop.json originals.")
    for name, digest in record["installed"].items():
        item = Path(name)
        if item.is_symlink() or not item.is_file() or hashlib.sha256(item.read_bytes()).hexdigest() != digest:
            raise Refusal(f"Changed since installation; refusing to overwrite your edits: {item}")
    for name, original in record["originals"].items():
        restore(Path(name), original)
    if record["shortcuts"] or record["picker"]:
        reload_hypr()
    if record["picker"]:
        run(["systemctl", "--user", "try-restart", "xdg-desktop-portal.service"], capture=True)
    path.rename(STORE / "desktop-removed.json")
    print("Restored pre-install preferences and files. Stock package remains installed.")


def execute(args):
    target = paths()
    if args.action == "rebrand":
        from desktop_rebrand import execute as rebrand
        rebrand(args, target)
        return
    if args.action == "remove":
        if not args.confirm:
            raise Refusal("Removal restores external preferences; pass --confirm after reviewing desktop.json.")
        remove()
        return
    values = payloads(args, target)
    print("User-level targets:")
    for path in values:
        print(f"  {path}")
    if args.action == "plan":
        print("Preview only; no user configuration was changed.")
        return
    if not args.confirm:
        raise Refusal("Installation writes outside the repository. Review desktop plan, then explicitly authorize these targets with --confirm.")
    install(args, target, values)

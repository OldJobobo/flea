"""Transactional branding refresh of an existing installation, without changing routing."""
from pathlib import Path
import hashlib
import json

import desktop
from branding import APP_ID
from bundles import selected, validate
from common import STORE, Refusal, atomic_json, read_json, require_stopped


def execute(args, target):
    if any(getattr(args, option, False) for option in ("shortcuts", "picker", "reveal", "directory_default", "mime_target")):
        raise Refusal("Rebrand preserves existing routing; do not pass installation options.")
    record_path = STORE / "desktop.json"
    pending = STORE / "desktop-rebrand-pending.json"
    if pending.exists():
        raise Refusal("An interrupted rebrand needs recovery from desktop-rebrand-pending.json first.")
    record = read_json(record_path)
    if not record.get("installed"):
        raise Refusal("An interrupted desktop installation must be recovered first.")
    bundle = selected()
    manifest = validate(bundle)
    if manifest.get("brand", {}).get("app_id") != APP_ID:
        raise Refusal("Select a smoke-tested Tick bundle before rebranding the desktop.")
    values = desktop.payloads(args, target)
    # The icon is pinned to the deployed build, not a mutable checkout asset.
    icon = bundle / "personal/branding/tick.svg"
    values[str(target["icon"])] = {"bytes": icon.read_bytes(), "mode": 0o644}
    originals = {}
    for name in values:
        path = Path(name)
        originals[name] = desktop.capture(path)
        expected = record["installed"].get(name)
        if expected:
            if originals[name] is None or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                raise Refusal(f"Changed since installation; refusing to overwrite your edits: {name}")
        elif originals[name] is not None:
            raise Refusal(f"An unowned Tick integration target already exists: {name}")
    print("Branding targets (shortcuts, MIME associations and services stay unchanged):")
    for name in values:
        print(f"  {name}")
    if not args.confirm:
        print("Preview only; pass --confirm to refresh these branding files.")
        return
    require_stopped()
    next_record = json.loads(json.dumps(record))
    for name, original in originals.items():
        next_record["originals"].setdefault(name, original)
    # Keep both the immediate rollback and the pre-install removal backups durable.
    atomic_json(pending, {"record": record, "originals": originals})
    try:
        for name, value in values.items():
            desktop.external_write(Path(name), value["bytes"], value["mode"])
        for name, value in values.items():
            if Path(name).read_bytes() != value["bytes"]:
                raise Refusal(f"Branding read-back failed: {name}")
            next_record["installed"][name] = hashlib.sha256(value["bytes"]).hexdigest()
        next_record["brand"] = {"name": "Tick", "app_id": APP_ID, "commit": bundle.name}
        atomic_json(record_path, next_record)
    except Exception:
        # A failed restore leaves pending metadata intact for explicit recovery.
        for name, original in originals.items():
            desktop.restore(Path(name), original)
        atomic_json(record_path, record)
        pending.unlink()
        raise
    pending.unlink()
    print("Tick desktop branding verified. Legacy entry points still work; stock Flea is unchanged.")

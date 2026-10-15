"""Clean-commit builds, bundle integrity and transactional selection."""
from pathlib import Path, PurePosixPath
import hashlib
import io
import os
import re
import shutil
import subprocess
import tarfile
import tempfile
import time

import branding

from common import (ROOT, STORE, Refusal, atomic_json, atomic_link, clean,
                    git, inside, logged, read_json, require_stopped, test_environment)

HELPERS = ("flea-gio-auth", "flea-udisks", "flea-portal", "flea-filemanager1")
UI_LINKS = ("ui/Commons", "ui/Ui", "ui/boot/Commons", "ui/boot/Ui")


def bundle_path(name):
    if not re.fullmatch(r"[0-9a-f]{40}", name):
        raise Refusal("A build ID must be a complete 40-character commit hash.")
    return inside(STORE / "releases" / name, STORE / "releases")


def selected(which="current"):
    link = STORE / which
    if not link.is_symlink():
        raise Refusal(f"No {which} build. Build, smoke-test and promote one first.")
    path = inside(link, STORE / "releases")
    if path.parent != (STORE / "releases").resolve():
        raise Refusal(f"Invalid {which} build selection.")
    return path


def fingerprints(path):
    result = {}
    for item in sorted(path.rglob("*")):
        key = str(item.relative_to(path))
        if key == "manifest.json" or item.is_dir() and not item.is_symlink():
            continue
        if item.is_symlink():
            result[key] = "link:" + os.readlink(item)
        elif item.is_file():
            result[key] = hashlib.sha256(item.read_bytes()).hexdigest()
        else:
            raise Refusal(f"Unexpected bundle entry: {item}")
    return result


def validate(path):
    path = bundle_path(Path(path).name)
    manifest = read_json(path / "manifest.json")
    if manifest.get("commit") != path.name:
        raise Refusal("Bundle commit does not match its directory.")
    if manifest.get("files") != fingerprints(path):
        raise Refusal(f"Bundle changed since it was built: {path}")
    for leaf in ("bin/flea", "ui/boot/shell.qml", "shelf/manifest.json", *[f"tools/{h}" for h in HELPERS]):
        if not (path / leaf).is_file():
            raise Refusal(f"Bundle is missing {leaf}.")
    for leaf in UI_LINKS:
        if not (path / leaf).is_dir():
            raise Refusal(f"Omarchy runtime dependency is missing: {path / leaf}")
    return manifest


def extract_source(source, stage, commit="HEAD"):
    names = ["ui", "shelf", "keys.toml", "LICENSE", "packaging/com.thisisgm.flea.svg"]
    names += [f"tools/{name}" for name in HELPERS]
    names += git("ls-tree", "-r", "--name-only", commit, "--", "personal/branding", "personal/branding.py", source=source).splitlines()
    archive = subprocess.check_output(["git", "archive", "--format=tar", commit, "--", *names], cwd=source)
    links = []
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        for entry in tar:
            parts = PurePosixPath(entry.name)
            if parts.is_absolute() or ".." in parts.parts:
                raise Refusal(f"Unsafe archive member: {entry.name}")
            dest = stage / entry.name
            if entry.issym():
                if entry.name not in UI_LINKS:
                    raise Refusal(f"Unexpected source symlink: {entry.name}")
                want = f"/usr/share/omarchy/shell/{Path(entry.name).name}"
                if entry.linkname != want:
                    raise Refusal(f"Unexpected Omarchy symlink target: {entry.linkname}")
                links.append((dest, entry.linkname))
            elif entry.isdir():
                dest.mkdir(parents=True, exist_ok=True)
            elif entry.isfile():
                dest.parent.mkdir(parents=True, exist_ok=True)
                data = tar.extractfile(entry)
                if data is None:
                    raise Refusal(f"Archive file has no data: {entry.name}")
                with data:
                    dest.write_bytes(data.read())
                dest.chmod(entry.mode & 0o777)
            else:
                raise Refusal(f"Unsupported archive member: {entry.name}")
    for dest, target in links:
        dest.symlink_to(target)


def build(source=ROOT, checks="full", timeout=600):
    source = clean(source)
    commit = git("rev-parse", "HEAD", source=source)
    final = bundle_path(commit)
    if final.exists():
        manifest = validate(final)
        if checks == "full" and manifest["checks"] != "full":
            raise Refusal("This commit already has a quick-check bundle. Run verify --full to extend its evidence.")
        print(f"Already built: {commit}")
        return final
    env = test_environment(source)
    logs = []
    for profile, args in (("unit-debug", []), ("unit-release", ["--release"])):
        logs.append(logged(["cargo", "test", "--locked", *args], source, profile, env, timeout=timeout))
    logs.append(logged(["cargo", "build", "--release", "--locked"], source, "release-build", env, timeout=timeout))
    logs.append(logged(["python3", "-B", "-m", "unittest", "discover", "-s", str(ROOT / "personal/tests"), "-v"],
                       ROOT, "personal-tools", env, timeout=timeout))
    if checks == "full":
        logs.append(logged(["bash", "tests/run-all.sh"], source, "upstream-battery", env, timeout=timeout))
    # Build/test hooks may generate files: never package a checkout they changed.
    clean(source)
    if git("rev-parse", "HEAD", source=source) != commit:
        raise Refusal("The checkout changed while the build was running.")
    with tempfile.TemporaryDirectory(prefix="bundle-", dir=STORE / "tmp") as temporary:
        stage = Path(temporary) / commit
        stage.mkdir()
        extract_source(source, stage, commit)
        overlay = None
        if (stage / "personal/branding").is_dir():
            if (stage / "personal/branding.py").read_bytes() != (ROOT / "personal/branding.py").read_bytes():
                raise Refusal("Build Tick with the branding tool from the same source commit.")
            overlay = branding.apply(stage, commit)
        (stage / "bin").mkdir()
        shutil.copy2(source / "target/release/flea", stage / "bin/flea")
        version = subprocess.check_output([str(stage / "bin/flea"), "--version"], text=True).strip()
        manifest = {"commit": commit, "version": version, "checks": checks,
                    "release_base": git("describe", "--tags", "--match", "v[0-9]*", "--abbrev=0", commit, source=source),
                    "created_ns": time.time_ns(), "logs": logs, "files": fingerprints(stage)}
        if overlay:
            manifest["brand"] = overlay
        atomic_json(stage / "manifest.json", manifest)
        if overlay:
            probe_env = dict(env, TICK_BUNDLE=str(stage))
            logs.append(logged(["bash", "personal/tests/branding.sh"], ROOT, "tick-branding-runtime", probe_env, timeout=timeout))
            if manifest["files"] != fingerprints(stage):
                raise Refusal("Tick runtime check changed bundled assets.")
            atomic_json(stage / "manifest.json", manifest)
        os.rename(stage, final)
    validate(final)
    print(f"Built {version}: {commit}\nNext: personal/tick-dev smoke {commit}")
    return final


def promote(name):
    require_stopped()
    path = bundle_path(name)
    manifest = validate(path)
    proof = read_json(STORE / "verification" / f"{name}.json")
    if proof.get("files") != manifest["files"] or not proof.get("smoke_passed"):
        raise Refusal("Run a successful smoke test for this exact bundle before promotion.")
    if (STORE / "current").is_symlink() and selected() == path:
        print("Already current; no state or selection changed.")
        return
    current = selected() if (STORE / "current").is_symlink() else None
    snapshot = STORE / "snapshots" / str(time.time_ns())
    snapshot.mkdir(mode=0o700)
    state = STORE / "profiles/daily/state"
    if state.exists():
        shutil.copytree(state, snapshot / "state", symlinks=True)
    record = {"current": name, "previous": current.name if current else None,
              "state_snapshot": str(snapshot.relative_to(STORE))}
    # This recovery record precedes the selection change, so an interrupted promotion is traceable.
    atomic_json(STORE / "promotion.json", record)
    if current:
        atomic_link(STORE / "previous", f"releases/{current.name}")
    atomic_link(STORE / "current", f"releases/{name}")
    print(f"Current: {manifest['version']} ({name[:12]})\nLauncher: {ROOT / 'personal/tick'}")


def rollback():
    require_stopped()
    record = read_json(STORE / "promotion.json")
    if not record["previous"]:
        raise Refusal("No previous build to restore.")
    if selected().name != record["current"]:
        raise Refusal("Selection disagrees with the promotion record; refusing state restoration.")
    previous = bundle_path(record["previous"])
    validate(previous)
    snapshot = inside(STORE / record["state_snapshot"], STORE / "snapshots")
    if not snapshot.is_dir():
        raise Refusal("The state snapshot is missing; refusing rollback.")
    state = inside(STORE / "profiles/daily/state")
    displaced = STORE / "snapshots" / f"before-rollback-{time.time_ns()}"
    displaced.mkdir(mode=0o700)
    if state.exists():
        os.rename(state, displaced / "state")
    try:
        if (snapshot / "state").exists():
            shutil.copytree(snapshot / "state", state, symlinks=True)
        atomic_link(STORE / "current", f"releases/{previous.name}")
    except Exception:
        if state.exists():
            shutil.rmtree(state)
        if (displaced / "state").exists():
            os.rename(displaced / "state", state)
        raise
    record.update({"current": previous.name, "previous": None, "rolled_back_from": record["current"]})
    atomic_json(STORE / "promotion.json", record)
    (STORE / "previous").unlink(missing_ok=True)
    print(f"Restored build {previous.name[:12]} and its pre-promotion state.\nNewer state saved in {displaced}.")

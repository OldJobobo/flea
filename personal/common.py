"""Repository-local paths, subprocesses, locking and profile environments."""
from contextlib import contextmanager
from pathlib import Path
import fcntl
import json
import os
import subprocess
import tempfile
import time


class Refusal(RuntimeError):
    pass


class CheckFailure(Refusal):
    def __init__(self, message, log, timed_out=False):
        super().__init__(message)
        self.log = log
        self.timed_out = timed_out


ROOT = Path(__file__).resolve().parent.parent
STORE = ROOT / ".local-builds"


def inside(path, base=None):
    base = ROOT if base is None else base
    path = Path(path).resolve()
    if not path.is_relative_to(base.resolve()):
        raise Refusal(f"Path is outside {base}: {path}")
    return path


def initialize():
    inside(STORE)
    for leaf in ("releases", "logs", "tmp", "profiles", "snapshots", "verification"):
        inside(STORE / leaf).mkdir(parents=True, exist_ok=True, mode=0o700)


def run(args, cwd=None, env=None, capture=False, timeout=None):
    cwd = ROOT if cwd is None else cwd
    result = subprocess.run([str(a) for a in args], cwd=cwd, env=env,
                            text=True, capture_output=capture, timeout=timeout)
    if result.returncode:
        detail = (result.stderr or result.stdout or "").strip() if capture else ""
        raise Refusal(f"Command failed ({result.returncode}): {' '.join(map(str, args))}\n{detail}".rstrip())
    return result.stdout.strip() if capture else None


def git(*args, source=None) -> str:
    result = run(["git", *args], cwd=ROOT if source is None else source, capture=True)
    assert isinstance(result, str)
    return result


def clean(source):
    source = inside(source)
    if git("status", "--porcelain", "--untracked-files=all", source=source):
        raise Refusal(f"Commit or stash changes before using this checkout: {source}")
    if git("rev-parse", "--show-toplevel", source=source) != str(source):
        raise Refusal(f"Not a worktree root: {source}")
    return source


def read_json(path):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError) as error:
        raise Refusal(f"Cannot read {path}: {error}") from error


def atomic_json(path, value):
    path = inside(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".write-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as out:
            json.dump(value, out, indent=2, sort_keys=True)
            out.write("\n")
            out.flush()
            os.fsync(out.fileno())
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def atomic_link(path, target):
    path = Path(path)
    inside(path.parent)
    if path.exists() and not path.is_symlink():
        raise Refusal(f"Not a managed symlink: {path}")
    fd, name = tempfile.mkstemp(prefix=".link-", dir=path.parent)
    os.close(fd)
    os.unlink(name)
    try:
        os.symlink(target, name)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


@contextmanager
def locked():
    initialize()
    lock = inside(STORE / "deployment.lock")
    with lock.open("a") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise Refusal("Another deployment operation is running.") from error
        yield


def active_processes():
    found = []
    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit() or int(proc.name) == os.getpid():
            continue
        try:
            if proc.stat().st_uid != os.getuid():
                continue
            env = (proc / "environ").read_bytes().split(b"\0")
            if f"FLEA_CUSTOM_ROOT={ROOT}".encode() in env:
                found.append(int(proc.name))
        except (OSError, PermissionError, ProcessLookupError):
            continue
    return found


def require_stopped():
    pids = active_processes()
    if pids:
        raise Refusal(f"Close custom Flea windows and services first (PIDs: {', '.join(map(str, pids))}).")


def environment(bundle, profile="daily", runtime=None):
    initialize()
    if profile not in ("daily", "smoke"):
        raise Refusal("Unknown profile.")
    bundle = inside(bundle, STORE / "releases")
    home = inside(STORE / "profiles" / profile)
    for leaf in ("state", "cache", "cache/qml"):
        inside(home / leaf).mkdir(parents=True, exist_ok=True, mode=0o700)
    env = os.environ.copy()
    env.update({
        "FLEA_CUSTOM_ROOT": str(ROOT), "FLEA_CUSTOM_BUNDLE": str(bundle),
        "FLEA_UI": str(bundle / "ui"), "FLEA_BIN": str(bundle / "bin/flea"),
        "FLEA_GIO_AUTH": str(bundle / "tools/flea-gio-auth"),
        "FLEA_UDISKS": str(bundle / "tools/flea-udisks"),
        "FLEA_SHELF": str(bundle / "shelf"),
        "FLEA_UNDO_DIR": str(home / "state/flea/undo"),
        "XDG_STATE_HOME": str(home / "state"), "XDG_CACHE_HOME": str(home / "cache"),
        "QML_DISK_CACHE_PATH": str(home / "cache/qml"), "TMPDIR": str(STORE / "tmp"),
    })
    if runtime:
        env["XDG_RUNTIME_DIR"] = str(runtime)
    return env


def test_environment(source=None):
    source = ROOT if source is None else source
    initialize()
    env = os.environ.copy()
    home = STORE / "test-home"
    home.mkdir(exist_ok=True, mode=0o700)
    (STORE / "fixtures").mkdir(exist_ok=True, mode=0o700)
    runtime = STORE / "test-runtime"
    runtime.mkdir(exist_ok=True, mode=0o700)
    env.update({"HOME": str(home), "RUSTUP_HOME": os.environ.get("RUSTUP_HOME", str(Path.home() / ".rustup")),
                "PATH": str(Path.home() / ".cargo/bin") + ":/usr/bin:/bin",
                # /tmp is bind-mounted to STORE/tmp; conventional paths keep upstream fixtures valid.
                "TMPDIR": "/tmp", "CARGO_HOME": str(STORE / "cargo-home"),
                "CARGO_TARGET_DIR": str(source / "target"), "FLEA_FIXTURE_ROOT": "/tmp/f",
                "XDG_RUNTIME_DIR": "/tmp/r", "XDG_CONFIG_HOME": str(home / ".config"),
                "XDG_DATA_HOME": str(home / ".local/share"), "XDG_CACHE_HOME": str(home / ".cache"),
                "XDG_STATE_HOME": str(home / ".local/state")})
    return env


def sandbox_command(args):
    # A private in-repository tmpfs avoids host-filesystem directory-order assumptions.
    # The inner namespace binds that memory-backed repository path to conventional /tmp.
    inner = ["bwrap", "--ro-bind", "/", "/", "--bind", str(ROOT), str(ROOT),
             "--bind", str(STORE / "tmp"), "/tmp", "--dev", "/dev", "--proc", "/proc",
             "--die-with-parent", "--", "sh", "-c",
             'mkdir -p /tmp/r /tmp/f && chmod 700 /tmp/r && exec "$@"', "flea-test", *args]
    return ["bwrap", "--ro-bind", "/", "/", "--bind", str(ROOT), str(ROOT),
            "--tmpfs", str(STORE / "tmp"), "--dev", "/dev", "--proc", "/proc",
            "--unshare-pid", "--unshare-ipc", "--unshare-net", "--die-with-parent", "--", *inner]


def logged(args, source, label, env, timeout=600):
    initialize()
    if timeout <= 0:
        raise Refusal("Check timeout must be a positive number of seconds.")
    path = STORE / "logs" / f"{time.time_ns()}-{label}.log"
    print(f"Checking {label}…", flush=True)
    try:
        with path.open("w") as output:
            result = subprocess.run(sandbox_command(args), cwd=source, env=env, stdout=output,
                                    stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        raise CheckFailure(f"{label} timed out after {timeout}s; it is incomplete. Log: {path}",
                           str(path.relative_to(ROOT)), timed_out=True) from error
    if result.returncode:
        tail = path.read_text(errors="replace").splitlines()[-12:]
        raise CheckFailure(f"{label} failed ({result.returncode}). Log: {path}\n" + "\n".join(tail),
                           str(path.relative_to(ROOT)))
    print(f"  passed; log: {path.relative_to(ROOT)}", flush=True)
    return str(path.relative_to(ROOT))

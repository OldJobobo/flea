"""Disposable-file backend and real Quickshell startup checks."""
from pathlib import Path
import json
import os
import select
import signal
import subprocess
import tempfile
import time

from bundles import bundle_path, validate
from common import ROOT, STORE, Refusal, atomic_json, environment


def stop(process):
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=5)


def backend_check(bundle, fixture, env):
    process = subprocess.Popen([str(bundle / "bin/flea"), "--backend"], env=env,
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, start_new_session=True)
    assert process.stdin is not None and process.stdout is not None and process.stderr is not None
    try:
        request = {"c": "list", "path": str(fixture), "first": 20, "hidden": False}
        process.stdin.write((json.dumps(request) + "\n").encode())
        process.stdin.flush()
        data = b""
        messages = []
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            ready, _, _ = select.select([process.stdout], [], [], 0.25)
            if ready:
                chunk = os.read(process.stdout.fileno(), 65536)
                if not chunk:
                    break
                data += chunk
                while b"\n" in data:
                    line, data = data.split(b"\n", 1)
                    messages.append(json.loads(line))
            if any(message.get("t") == "rows" for message in messages):
                break
        errors = [m for m in messages if m.get("t") == "error"]
        listed = [m for m in messages if m.get("t") == "listed"]
        rows = [m for m in messages if m.get("t") == "rows"]
        if errors or not listed or not rows or listed[0].get("n") != 3:
            raise Refusal(f"Backend did not return the three-file fixture: {messages}")
        process.stdin.write(b'{"c":"quit"}\n')
        process.stdin.flush()
        process.communicate(timeout=5)
        if process.returncode:
            raise Refusal(f"Backend exited {process.returncode}.")
    finally:
        stop(process)
        for stream in (process.stdin, process.stdout, process.stderr):
            if stream is not None:
                stream.close()


def gui_check(bundle, fixture, env, log, native=False):
    if not native:
        env.update({"QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
                    "QSG_RHI_BACKEND": "software", "QT_QPA_PLATFORMTHEME": "generic"})
    with log.open("w") as output:
        process = subprocess.Popen([str(bundle / "bin/flea"), "--gui", str(fixture)], env=env,
                                   stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            deadline = time.monotonic() + 30
            last = "No IPC reply"
            while time.monotonic() < deadline and process.poll() is None:
                values = []
                for method in ("ready", "path", "total", "themeLoaded"):
                    try:
                        result = subprocess.run(["qs", "ipc", "--pid", str(process.pid),
                                                 "call", "flea", method], env=env,
                                                capture_output=True, text=True, timeout=3)
                    except subprocess.TimeoutExpired:
                        break
                    values.append(result.stdout.strip() if result.returncode == 0 else "")
                    last = result.stderr.strip() or str(values)
                if values == ["true", str(fixture), "3", "true"]:
                    return
                time.sleep(0.2)
            raise Refusal(f"GUI did not settle on the fixture with a loaded theme: {last}\nLog: {log}")
        finally:
            stop(process)


def smoke(name, native=False):
    bundle = bundle_path(name)
    manifest = validate(bundle)
    log = STORE / "logs" / f"{time.time_ns()}-smoke-{'native' if native else 'offscreen'}.log"
    with tempfile.TemporaryDirectory(prefix="smoke-", dir=STORE / "tmp") as temporary:
        root = Path(temporary)
        fixture = root / "files"
        fixture.mkdir()
        (fixture / "example.txt").write_text("Custom Flea smoke fixture.\n")
        (fixture / "example.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10" fill="red"/></svg>')
        (fixture / "folder").mkdir()
        runtime = root / "runtime"
        runtime.mkdir(mode=0o700)
        env = environment(bundle, "smoke", None if native else runtime)
        print("Checking deployed backend and GUI with disposable files…", flush=True)
        backend_check(bundle, fixture, env)
        gui_check(bundle, fixture, env, log, native)
    proof_path = STORE / "verification" / f"{name}.json"
    previous = json.loads(proof_path.read_text()) if proof_path.exists() else {}
    proof = {**previous, "files": manifest["files"], "smoke_passed": True,
             "smoke_mode": "native" if native else "offscreen", "smoke_ns": time.time_ns(),
             "smoke_log": str(log.relative_to(ROOT))}
    atomic_json(proof_path, proof)
    print(f"Passed: backend listing, GUI startup, fixture count, and Omarchy theme loading.\nLog: {log.relative_to(ROOT)}")

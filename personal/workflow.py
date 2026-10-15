"""Upstream tracking and clean contribution/sync worktrees."""
from datetime import datetime, timezone
import re

from common import ROOT, Refusal, clean, git, inside, run


def latest_release():
    tags = git("tag", "--sort=-version:refname").splitlines()
    for tag in tags:
        if not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
            continue
        # Exclude personal version tags that do not belong to upstream's history.
        import subprocess
        if subprocess.run(["git", "merge-base", "--is-ancestor", tag, "upstream/main"],
                          cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            return tag
    raise Refusal("No stable upstream release tag is available. Run fetch first.")


def fetch():
    print("Fetching upstream; personal and deployed builds stay unchanged…", flush=True)
    run(["git", "fetch", "upstream", "--tags", "--prune"])
    tree = inside(ROOT / ".personal-worktrees/upstream")
    if not tree.exists():
        run(["git", "worktree", "add", str(tree), "main"])
    clean(tree)
    if git("branch", "--show-current", source=tree) != "main":
        raise Refusal("The upstream worktree is not on main.")
    run(["git", "merge", "--ff-only", "upstream/main"], cwd=tree)
    print(f"Clean main is current. Latest stable release: {latest_release()}")


def new_worktree(branch, base):
    run(["git", "check-ref-format", "--branch", branch], capture=True)
    git("rev-parse", "--verify", f"{base}^{{commit}}")
    path = inside(ROOT / ".personal-worktrees" / branch.replace("/", "-"))
    if path.exists():
        raise Refusal(f"Worktree already exists: {path}")
    path.parent.mkdir(exist_ok=True)
    run(["git", "worktree", "add", "-b", branch, str(path), base])
    return path


def feature(name):
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", name):
        raise Refusal("Use a lowercase, hyphenated feature name.")
    path = new_worktree(f"feature/{name}", "upstream/main")
    print(f"Clean contribution branch: feature/{name}\nWorktree: {path}\nPersonal deployment commits are not included.")


def sync(base="release"):
    clean(ROOT)
    if git("branch", "--show-current") != "personal":
        raise Refusal("Start an upstream sync from the personal checkout.")
    ref = latest_release() if base == "release" else "upstream/main"
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    branch = f"sync/{stamp}"
    tree = new_worktree(branch, "personal")
    print(f"Merging {ref} into {branch}; daily deployment stays unchanged…", flush=True)
    try:
        run(["git", "merge", "--no-edit", ref], cwd=tree)
    except Refusal as error:
        raise Refusal(f"Sync needs attention in {tree}. Resolve or abort the merge there.\n{error}") from error
    print(f"Candidate: {branch}\nWorktree: {tree}\nValidate here before integrating into personal.")


def integrate(branch):
    clean(ROOT)
    if git("branch", "--show-current") != "personal":
        raise Refusal("Integrate only from the personal checkout.")
    if not re.fullmatch(r"(?:feature|sync)/[a-zA-Z0-9-]+", branch):
        raise Refusal("Integrate an explicit feature/<name> or sync/<date> branch.")
    git("rev-parse", "--verify", f"refs/heads/{branch}")
    run(["git", "merge", "--no-ff", "--no-edit", branch])
    print("Integrated. Daily build is unchanged; build and smoke-test before promotion.")


def status():
    from bundles import selected, validate
    from common import STORE, read_json
    print(f"Checkout: {git('branch', '--show-current')} ({git('rev-parse', '--short', 'HEAD')})")
    print(f"Working tree: {'dirty' if git('status', '--porcelain') else 'clean'}")
    print(f"Latest fetched release: {latest_release()} (remote not checked)")
    for name in ("current", "previous"):
        try:
            path = selected(name)
        except Refusal:
            print(f"{name.capitalize()}: not selected")
            continue
        manifest = validate(path)
        brand = manifest.get("brand", {}).get("name", "Flea")
        print(f"{name.capitalize()}: {brand} / {manifest['version']} / {path.name[:12]} / {manifest['checks']} checks")
        proof_path = STORE / "verification" / f"{path.name}.json"
        if proof_path.exists():
            proof = read_json(proof_path)
            print(f"  smoke: {proof.get('smoke_mode', 'not checked')}; full battery: {proof.get('full_battery', 'not run')}")
    print("Stock fallback: /usr/bin/flea\nDesktop routing is separate; status does not change defaults.")

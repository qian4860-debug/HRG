"""Publish the committed local tree under HRG_WA/ without rewriting history."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
URL = "https://github.com/qian4860-debug/HRG.git"
PREFIX = "HRG_WA"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--push", action="store_true", help="publish after verification")
    parser.add_argument("--proxy", help="optional command-local HTTP proxy")
    parser.add_argument("--committed-only", action="store_true",
                        help="export HEAD only; leave and omit all working-tree changes")
    args = parser.parse_args()
    base = ["git", "-c", f"safe.directory={ROOT.as_posix()}",
            "-c", "user.name=Codex", "-c", "user.email=codex@local"]
    if args.proxy:
        base += ["-c", f"http.proxy={args.proxy}"]

    def git(*cmd, env=None, data=None):
        result = subprocess.run(base + list(cmd), cwd=ROOT, env=env, input=data,
                                stdout=subprocess.PIPE, check=True)
        return result.stdout.decode("utf-8").strip()

    dirty = git("status", "--porcelain")
    if dirty:
        if not args.committed_only:
            raise SystemExit("Commit or resolve local changes before publishing, or explicitly use --committed-only.")
        print("Exporting committed HEAD only; these working-tree changes are preserved and omitted:\n" + dirty)
    if git("remote", "get-url", "origin") != URL:
        raise SystemExit("origin does not match the authorized HRG repository.")
    git("fetch", "origin", "main")
    source = git("rev-parse", "HEAD")
    source_tree = git("rev-parse", "HEAD^{tree}")
    remote = git("rev-parse", "refs/remotes/origin/main")
    # A remote subproject may only be replaced if its exact tree is present in
    # local history. This stops an outdated checkout overwriting remote edits.
    existing = git("ls-tree", remote, PREFIX)
    if existing:
        mode, kind, sha_path = existing.split(" ", 2)
        old_tree, path = sha_path.split("\t", 1)
        local_trees = set(git("log", "--format=%T", source).splitlines())
        if kind != "tree" or old_tree not in local_trees:
            raise SystemExit("Remote HRG_WA has changes absent from local history; reconcile first.")
        if old_tree == source_tree:
            print("Remote HRG_WA already matches local HEAD.")
            return
    with tempfile.TemporaryDirectory(prefix="hrg-publish-") as tmp:
        env = dict(os.environ, GIT_INDEX_FILE=str(Path(tmp) / "index"))
        git("read-tree", remote, env=env)
        if existing:
            paths = subprocess.check_output(base + ["ls-tree", "-r", "--name-only", "-z", remote, PREFIX], cwd=ROOT)
            git("update-index", "--force-remove", "-z", "--stdin", env=env, data=paths)
        git("read-tree", f"--prefix={PREFIX}/", source_tree, env=env)
        tree = git("write-tree", env=env)
    # Original project commits remain unchanged as the second parent.
    commit = git("commit-tree", tree, "-p", remote, "-p", source,
                 "-m", "Import HRG_WA subproject preserving original project history")
    assert git("rev-parse", f"{commit}:{PREFIX}") == source_tree
    # The temporary index must not change sibling files in the parent repo.
    before = [x for x in git("ls-tree", remote).splitlines() if x.split("\t", 1)[-1] != PREFIX]
    after = [x for x in git("ls-tree", commit).splitlines() if x.split("\t", 1)[-1] != PREFIX]
    assert before == after, "Parent repository siblings changed"
    git("update-ref", "refs/heads/codex/github-hrg-wa", commit)
    tag_specs = []
    for tag in git("tag", "--list").splitlines():
        if tag.startswith("HRG_WA/"):
            continue
        tag_specs.append(f"refs/tags/{tag}:refs/tags/HRG_WA/{tag}")
    print(f"Verified subtree byte identity: {source_tree}; export commit: {commit}")
    if args.push:
        git("push", "--atomic", "origin", f"{commit}:refs/heads/main", *tag_specs)
        git("fetch", "origin", "main")
        assert git("rev-parse", "origin/main:HRG_WA") == source_tree
        print("Published and verified HRG/main:HRG_WA; original tags use HRG_WA/ namespace.")
    else:
        print("Prepared locally only. Add --push to publish.")


if __name__ == "__main__":
    main()

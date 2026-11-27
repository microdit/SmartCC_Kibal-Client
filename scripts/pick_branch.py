#!/usr/bin/env python3
"""Pick branch selector — lists local (and known remote) branches for git-pull.

Usage:
  python scripts/pick_branch.py --list
  python scripts/pick_branch.py --info <branch>
"""
import argparse
import subprocess
import sys
from pathlib import Path


def root() -> Path:
    return Path(__file__).resolve().parent.parent


def git(*args: str) -> str:
    try:
        return subprocess.run(
            ["git", *args], capture_output=True, text=True, cwd=root()
        ).stdout.strip()
    except Exception:
        return ""


def local_branches() -> list[str]:
    out = git("for-each-ref", "--format=%(refname:short)", "refs/heads")
    return [b for b in out.splitlines() if b]


def remote_branches() -> list[str]:
    out = git("for-each-ref", "--format=%(refname:short)", "refs/remotes")
    return [b for b in out.splitlines() if b]


def resolve_remote(branch: str) -> tuple[str, str]:
    if "/" in branch:
        prefix, target = branch.split("/", 1)
        if prefix in git("remote").splitlines():
            return prefix, target
    return "origin", branch


def branch_version(ref: str) -> str:
    for path in ("macos-client/pubspec.yaml", "pubspec.yaml"):
        out = git("show", f"{ref}:{path}")
        for line in out.splitlines():
            if line.startswith("version:"):
                return line.split(":", 1)[1].strip()
    return "-"


def feature_summary(branch: str) -> str:
    prefix, _, target = branch.partition("/")
    if prefix not in git("remote").splitlines():
        target = branch
    if target == "test/client-v0.0.64-recovery":
        return "TEST 검수(로그 1~60분/이중저장)"
    if target == "feature/external-network-access":
        return "DEV 안정화/외부망 라인"
    if target.startswith("test/") or target == "test-pending-verification":
        return "TEST 검수 브랜치"
    if "external" in target:
        return "외부망 기능 브랜치"
    if target.startswith("feature/"):
        return "기능 브랜치"
    return "기능 브랜치"


def info(branch: str):
    remote, target = resolve_remote(branch)
    ref = f"{remote}/{target}"
    commit = git("rev-parse", "--short", ref) or "-"
    version = branch_version(ref)
    summary = feature_summary(branch)
    print(f"{branch}\t{remote}\t{target}\t{version}\t{commit}\t{summary}")


def main():
    ap = argparse.ArgumentParser(description="Branch selector for git-pull")
    ap.add_argument("--list", action="store_true", help="List branches")
    ap.add_argument("--info", metavar="BRANCH", help="Print remote/version/commit/summary for a branch")
    args = ap.parse_args()

    if args.info:
        info(args.info)
        return
    if args.list:
        seen = set()
        for b in local_branches():
            if b not in seen:
                print(b)
                seen.add(b)
        remotes = set(git("remote").splitlines())
        for b in remote_branches():
            if "/" not in b or b.endswith("/HEAD"):
                continue
            prefix, target = b.split("/", 1)
            if prefix in remotes and target in seen:
                continue
            if b not in seen:
                print(b)
                seen.add(b)
        return
    ap.print_help()
    sys.exit(1)


if __name__ == "__main__":
    main()

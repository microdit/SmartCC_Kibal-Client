#!/usr/bin/env python3
"""Pick branch selector — lists local (and known remote) branches for git-pull.
   SmartCC_Kibal (Kibal IP-PBX) variant.  Usage:
     python scripts/pick_branch.py --list
   Prints one branch per line (local branches first, then known remote branches).
"""
import argparse
import subprocess
import sys
from pathlib import Path


def root() -> Path:
    return Path(__file__).resolve().parent.parent


def local_branches() -> list[str]:
    out = subprocess.run(
        ["git", "for-each-ref", "--format=%(refname:short)", "refs/heads"],
        capture_output=True, text=True, cwd=root(),
    ).stdout.strip()
    return [b for b in out.splitlines() if b]


def remote_branches() -> list[str]:
    out = subprocess.run(
        ["git", "for-each-ref", "--format=%(refname:short)", "refs/remotes"],
        capture_output=True, text=True, cwd=root(),
    ).stdout.strip()
    result = []
    for b in out.splitlines():
        if b:
            result.append(b)
    return result


def main():
    ap = argparse.ArgumentParser(description="Branch selector for git-pull")
    ap.add_argument("--list", action="store_true", help="List branches")
    args = ap.parse_args()

    if args.list:
        seen = set()
        for b in local_branches():
            if b not in seen:
                print(b)
                seen.add(b)
        for b in remote_branches():
            if b not in seen:
                print(b)
                seen.add(b)
    else:
        ap.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()

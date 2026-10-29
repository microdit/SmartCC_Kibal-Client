#!/usr/bin/env python3
"""
Universal Log System — 모든 스크립트 실행 결과를 docs/_작업이력/log/ 에 기록한다.

Usage:
    python scripts/log.py <name> <status> [duration]
    python scripts/log.py --level debug <name> <status> [duration]
    python scripts/log.py --list [--limit N]
    python scripts/log.py --last
    python scripts/log.py --search <keyword>
    python scripts/log.py --failed

Level:
    info (default)  →  YYYY-MM-DD_HHMMSS_name.md
    warning         →  (same file as info)
    debug           →  YYYY-MM-DD_HHMMSS_name_debug.md

Environment:
    LOG_LEVEL       override default level (debug/info/warning)
    LOG_DIR         output directory (default: docs/_작업이력/log/)
"""

from __future__ import annotations

import argparse
import datetime
import os
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_LOG_DIR = REPO_ROOT / "docs" / "_작업이력" / "log"
TIMESTAMP_FMT = "%Y-%m-%d %H:%M:%S"
FILE_PREFIX_FMT = "%Y-%m-%d_%H%M%S"
VALID_LEVELS = ("info", "debug", "warning")
VALID_STATUSES = ("PASSED", "FAILED", "RUNNING", "SKIPPED", "ERROR")


def get_log_dir() -> Path:
    env_dir = os.environ.get("LOG_DIR", "")
    return Path(env_dir) if env_dir else DEFAULT_LOG_DIR


def get_effective_level(cli_level: str | None) -> str:
    if cli_level and cli_level in VALID_LEVELS:
        return cli_level
    env_level = os.environ.get("LOG_LEVEL", "").lower().strip()
    if env_level in VALID_LEVELS:
        return env_level
    return "info"


def should_write(requested_level: str, effective_level: str) -> bool:
    order = {"debug": 0, "info": 1, "warning": 2}
    return order.get(requested_level, 1) >= order.get(effective_level, 1)


def sanitize_name(name: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]", "_", name)[:60]


def parse_pytest_output(text: str) -> dict:
    result = {"passed": 0, "failed": 0, "errors": 0, "skipped": 0, "total": 0}
    lines = text.splitlines()
    for line in lines:
        m = re.match(r"={3,}\s*(\d+)\s+(passed|failed|error|skipped)", line)
        if m:
            result[m.group(2)] = int(m.group(1))
            continue
        m2 = re.match(r"^(\d+)\s+(passed|failed|error|skipped)", line)
        if m2:
            result[m2.group(2)] = int(m2.group(1))
            continue
    for key in ("passed", "failed", "error", "skipped"):
        m = re.search(rf"(\d+)\s+{key}", text)
        if m:
            result[key if key != "error" else "errors"] = max(
                result[key if key != "error" else "errors"], int(m.group(1))
            )
    result["total"] = result["passed"] + result["failed"] + result["errors"] + result["skipped"]
    failed_tests = []
    for line in lines:
        m = re.match(r"^(FAILED|ERROR)\s+(.+)$", line)
        if m:
            failed_tests.append(m.group(2).strip())
    result["failed_tests"] = failed_tests
    result["status"] = "PASSED" if result["failed"] == 0 and result["errors"] == 0 else "FAILED"
    return result


def parse_vitest_output(text: str) -> dict:
    result = {"passed": 0, "failed": 0, "errors": 0, "skipped": 0, "total": 0}
    for line in text.splitlines():
        m = re.search(r"Tests\s+(\d+)\s+passed\s*\|?\s*(\d+)?\s*failed\s*\|?\s*(\d+)?\s*skipped", line)
        if m:
            result["passed"] = int(m.group(1))
            result["failed"] = int(m.group(2)) if m.group(2) else 0
            result["skipped"] = int(m.group(3)) if m.group(3) else 0
            result["total"] = result["passed"] + result["failed"] + result["skipped"]
            break
    if result["total"] == 0:
        for line in text.splitlines():
            m = re.match(r"^\s+Tests\s+(\d+)\s+passed\s+\((\d+)\)", line)
            if m:
                result["passed"] = int(m.group(1))
                result["total"] = int(m.group(1))
    result["status"] = "PASSED" if result["failed"] == 0 and result["errors"] == 0 else "FAILED"
    failed_tests = []
    for line in text.splitlines():
        m = re.search(r".*×\s+(.+)\s+\(\d+\s+ms\)", line)
        if m:
            failed_tests.append(m.group(1).strip())
    result["failed_tests"] = failed_tests
    return result


def save_entry(
    name: str,
    status: str,
    duration: float = 0.0,
    level: str = "info",
    command: str = "",
    description: str = "",
    stdout: str = "",
    stderr: str = "",
    returncode: int = 0,
    summary: dict | None = None,
) -> Path | None:
    effective = get_effective_level(level)
    if not should_write(level, effective):
        return None

    log_dir = get_log_dir()
    log_dir.mkdir(parents=True, exist_ok=True)
    now = datetime.datetime.now()
    safe_name = sanitize_name(name)
    debug_suffix = "_debug" if level == "debug" else ""
    filename = f"{now.strftime(FILE_PREFIX_FMT)}_{safe_name}{debug_suffix}.md"
    filepath = log_dir / filename

    if summary is None:
        combined = (stdout or "") + "\n" + (stderr or "")
        if "pytest" in command:
            summary = parse_pytest_output(combined)
        elif "vitest" in command or "npx vitest" in command:
            summary = parse_vitest_output(combined)
        else:
            summary = {
                "passed": 0, "failed": 0, "errors": 0, "skipped": 0,
                "total": 0, "status": status,
                "failed_tests": [],
            }

    lines_stdout = (stdout or "").splitlines()
    lines_stderr = (stderr or "").splitlines()
    max_preview = 100

    content = f"""# Test Log — {name}

## Meta
- **Date**: {now.strftime(TIMESTAMP_FMT)}
- **Level**: {level}
- **Name**: {name}
- **Command**: `{command}`
- **Description**: {description}
- **Status**: {status}
- **Duration**: {duration:.2f}s
- **Exit Code**: {returncode}
- **Log File**: `{filename}`

## Summary
- **Total**: {summary.get('total', 0)}
- **Passed**: {summary.get('passed', 0)}
- **Failed**: {summary.get('failed', 0)}
- **Errors**: {summary.get('errors', 0)}
- **Skipped**: {summary.get('skipped', 0)}
"""

    failed_tests = summary.get("failed_tests", [])
    if failed_tests:
        content += f"""
## Failed Tests
"""
        for ft in failed_tests:
            content += f"""
### {ft}
- **Analysis**:
- **Fix applied**:
- **Re-run result**:
"""
        content += "\n"

    if lines_stderr and stderr.strip():
        content += f"""
## Stderr
```
{stderr.strip()[:2000]}
```
"""

    if returncode != 0 and level != "debug":
        content += f"""
## Error Details
```
{stderr.strip()[:1000] if stderr.strip() else stdout.strip()[:1000]}
```
"""

    if lines_stdout:
        content += f"""
## Output (first {max_preview} lines)
```text
"""
        preview = lines_stdout[:max_preview]
        content += "\n".join(preview)
        if len(lines_stdout) > max_preview:
            content += f"\n... (truncated, {len(lines_stdout)} lines total)"
        content += """
```
"""

    if level == "debug":
        content += """
---
## Debug Trace
(step-by-step execution details)
"""

    content += """

---
## AI Analysis
<!-- ilkkung AI Agent fills during debugging -->

### Observations
-

### Root Cause Analysis
-

### Recommended Fix
-

### Re-run Verification
-
"""

    filepath.write_text(content, encoding="utf-8")
    return filepath


def list_logs(limit: int = 10, level_filter: str | None = None, keyword: str | None = None, failed_only: bool = False):
    log_dir = get_log_dir()
    if not log_dir.exists():
        print("No test logs found.")
        return
    files = sorted(log_dir.glob("*.md"), reverse=True)
    if not files:
        print("No test logs found.")
        return

    count = 0
    print(f"{'Date':<20} {'Level':<8} {'Status':<10} {'Name':<40}")
    print("-" * 80)
    for f in files:
        if f.name == "README.md":
            continue
        content = f.read_text(encoding="utf-8")
        name = "?"
        status = "?"
        level = "?"
        for line in content.splitlines():
            m = re.search(r"\*\*Name\*\*:\s*(.+)", line)
            if m:
                name = m.group(1).strip()[:38]
            m2 = re.search(r"\*\*Status\*\*:\s*(.+)", line)
            if m2:
                status = m2.group(1).strip()
            m3 = re.search(r"\*\*Level\*\*:\s*(.+)", line)
            if m3:
                level = m3.group(1).strip()

        if level_filter and level != level_filter:
            continue
        if keyword and keyword.lower() not in name.lower() and keyword not in f.name:
            continue
        if failed_only and status != "FAILED":
            continue

        count += 1
        if count > limit:
            break
        icon = "✅" if status == "PASSED" else "❌"
        date = f.stem[:19]
        print(f"{date:<20} {level:<8} {icon:<10} {name:<40}")

    if count == 0:
        print("No matching logs found.")


def show_last():
    log_dir = get_log_dir()
    if not log_dir.exists():
        print("No test logs found.")
        return
    files = sorted(log_dir.glob("*.md"), reverse=True)
    if not files:
        print("No test logs found.")
        return
    content = files[0].read_text(encoding="utf-8")
    print(content)


def cli():
    parser = argparse.ArgumentParser(description="Universal Log System")
    parser.add_argument("name", nargs="?", help="Log entry name")
    parser.add_argument("status", nargs="?", choices=VALID_STATUSES, help="Status")
    parser.add_argument("duration", nargs="?", type=float, default=0.0, help="Duration in seconds")
    parser.add_argument("--level", "-l", choices=VALID_LEVELS, default=None, help="Log level")
    parser.add_argument("--desc", "-d", default="", help="Description")
    parser.add_argument("--list", action="store_true", help="List recent logs")
    parser.add_argument("--limit", type=int, default=10, help="Number of logs to show")
    parser.add_argument("--last", action="store_true", help="Show last log")
    parser.add_argument("--search", metavar="KEYWORD", help="Search logs by keyword")
    parser.add_argument("--failed", action="store_true", help="Show only FAILED logs")

    args = parser.parse_args()

    if args.list:
        list_logs(args.limit)
        return

    if args.last:
        show_last()
        return

    if args.search:
        list_logs(args.limit, keyword=args.search)
        return

    if args.failed:
        list_logs(args.limit, failed_only=True)
        return

    # Check stdin for output piped data
    stdin_data = ""
    if not sys.stdin.isatty():
        stdin_data = sys.stdin.read()

    if not args.name or not args.status:
        parser.print_help()
        sys.exit(1)

    filepath = save_entry(
        name=args.name,
        status=args.status,
        duration=args.duration,
        level=args.level or "info",
        command=" ".join(sys.argv),
        description=args.desc,
        stdout=stdin_data,
        returncode=0 if args.status == "PASSED" else 1,
    )

    if filepath:
        print(f"Log saved: {filepath}")


if __name__ == "__main__":
    cli()

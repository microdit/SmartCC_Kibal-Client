#!/usr/bin/env python3
"""Auto-generate commit message from work logs + staged changes.
   v1.1 — title parsing fix, session-only changes, staged categorization, cp949 title file."""

from __future__ import annotations

import hashlib, json, locale, os, re, subprocess, sys
from datetime import date, datetime
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")


def root() -> Path:
    return Path(__file__).resolve().parent.parent


def sanitize_filename(name: str, max_len: int = 40) -> str:
    """Sanitize a string for use as a filename across Windows/Linux.
    Replaces all batch-dangerous characters (space, comma, parens, etc.)
    with underscore."""
    safe = re.sub(r'[\\/:*?"<>|,;=&()^%!@#$~\[\]{} ]', '_', name)
    safe = re.sub(r'_+', '_', safe)
    safe = safe.strip('_.')
    return safe[:max_len] or "auto"


def staged_files() -> list[str]:
    r = subprocess.run(
        ["git", "-c", "core.quotepath=false", "diff", "--name-only", "--cached"],
        capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=root(),
    )
    files = [f for f in r.stdout.strip().split("\n") if f] if r.returncode == 0 else []

    # Only include docs/ and root-level files (no wiki/)
    files = [f for f in files if not f.startswith(("node_modules/", "dist/", "logs/", ".git/"))]
    return files



def latest_log(dir: Path) -> Path | None:
    today = dir / f"{date.today().isoformat()}.md"
    if today.exists():
        return today
    candidates = sorted(dir.glob("[0-9][0-9][0-9][0-9]-*.md"), key=lambda f: f.name, reverse=True)
    return candidates[0] if candidates else None


# ── title extraction ──────────────────────────────────────────────

def extract_title(text: str) -> str | None:
    """# 헤더에서 의미 있는 타이틀 추출
       Supports: "# 로그: 2026-07-01 — 설명" and "# AGENTS.md — 설명" formats."""

    m = re.search(r'^#\s+(.+)', text, re.MULTILINE)
    if not m:
        return None
    raw = m.group(1).strip()

    # case 1: "로그: 2026-07-01 — 설명글" → "설명글"
    # use LAST occurrence to avoid matching date hyphen
    sep = None
    for m2 in re.finditer(r'(?<!\d)[—\-–](?!\d)\s*(.+)', raw):
        sep = m2
    if sep:
        after = sep.group(1).strip()
        if not re.match(r'^\d{4}[-/]\d{2}[-/]\d{2}', after) and not re.match(r'^v?\d+\.\d+', after):
            return after[:72]

    # case 2: 앞부분 (날짜 + 로그 레이블 + 구분자 제거)
    before = re.sub(r'\d{4}[-/]\d{2}[-/]\d{2}', '', raw).strip()
    before = re.sub(r'로그\s*', '', before).strip()
    before = re.sub(r'\s*[—\-–|:]\s*', '', before).strip()
    before = re.sub(r'\(.*?\)', '', before).strip()
    before = re.sub(r'\s+', ' ', before).strip()
    if before and len(before) > 3:
        return before[:72]

    return raw[:72]


# ── change extraction ─────────────────────────────────────────────

def _extract_changes_from_section(sec_text: str) -> list[str]:
    """Extract changes from a section: bullets, numbered lists, table cells."""
    changes = set()

    # markdown table content (non-header rows, second column)
    for cells in re.findall(r'^\|\s*.+?\|\s*(.+?)\s*\|', sec_text, re.MULTILINE):
        v = cells.strip()
        if v and not re.match(r'^-+$', v):
            changes.add(v)

    # bullet points: "- xxx" or "* xxx"
    for line in re.findall(r'^\s*[-*]\s+(.+)$', sec_text, re.MULTILINE):
        changes.add(line.strip())

    # numbered lists: "1. xxx" or "1) xxx"
    for line in re.findall(r'^\s*(?:\d+\.\s*|\d+\)\s*)(.+)', sec_text, re.MULTILINE):
        changes.add(line.strip())

    return sorted(changes)


def _changes_from_section(text: str, heading: str) -> list[str]:
    """Find a section by heading name and extract changes from it.
       Supports both h2 (## 변경 파일) and h3 (### 변경 파일)."""
    # h2 top-level
    m = re.search(rf'^##\s*{re.escape(heading)}\s*\n(.+?)(?=\n##|\Z)', text, re.DOTALL | re.MULTILINE)
    if m:
        return _extract_changes_from_section(m.group(1))
    # h3 nested under h2 sections
    m = re.search(rf'^###\s*{re.escape(heading)}\s*\n(.+?)(?=\n(?:##|###)|\Z)', text, re.DOTALL | re.MULTILINE)
    if m:
        return _extract_changes_from_section(m.group(1))
    return []


# ── log / agents detectors ────────────────────────────────────────

def try_log(path: Path) -> dict | None:
    if not path:
        return None
    text = path.read_text(encoding="utf-8")

    title = extract_title(text)
    if not title:
        title = "Work update"

    changes = _changes_from_section(text, "변경 사항")
    if not changes:
        changes = _changes_from_section(text, "변경 파일")
    if not changes:
        # fallback: extract from ALL h3 sub-sections (bullets, tables, numbered lists)
        for sub in re.findall(r'^###\s+.+?\n(.*?)(?=\n(?:##|###)|\Z)', text, re.DOTALL | re.MULTILINE):
            changes.extend(_extract_changes_from_section(sub))
    if not changes:
        changes = _changes_from_section(text, "작업")

    # filter table header rows and very short entries
    changes = [c for c in changes if len(c) > 3 and c.lower() not in ("변경 내용", "변경 사항", "작업", "작업 내용")]
    return {"title": title[:72], "changes": changes}


def try_agents(path: Path) -> dict | None:
    """AGENTS.md fallback: use last h3 heading as title, extract - [x] items."""
    if not path or not path.exists():
        return None
    text = path.read_text(encoding="utf-8")

    title = extract_title(text)

    # Get completed checkboxes
    changes = re.findall(r'^\s*-\s*\[[xX]\]\s+(.+)$', text, re.MULTILINE)
    if not changes:
        # try ✅ items (h3 + checkbox)
        changes = re.findall(r'^\s*- \[[xX]\]\s+(.+)$', text, re.MULTILINE)

    return {"title": (title or "Work update")[:72], "changes": changes}


# ── staged change description ────────────────────────────────────

def _git_cached(args: list[str], no_quote: bool = False) -> str:
    cmd = ["git"]
    if no_quote:
        cmd += ["-c", "core.quotepath=false"]
    cmd += ["diff", "--cached"] + args
    r = subprocess.run(
        cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=root(),
    )
    return r.stdout if r.returncode == 0 else ""

def staged_diff_stat() -> str:
    return _git_cached(["--stat"], no_quote=True).strip()

def staged_diff_lines() -> int:
    out = _git_cached(["--numstat"], no_quote=True)
    total = 0
    for line in out.strip().split("\n"):
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) >= 2:
            try:
                total += int(parts[0]) + int(parts[1])
            except ValueError:
                pass
    return total


def staged_diff_content() -> str:
    return _git_cached([], no_quote=True)


def analyze_diff_context(staged: list[str]) -> dict:
    """Analyze staged diff content and classify changes.
       Returns: {"type": str, "summary": str, "additions": int, "deletions": int, "files_changed": int}"""
    diff = staged_diff_content()
    type_counts = {"feat": 0, "fix": 0, "docs": 0, "refactor": 0, "chore": 0}

    # Count added/removed content lines (exclude diff headers +++/---)
    added = len(re.findall(r'^\+[^+]', diff, re.MULTILINE))
    removed = len(re.findall(r'^\-[^-]', diff, re.MULTILINE))

    # Keyword-based type detection from diff content (added lines)
    added_lines = re.findall(r'^\+[^+](.*)', diff, re.MULTILINE)
    added_text = " ".join(added_lines).lower()

    # File-path based classification
    doc_paths = [f for f in staged if f.startswith(("docs/", "AGENTS.md"))]
    code_paths = [f for f in staged if not f.startswith(("docs/", "AGENTS.md"))]

    # Type detection based on file category
    if code_paths:
        code_added = " ".join(added_lines).lower()
        if any(k in code_added for k in ["error", "except", "raise", "bug", "fix ", "hotfix", "fallback"]):
            type_counts["fix"] = 1
        if any(k in code_added for k in ["def ", "class ", "import ", "new ", "add", "feat"]):
            type_counts["feat"] = 1
        if any(k in code_added for k in ["rename", "move", "refactor", "extract", "simplif"]):
            type_counts["refactor"] = 1

    if doc_paths:
        doc_added = " ".join(added_lines).lower()
        if any(k in doc_added for k in ["docs", "readme", "comment", "설명", "주석", "문서", "wiki"]):
            type_counts["docs"] = 1

    # Determine type
    if code_paths and type_counts["fix"] > 0:
        ctype = "fix"
    elif code_paths and type_counts["feat"] > 0:
        ctype = "feat"
    elif code_paths and type_counts["refactor"] > 0:
        ctype = "refactor"
    elif code_paths and doc_paths:
        ctype = "chore"
    elif code_paths and not doc_paths:
        ctype = "chore"
    elif doc_paths and not code_paths:
        ctype = "docs"
    else:
        ctype = "chore"

    # Generate summary from filenames
    summary_parts = []
    for f in staged:
        short = f
        for prefix in ["src/backend/", "src/frontend/", "docs/기타 문서/", "docs/",
                        "wiki/07_Logs/", "wiki/01_Projects/", "scripts/"]:
            if f.startswith(prefix):
                short = f[len(prefix):]
                break
        summary_parts.append(short)

    summary = ", ".join(summary_parts[:4])
    if len(summary_parts) > 4:
        summary += f" +{len(summary_parts) - 4} more"

    return {
        "type": ctype,
        "summary": summary,
        "additions": added,
        "deletions": removed,
        "files_changed": len(staged),
    }


def describe_staged(staged: list[str]) -> str | None:
    if not staged:
        return None
    if len(staged) > 8:
        return None
    context = analyze_diff_context(staged)
    prefix = context["type"]
    title = f"{prefix}: {context['summary'][:60]}"
    return title


# ── auto wiki log ────────────────────────────────────────────────

def write_auto_log(context: dict | None, staged: list[str]) -> Path | None:
    """Write auto-generated log entry to docs/_작업이력/{date}.md and stage it."""
    if not context or not staged:
        return None

    today = date.today().isoformat()
    log_dir = root() / "docs" / "_작업이력"
    log_dir.mkdir(parents=True, exist_ok=True)
    log_file = log_dir / f"{today}.md"
    timestamp = datetime.now().strftime("%H:%M")

    code_files = [f for f in staged if not f.startswith(("docs/", "AGENTS.md"))]
    doc_files = [f for f in staged if f.startswith(("docs/", "AGENTS.md"))]

    # Content-based dedup: hash of sorted staged file paths
    staged_key = "|".join(sorted(staged))
    section_hash = hashlib.sha256(staged_key.encode("utf-8")).hexdigest()[:16]

    section = f"""
## Auto Commit: {timestamp}

### 변경 파일
- type: {context['type']}
- files changed: {context['files_changed']} (code={len(code_files)}, docs={len(doc_files)})
- +{context['additions']} / -{context['deletions']}
- hash: {section_hash}
"""
    if code_files:
        section += "- code:\n"
        section += "".join(f"  - {f}\n" for f in code_files[:8])
        if len(code_files) > 8:
            section += f"  - +{len(code_files) - 8} more\n"
    if doc_files:
        section += "- docs:\n"
        section += "".join(f"  - {f}\n" for f in doc_files[:5])
        if len(doc_files) > 5:
            section += f"  - +{len(doc_files) - 5} more\n"

    if log_file.exists():
        content = log_file.read_text(encoding="utf-8")
        # Dedup by staged file hash, not timestamp — prevents rerun append
        if f"hash: {section_hash}" in content:
            return log_file
        content += "\n" + section.lstrip("\n")
    else:
        content = f"# {today} 작업 로그 (auto-generated)\n" + section.lstrip("\n")

    log_file.write_text(content, encoding="utf-8")
    # Stage the wiki log file
    subprocess.run(
        ["git", "add", str(log_file.relative_to(root()))],
        capture_output=True, cwd=root(),
    )
    print(f"[generate-commit-msg] auto log written to docs/_작업이력/{today}.md", file=sys.stderr)
    return log_file


# ── version sync (AGENTS.md ↔ 작업지시서.md) ─────────────────────

def sync_versions() -> list[str]:
    """Sync version from AGENTS.md (canonical) to 작업지시서.md.
    AGENTS.md header `**버전**: v{ver}` is the single source of truth.
    Fixes AGENTS.md footer if out of sync with header.
    Returns list of file paths that were staged by this function.
    """
    repo = root()
    agents_path = repo / "AGENTS.md"
    work_path = repo / "docs" / "작업지시서.md"
    updated = []

    if not agents_path.exists():
        return updated

    agents_orig = agents_path.read_text(encoding="utf-8")
    m = re.search(r'^\*\*버전\*\*:\s*v([\d.]+)', agents_orig, re.MULTILINE)
    if not m:
        return updated
    ver = m.group(1)

    today_str = date.today().isoformat()

    # Fix AGENTS.md footer only if version in footer != header version
    foot_m = re.search(r'\(v([\d.]+)\)\*', agents_orig)
    if not foot_m or foot_m.group(1) != ver:
        agents_text = re.sub(
            r'^\*updated:.*\(v[\d.]+\)\*',
            f"*updated: {today_str} (v{ver})*",
            agents_orig,
            flags=re.MULTILINE,
        )
        agents_path.write_text(agents_text, encoding="utf-8")
        subprocess.run(["git", "add", "AGENTS.md"], capture_output=True, cwd=repo)
        updated.append("AGENTS.md")
        print(f"[sync_versions] AGENTS.md footer synced to v{ver}", file=sys.stderr)

    # Sync 작업지시서.md
    if not work_path.exists():
        return updated

    work_orig = work_path.read_text(encoding="utf-8")

    # Check if already in sync
    work_ver_m = re.search(r'v([\d.]+)', work_orig)
    if work_ver_m and work_ver_m.group(1) == ver:
        return updated  # already synced

    work_text = re.sub(
        r'^\*\*버전\*\*:.*$',
        f"**버전**: 작업지시서 v{ver}",
        work_orig,
        count=1,
        flags=re.MULTILINE,
    )
    if re.search(r'^\*updated:', work_text, re.MULTILINE):
        work_text = re.sub(
            r'^\*updated:.*$',
            f"*updated: {today_str} (작업지시서 v{ver})*",
            work_text,
            flags=re.MULTILINE,
        )
    else:
        work_text += f"\n*updated: {today_str} (작업지시서 v{ver})*\n"

    work_path.write_text(work_text, encoding="utf-8")
    subprocess.run(["git", "add", "docs/작업지시서.md"], capture_output=True, cwd=repo)
    updated.append("docs/작업지시서.md")
    print(f"[sync_versions] 작업지시서.md synced to v{ver}", file=sys.stderr)

    return updated


# ── main ──────────────────────────────────────────────────────────

def main():
    repo = root()

    # Sync AGENTS.md → 작업지시서.md version before analysis
    sync_versions()

    staged = staged_files()
    context = analyze_diff_context(staged) if staged else None

    # Wiki Agent: generate wiki docs from staged changes (before commit msg build)
    original_staged = staged[:]
    try:
        wiki_agent = repo / "scripts" / "wiki_agent.py"
        if wiki_agent.exists() and staged:
            ctx_json = json.dumps(context) if context else ""
            subprocess.run(
                [sys.executable, str(wiki_agent), "--auto", "--skip-push"],
                capture_output=False, cwd=root(), timeout=15,
            )
    except subprocess.TimeoutExpired:
        print("[generate-commit-msg] wiki_agent timed out (>15s), continuing", file=sys.stderr)
    except Exception as e:
        print(f"[generate-commit-msg] wiki_agent error: {e}", file=sys.stderr)

    # Re-analyze staging after wiki_agent may have added generated docs
    staged = staged_files()
    # If the ONLY new files after wiki_agent are wiki/docs auto-generated,
    # keep the original context to avoid self-referential loop
    new_files = [f for f in staged if f not in original_staged]
    if new_files and all(f.startswith(("docs/", "AGENTS.md")) for f in new_files):
        pass  # wiki_agent generated docs — use updated staged but original context type
    context = analyze_diff_context(staged) if staged else None

    staged_title = describe_staged(staged) if staged else None

    info = try_log(latest_log(repo / "docs" / "_작업이력"))
    if not info:
        info = try_agents(repo / "AGENTS.md")
    if not info:
        info = {"title": "Work update", "changes": []}

    title = (staged_title or info["title"])[:72]
    body = []

    # Diff context summary first
    if context:
        body.append(f"Type: {context['type']} | Files: {context['files_changed']} | +{context['additions']} -{context['deletions']}")

    # Changes from log
    for c in info["changes"][:15]:
        body.append(f"- {c}")

    # staged files: categorize
    if staged:
        doc_files = [f for f in staged if f.startswith("docs/") or f.startswith("AGENTS.md")]
        other_files = [f for f in staged if f not in doc_files]
        parts = []
        if other_files:
            parts.append(f"code({len(other_files)})")
        if doc_files:
            parts.append(f"docs({len(doc_files)})")
        if parts:
            body.append("")
            body.append(f"Staged: {', '.join(parts)}")
            if other_files:
                body.append(f"  {', '.join(other_files[:5])}")
                if len(other_files) > 5:
                    body.append(f"  +{len(other_files) - 5} more")
            if doc_files:
                body.append(f"  docs {len(doc_files)} files")

    # diff stat summary
    stat = staged_diff_stat()
    if stat:
        body.append("")
        body.append(stat)

    msg = title + "\n"
    if body:
        msg += "\n" + "\n".join(body) + "\n"

    out = repo / ".git" / "AUTO_COMMIT_MSG"
    out.write_text(msg, encoding="utf-8")

    # system encoding copy for Windows cmd.exe (cp949) display
    try:
        sys_enc = locale.getpreferredencoding()
        title_file = repo / ".git" / "AUTO_COMMIT_MSG_TITLE"
        # Sanitize title for cmd.exe safe display (remove ! & etc.)
        safe_title = title.replace("!", "_").replace("&", "and")
        # Replace characters not encodable in system encoding (e.g. em dash —)
        safe_title = safe_title.encode(sys_enc, errors="replace").decode(sys_enc)
        title_file.write_text(safe_title + "\n", encoding=sys_enc)
    except Exception:
        pass

    # Auto wiki log (only for --auto workflow, but harmless either way)
    write_auto_log(context, staged)

    print(msg)
    print(f"[generate-commit-msg] written to .git/AUTO_COMMIT_MSG", file=sys.stderr)

    # Log via Universal Log System
    try:
        log_script = root() / "scripts" / "log.py"
        title_safe = title[:40].replace(":", "_").replace("/", "_")
        subprocess.run(
            [sys.executable, str(log_script), f"commit-msg_{title_safe}", "PASSED", "0.0",
             "--desc", f"title={title[:60]}"],
            capture_output=True, timeout=10,
        )
    except Exception:
        pass


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Audit project context across all four layers.

Scans CLAUDE.md files, .claude/rules/ topic files, auto-memory,
project documentation, session files, and public markdown.
Reports sizes, quality scores, project type, footprint, and overlap.

Usage:
    python3 audit_memory.py [repo-path]
    python3 audit_memory.py                # uses current directory
    python3 audit_memory.py --json         # JSON output for programmatic use
"""

import json
import os
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

ROOT_TARGET = 150
SUBDIR_TARGET = 50
RULES_TARGET = 80

SKIP_DIRS = {
    "node_modules", ".git", "dist", "build", ".wrangler",
    ".output", ".vercel", ".cache", "__pycache__", ".venv",
    "vendor", ".next", ".nuxt", ".turbo", ".parcel-cache",
}

# Sections that indicate quality (used for scoring)
COMMAND_PATTERNS = re.compile(
    r"(##\s*(commands?|scripts?|workflow|usage|quick\s*start))",
    re.IGNORECASE,
)
ARCH_PATTERNS = re.compile(
    r"(##\s*(architect|directory|structure|stack|overview|layout))",
    re.IGNORECASE,
)
GOTCHA_PATTERNS = re.compile(
    r"(##\s*(gotcha|caveat|warning|critical|never|important|rules?))",
    re.IGNORECASE,
)

# Well-known project docs
PROJECT_DOC_NAMES = {
    "ARCHITECTURE.md", "DATABASE_SCHEMA.md", "API_ENDPOINTS.md",
    "PROJECT_SPEC.md",
}

# Well-known session files
SESSION_FILE_NAMES = {"SESSION.md", "PROJECT_BRIEF.md"}

# Well-known public files
PUBLIC_MD_NAMES = {"README.md", "CONTRIBUTING.md", "CHANGELOG.md", "LICENSE.md"}

# Project type detection indicators
PROJECT_INDICATORS = {
    "cloudflare-worker": {
        "files": ["wrangler.jsonc", "wrangler.toml"],
        "docs": ["ARCHITECTURE.md"],
    },
    "mcp-server": {
        "content_patterns": [r"FastMCP|McpAgent|mcp.*server"],
        "docs": ["ARCHITECTURE.md", "API_ENDPOINTS.md"],
    },
    "vite-react": {
        "files_glob": ["vite.config.*"],
        "content_check": {"dir": "src", "ext": ".tsx"},
        "docs": ["ARCHITECTURE.md"],
    },
    "vite-app": {
        "files_glob": ["vite.config.*"],
        "docs": ["ARCHITECTURE.md"],
    },
    "nextjs": {
        "files_glob": ["next.config.*"],
        "docs": ["ARCHITECTURE.md"],
    },
    "api-project": {
        "dirs": ["src/routes", "src/api", "app/api"],
        "docs": ["API_ENDPOINTS.md", "DATABASE_SCHEMA.md"],
    },
    "database-project": {
        "files_glob": ["drizzle.config.*", "prisma/schema.prisma"],
        "docs": ["DATABASE_SCHEMA.md"],
    },
    "skills-repo": {
        "dirs": ["skills"],
        "content_check_dir": {"subdir": "skills", "file": "SKILL.md"},
        "docs": [],
    },
    "claude-ops": {
        "dirs": [".claude/agents"],
        "docs": [],
    },
}

# ---------------------------------------------------------------------------
# Core scanning functions
# ---------------------------------------------------------------------------


def count_lines(path: Path) -> int:
    try:
        return len(path.read_text(encoding="utf-8").splitlines())
    except (OSError, UnicodeDecodeError):
        return -1


def file_size(path: Path) -> int:
    """Return file size in bytes."""
    try:
        return path.stat().st_size
    except OSError:
        return 0


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""


def find_claude_md(repo: Path) -> list[Path]:
    """Find all CLAUDE.md files, skipping ignored directories."""
    results = []
    for root, dirs, files in os.walk(repo):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f == "CLAUDE.md":
                results.append(Path(root) / f)
    return sorted(results)


def find_rules(repo: Path) -> list[Path]:
    """Find .claude/rules/ files."""
    rules_dir = repo / ".claude" / "rules"
    if not rules_dir.is_dir():
        return []
    return sorted(rules_dir.glob("*.md"))


def find_auto_memory() -> list[Path]:
    """Find auto-memory MEMORY.md files in ~/.claude/projects/."""
    home = Path.home()
    projects_dir = home / ".claude" / "projects"
    if not projects_dir.is_dir():
        return []
    results = []
    for project_dir in sorted(projects_dir.iterdir()):
        memory_file = project_dir / "memory" / "MEMORY.md"
        if memory_file.is_file():
            results.append(memory_file)
    return results


def find_project_docs(repo: Path) -> list[Path]:
    """Find project documentation files (ARCHITECTURE.md, docs/, etc.)."""
    results = []
    # Check root-level project docs
    for name in PROJECT_DOC_NAMES:
        path = repo / name
        if path.is_file():
            results.append(path)
    # Check docs/ directory
    docs_dir = repo / "docs"
    if docs_dir.is_dir():
        for md in sorted(docs_dir.rglob("*.md")):
            results.append(md)
    return sorted(set(results))


def find_session_files(repo: Path) -> list[Path]:
    """Find session tracking files (SESSION.md, PROJECT_BRIEF.md)."""
    results = []
    for name in SESSION_FILE_NAMES:
        path = repo / name
        if path.is_file():
            results.append(path)
    return sorted(results)


def find_public_md(repo: Path, already_categorised: set[Path]) -> list[Path]:
    """Find public-facing markdown in repo root not already categorised."""
    results = []
    for name in PUBLIC_MD_NAMES:
        path = repo / name
        if path.is_file() and path not in already_categorised:
            results.append(path)
    # Also pick up any other root .md files not yet categorised
    for md in sorted(repo.glob("*.md")):
        if md not in already_categorised and md not in results:
            # Skip CLAUDE.md (handled in memory layer)
            if md.name != "CLAUDE.md":
                results.append(md)
    return sorted(set(results))


def extract_sections(path: Path) -> list[tuple[str, str]]:
    """Extract H2 sections with their content."""
    lines = read_text(path).splitlines()
    sections = []
    current_heading = None
    current_lines = []
    for line in lines:
        if line.startswith("## "):
            if current_heading is not None:
                sections.append((current_heading, "\n".join(current_lines)))
            current_heading = line.lstrip("# ").strip()
            current_lines = []
        elif current_heading is not None:
            current_lines.append(line)
    if current_heading is not None:
        sections.append((current_heading, "\n".join(current_lines)))
    return sections


def find_complex_dirs(repo: Path, existing: set[Path]) -> list[Path]:
    """Find directories that might benefit from a CLAUDE.md."""
    indicators = {
        "wrangler.jsonc", "wrangler.toml", ".env.example",
        "docker-compose.yml", "Dockerfile", "firebase.json",
        "vercel.json", "netlify.toml",
    }
    suggestions = []
    for root, dirs, files in os.walk(repo):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        root_path = Path(root)
        if root_path in existing:
            continue
        if root_path == repo:
            continue
        has_indicator = bool(set(files) & indicators)
        src_count = sum(1 for f in files if f.endswith((".ts", ".tsx", ".py", ".go")))
        if has_indicator or src_count > 10:
            suggestions.append(root_path)
    return sorted(suggestions)


# ---------------------------------------------------------------------------
# Overlap detection
# ---------------------------------------------------------------------------


def normalise_text(text: str) -> str:
    """Normalise text for comparison: lowercase, strip whitespace, remove markdown formatting."""
    text = text.lower()
    text = re.sub(r"[`*_#|>\-]", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def section_overlap(text_a: str, text_b: str) -> float:
    """Calculate word-level overlap between two text blocks. Returns 0.0-1.0."""
    words_a = set(normalise_text(text_a).split())
    words_b = set(normalise_text(text_b).split())
    if not words_a or not words_b:
        return 0.0
    intersection = words_a & words_b
    # Use the smaller set as denominator (Jaccard-like but asymmetric)
    smaller = min(len(words_a), len(words_b))
    return len(intersection) / smaller if smaller > 0 else 0.0


def detect_overlaps(claude_md_path: Path, other_paths: list[Path], repo: Path, threshold: float = 0.5) -> list[dict]:
    """Detect section-level overlap between root CLAUDE.md and other files."""
    claude_sections = extract_sections(claude_md_path)
    if not claude_sections:
        return []

    overlaps = []
    for other_path in other_paths:
        other_sections = extract_sections(other_path)
        if not other_sections:
            continue

        for c_heading, c_content in claude_sections:
            if len(c_content.strip()) < 50:  # Skip tiny sections
                continue
            for o_heading, o_content in other_sections:
                if len(o_content.strip()) < 50:
                    continue
                pct = section_overlap(c_content, o_content)
                if pct >= threshold:
                    overlaps.append({
                        "claude_section": c_heading,
                        "other_file": str(other_path.relative_to(repo)),
                        "other_section": o_heading,
                        "overlap_pct": round(pct * 100),
                    })
    return overlaps


# ---------------------------------------------------------------------------
# Footprint calculation
# ---------------------------------------------------------------------------


def calculate_footprint(
    claude_files: list[Path],
    rules: list[Path],
    project_docs: list[Path],
    session_files: list[Path],
    public_md: list[Path],
    auto_memory: list[Path],
) -> dict:
    """Calculate total markdown footprint by layer."""

    def sum_bytes(paths: list[Path]) -> int:
        return sum(file_size(p) for p in paths)

    memory_bytes = sum_bytes(claude_files) + sum_bytes(rules)
    docs_bytes = sum_bytes(project_docs)
    session_bytes = sum_bytes(session_files)
    public_bytes = sum_bytes(public_md)
    auto_bytes = sum_bytes(auto_memory)
    total = memory_bytes + docs_bytes + session_bytes + public_bytes + auto_bytes
    total_files = len(claude_files) + len(rules) + len(project_docs) + len(session_files) + len(public_md) + len(auto_memory)

    return {
        "total_bytes": total,
        "total_files": total_files,
        "memory_bytes": memory_bytes,
        "project_docs_bytes": docs_bytes,
        "session_bytes": session_bytes,
        "public_bytes": public_bytes,
        "auto_memory_bytes": auto_bytes,
    }


def format_bytes(b: int) -> str:
    """Format bytes as human-readable KB."""
    if b < 1024:
        return f"{b}B"
    return f"{b / 1024:.1f}KB"


# ---------------------------------------------------------------------------
# Project type detection
# ---------------------------------------------------------------------------


def detect_project_type(repo: Path) -> list[dict]:
    """Detect project types from file presence. Returns list of matching types."""
    detected = []

    for type_name, indicators in PROJECT_INDICATORS.items():
        matched = False

        # Check specific files
        if "files" in indicators:
            for f in indicators["files"]:
                if (repo / f).exists():
                    matched = True
                    break

        # Check glob patterns
        if not matched and "files_glob" in indicators:
            for pattern in indicators["files_glob"]:
                if list(repo.glob(pattern)):
                    matched = True
                    break

        # Check directories
        if not matched and "dirs" in indicators:
            for d in indicators["dirs"]:
                if (repo / d).is_dir():
                    matched = True
                    break

        # Content pattern check (e.g. MCP server detection)
        if not matched and "content_patterns" in indicators:
            src_index = repo / "src" / "index.ts"
            if src_index.exists():
                content = read_text(src_index)
                for pattern in indicators["content_patterns"]:
                    if re.search(pattern, content):
                        matched = True
                        break

        # Vite-react needs .tsx files in src/
        if matched and type_name == "vite-react":
            src_dir = repo / "src"
            if not src_dir.is_dir() or not list(src_dir.glob("**/*.tsx")):
                matched = False

        # Vite-app should not match if vite-react already matched
        if type_name == "vite-app" and matched:
            if any(d["type"] == "vite-react" for d in detected):
                matched = False

        # Skills repo needs SKILL.md files inside skills/
        if matched and type_name == "skills-repo":
            skills_dir = repo / "skills"
            if not list(skills_dir.glob("*/SKILL.md")):
                matched = False

        if matched:
            detected.append({
                "type": type_name,
                "docs": indicators.get("docs", []),
            })

    return detected if detected else [{"type": "generic", "docs": []}]


def get_expected_docs(project_types: list[dict]) -> list[str]:
    """Union all expected docs from detected project types."""
    docs = {"CLAUDE.md"}
    for pt in project_types:
        for d in pt.get("docs", []):
            docs.add(d)
    return sorted(docs)


def check_missing_docs(repo: Path, expected: list[str]) -> list[str]:
    """Check which expected docs are missing."""
    missing = []
    for doc in expected:
        # Check root and docs/ directory
        if not (repo / doc).exists() and not (repo / "docs" / doc).exists():
            missing.append(doc)
    return missing


# ---------------------------------------------------------------------------
# Quality scoring
# ---------------------------------------------------------------------------


def score_claude_md(path: Path, repo: Path) -> dict:
    """Score a CLAUDE.md file on 6 criteria (100 points total)."""
    content = read_text(path)
    lines = content.splitlines()
    line_count = len(lines)

    scores = {}

    # 1. Commands/Workflows (20 pts)
    has_commands = bool(COMMAND_PATTERNS.search(content))
    has_code_blocks = content.count("```") >= 2
    has_table = "|" in content and "---" in content
    cmd_score = 0
    if has_commands and has_code_blocks:
        cmd_score = 20
    elif has_commands or has_code_blocks:
        cmd_score = 15 if has_table else 10
    elif has_table:
        cmd_score = 5
    scores["commands"] = cmd_score

    # 2. Architecture Clarity (20 pts)
    has_arch = bool(ARCH_PATTERNS.search(content))
    has_tree = "├" in content or "└" in content
    arch_score = 0
    if has_arch and has_tree:
        arch_score = 20
    elif has_arch:
        arch_score = 15
    elif has_tree:
        arch_score = 10
    scores["architecture"] = arch_score

    # 3. Non-Obvious Patterns (15 pts)
    has_gotchas = bool(GOTCHA_PATTERNS.search(content))
    has_never = "never" in content.lower() or "don't" in content.lower()
    gotcha_score = 0
    if has_gotchas and has_never:
        gotcha_score = 15
    elif has_gotchas or has_never:
        gotcha_score = 10
    scores["patterns"] = gotcha_score

    # 4. Conciseness (15 pts)
    is_root = path.parent == repo
    target = ROOT_TARGET if is_root else SUBDIR_TARGET
    ratio = line_count / target if target > 0 else 2.0
    if 0.3 <= ratio <= 1.0:
        concise_score = 15
    elif ratio <= 1.5:
        concise_score = 10
    elif ratio <= 2.0:
        concise_score = 5
    else:
        concise_score = 0
    scores["conciseness"] = concise_score

    # 5. Currency (15 pts) — check for stale references
    stale_refs = check_staleness(path, repo)
    if not stale_refs:
        currency_score = 15
    elif len(stale_refs) <= 2:
        currency_score = 10
    elif len(stale_refs) <= 5:
        currency_score = 5
    else:
        currency_score = 0
    scores["currency"] = currency_score

    # 6. Actionability (15 pts)
    has_inline_code = "`" in content
    actionability_score = 0
    if has_code_blocks and has_inline_code and has_table:
        actionability_score = 15
    elif has_code_blocks and has_inline_code:
        actionability_score = 10
    elif has_inline_code:
        actionability_score = 5
    scores["actionability"] = actionability_score

    total = sum(scores.values())
    grade = (
        "A" if total >= 90 else
        "B" if total >= 70 else
        "C" if total >= 50 else
        "D" if total >= 30 else
        "F"
    )

    return {
        "scores": scores,
        "total": total,
        "grade": grade,
        "stale_refs": stale_refs,
    }


# ---------------------------------------------------------------------------
# Staleness detection
# ---------------------------------------------------------------------------


def check_staleness(path: Path, repo: Path) -> list[str]:
    """Check for references to non-existent files/directories."""
    content = read_text(path)
    stale = []

    # Find file path references (backticked paths, markdown links)
    path_patterns = [
        r"`([a-zA-Z0-9_./-]+\.[a-zA-Z]{1,5})`",  # `path/to/file.ext`
        r"\[.*?\]\(([a-zA-Z0-9_./-]+\.[a-zA-Z]{1,5})\)",  # [text](path)
        r"`([a-zA-Z0-9_/-]+/)`",  # `path/to/dir/`
    ]

    checked = set()
    for pattern in path_patterns:
        for match in re.finditer(pattern, content):
            ref = match.group(1).rstrip("/")
            if ref in checked:
                continue
            checked.add(ref)

            # Skip URLs, commands, common patterns
            if ref.startswith(("http", "//", "npm ", "git ", "$")):
                continue
            if ref.startswith(("*.", "**/")):
                continue
            # Skip short refs that are likely code, not file paths
            if "/" not in ref and not ref.startswith("."):
                continue

            # Check relative to the file's directory and repo root
            ref_path = Path(ref)
            candidates = [
                path.parent / ref_path,
                repo / ref_path,
            ]
            if not any(c.exists() for c in candidates):
                stale.append(ref)

    return stale


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------


def print_header(text: str) -> None:
    print(f"\n{'=' * 60}")
    print(f"  {text}")
    print(f"{'=' * 60}\n")


def main():
    json_output = "--json" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--json"]
    repo = Path(args[0] if args else ".").resolve()

    if not repo.is_dir():
        print(f"Error: {repo} is not a directory", file=sys.stderr)
        sys.exit(1)

    report = {
        "repo": str(repo),
        "project_types": [],
        "claude_md_files": [],
        "rules_files": [],
        "auto_memory_files": [],
        "project_docs": [],
        "session_files": [],
        "public_md": [],
        "missing_docs": [],
        "suggestions": [],
        "footprint": {},
        "overlaps": [],
        "summary": {},
    }

    # --- Project Type Detection ---
    project_types = detect_project_type(repo)
    report["project_types"] = [pt["type"] for pt in project_types]
    expected_docs = get_expected_docs(project_types)
    missing_docs = check_missing_docs(repo, expected_docs)
    report["missing_docs"] = missing_docs

    if not json_output:
        print(f"Auditing: {repo}\n")
        type_names = ", ".join(pt["type"] for pt in project_types)
        print(f"Project type(s): {type_names}")
        print(f"Expected docs: {', '.join(expected_docs)}")
        if missing_docs:
            print(f"Missing docs: {', '.join(missing_docs)}")
        else:
            print("Missing docs: none")

    # --- Layer 1: CLAUDE.md Files ---
    claude_files = find_claude_md(repo)
    existing_dirs = {f.parent for f in claude_files}

    if not json_output:
        print_header("Layer 1: CLAUDE.md Hierarchy")

    if not claude_files:
        if not json_output:
            print("  No CLAUDE.md files found.\n")
    else:
        if not json_output:
            print(f"  Found {len(claude_files)} file(s):\n")

        for f in claude_files:
            lines = count_lines(f)
            rel = str(f.relative_to(repo))
            is_root = f.parent == repo
            target = ROOT_TARGET if is_root else SUBDIR_TARGET
            status = "OK" if lines <= target else "OVER"
            quality = score_claude_md(f, repo)

            file_info = {
                "path": rel,
                "lines": lines,
                "target": target,
                "status": status,
                "quality": quality,
            }
            report["claude_md_files"].append(file_info)

            if not json_output:
                marker = f" <<< +{lines - target} over" if status == "OVER" else ""
                print(f"  {rel}: {lines} lines (target: {target}){marker}")
                print(f"    Score: {quality['total']}/100 ({quality['grade']})")
                scores = quality["scores"]
                parts = [f"{k}={v}" for k, v in scores.items()]
                print(f"    [{', '.join(parts)}]")
                if quality["stale_refs"]:
                    print(f"    Stale refs: {', '.join(quality['stale_refs'])}")
                print()

    # --- Layer 2: Rules Files ---
    rules = find_rules(repo)

    if not json_output:
        print_header("Layer 2: .claude/rules/")

    if rules:
        if not json_output:
            print(f"  Found {len(rules)} rule file(s):\n")
        for r in rules:
            lines = count_lines(r)
            status = "OVER" if lines > RULES_TARGET else "OK"
            file_info = {
                "path": f".claude/rules/{r.name}",
                "lines": lines,
                "target": RULES_TARGET,
                "status": status,
            }
            report["rules_files"].append(file_info)
            if not json_output:
                marker = f" <<< +{lines - RULES_TARGET} over" if status == "OVER" else ""
                print(f"  {r.name}: {lines} lines{marker}")
    else:
        if not json_output:
            print("  No .claude/rules/ directory found.")

    # --- Layer 3: Auto-Memory ---
    auto_memory = find_auto_memory()

    if not json_output:
        print_header("Layer 3: Auto-Memory")

    if auto_memory:
        if not json_output:
            print(f"  Found {len(auto_memory)} auto-memory file(s):\n")
        for m in auto_memory:
            lines = count_lines(m)
            # Extract project name from directory
            project_name = m.parent.parent.name
            file_info = {
                "path": str(m),
                "project": project_name,
                "lines": lines,
                "empty": lines <= 1,
            }
            report["auto_memory_files"].append(file_info)
            if not json_output:
                empty_note = " (empty)" if lines <= 1 else ""
                print(f"  {project_name}: {lines} lines{empty_note}")
    else:
        if not json_output:
            print("  No auto-memory files found.")

    # --- Layer 4: Project Documentation ---
    project_docs = find_project_docs(repo)
    # Track all categorised paths for public_md exclusion
    categorised = set(claude_files) | set(rules) | set(project_docs)

    if not json_output:
        print_header("Layer 4: Project Documentation")

    if project_docs:
        if not json_output:
            print(f"  Found {len(project_docs)} doc file(s):\n")
        for d in project_docs:
            lines = count_lines(d)
            rel = str(d.relative_to(repo))
            stale_refs = check_staleness(d, repo)
            file_info = {
                "path": rel,
                "lines": lines,
                "bytes": file_size(d),
                "stale_refs": stale_refs,
            }
            report["project_docs"].append(file_info)
            if not json_output:
                stale_note = f" ({len(stale_refs)} stale refs)" if stale_refs else ""
                print(f"  {rel}: {lines} lines ({format_bytes(file_size(d))}){stale_note}")
    else:
        if not json_output:
            print("  No project documentation found.")

    # --- Session Files ---
    session_files = find_session_files(repo)
    categorised.update(session_files)

    if not json_output:
        print_header("Session Files")

    if session_files:
        for s in session_files:
            lines = count_lines(s)
            rel = str(s.relative_to(repo))
            file_info = {
                "path": rel,
                "lines": lines,
                "bytes": file_size(s),
            }
            report["session_files"].append(file_info)
            if not json_output:
                print(f"  {rel}: {lines} lines ({format_bytes(file_size(s))})")
    else:
        if not json_output:
            print("  No session files found.")

    # --- Public Markdown ---
    public_md = find_public_md(repo, categorised)
    categorised.update(public_md)

    if not json_output:
        print_header("Public Markdown")

    if public_md:
        for p in public_md:
            lines = count_lines(p)
            rel = str(p.relative_to(repo))
            file_info = {
                "path": rel,
                "lines": lines,
                "bytes": file_size(p),
            }
            report["public_md"].append(file_info)
            if not json_output:
                print(f"  {rel}: {lines} lines ({format_bytes(file_size(p))})")
    else:
        if not json_output:
            print("  No public markdown files found.")

    # --- Overlap Detection ---
    root_claude = repo / "CLAUDE.md"
    overlaps = []
    if root_claude.is_file():
        # Compare root CLAUDE.md against project docs and public md
        compare_targets = project_docs + public_md
        overlaps = detect_overlaps(root_claude, compare_targets, repo)
    report["overlaps"] = overlaps

    if not json_output and overlaps:
        print_header("Overlap Warnings")
        for o in overlaps:
            print(f"  CLAUDE.md § {o['claude_section']} ↔ {o['other_file']} § {o['other_section']} ({o['overlap_pct']}% overlap)")

    # --- Suggestions ---
    suggestions = find_complex_dirs(repo, existing_dirs)
    report["suggestions"] = [str(s.relative_to(repo)) for s in suggestions]

    if suggestions and not json_output:
        print_header("Suggestions")
        print(f"  {len(suggestions)} director(ies) could benefit from a CLAUDE.md:\n")
        for s in suggestions:
            print(f"  {s.relative_to(repo)}/CLAUDE.md")

    # --- Footprint ---
    footprint = calculate_footprint(claude_files, rules, project_docs, session_files, public_md, auto_memory)
    report["footprint"] = footprint

    if not json_output:
        print_header("Markdown Footprint")
        print(f"  Total: {format_bytes(footprint['total_bytes'])} across {footprint['total_files']} files")
        print(f"    Memory:       {format_bytes(footprint['memory_bytes'])}  (CLAUDE.md + {len(rules)} rules)")
        print(f"    Project docs: {format_bytes(footprint['project_docs_bytes'])}  ({len(project_docs)} files)")
        print(f"    Session:      {format_bytes(footprint['session_bytes'])}  ({len(session_files)} files)")
        print(f"    Public:       {format_bytes(footprint['public_bytes'])}  ({len(public_md)} files)")
        if auto_memory:
            print(f"    Auto-memory:  {format_bytes(footprint['auto_memory_bytes'])}  ({len(auto_memory)} files)")

    # --- Summary ---
    total_claude_lines = sum(count_lines(f) for f in claude_files)
    total_rules_lines = sum(count_lines(r) for r in rules)
    oversized_count = sum(
        1 for f in report["claude_md_files"] if f["status"] == "OVER"
    )
    avg_score = 0
    if report["claude_md_files"]:
        avg_score = round(
            sum(f["quality"]["total"] for f in report["claude_md_files"])
            / len(report["claude_md_files"])
        )

    report["summary"] = {
        "claude_md_count": len(claude_files),
        "claude_md_total_lines": total_claude_lines,
        "claude_md_oversized": oversized_count,
        "claude_md_avg_score": avg_score,
        "rules_count": len(rules),
        "rules_total_lines": total_rules_lines,
        "auto_memory_count": len(auto_memory),
        "project_docs_count": len(project_docs),
        "session_files_count": len(session_files),
        "public_md_count": len(public_md),
        "overlap_count": len(overlaps),
        "missing_docs": len(missing_docs),
        "suggestion_count": len(suggestions),
        "total_footprint_bytes": footprint["total_bytes"],
    }

    if not json_output:
        print_header("Summary")
        print(f"  CLAUDE.md files: {len(claude_files)} ({total_claude_lines} lines, {oversized_count} oversized)")
        print(f"  Average quality: {avg_score}/100")
        print(f"  Rules files: {len(rules)} ({total_rules_lines} lines)")
        print(f"  Auto-memory files: {len(auto_memory)}")
        print(f"  Project docs: {len(project_docs)}")
        print(f"  Session files: {len(session_files)}")
        print(f"  Public markdown: {len(public_md)}")
        print(f"  Overlaps: {len(overlaps)}")
        print(f"  Missing docs: {len(missing_docs)}")
        print(f"  Suggested additions: {len(suggestions)}")
        print(f"  Total footprint: {format_bytes(footprint['total_bytes'])}")
    else:
        print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()

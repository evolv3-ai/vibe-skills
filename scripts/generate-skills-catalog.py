#!/usr/bin/env python3
"""
Generate SKILLS_CATALOG.md from skill directories.

Scans skills/ directory, extracts YAML frontmatter from SKILL.md files,
categorizes skills, and generates a formatted markdown catalog.

Usage:
    python scripts/generate-skills-catalog.py
    python scripts/generate-skills-catalog.py --dry-run  # Preview without writing
"""

import os
import re
import sys
from pathlib import Path
from datetime import date

# Category definitions - skills are assigned based on name patterns
# Order matters: first match wins
CATEGORY_PATTERNS = {
    "Cloudflare Platform": [
        r"^cloudflare-",
        r"^drizzle-orm-d1$",  # D1-specific ORM
    ],
    "AI & Machine Learning": [
        r"^ai-sdk-",
        r"^openai-",
        r"^claude-",
        r"^google-gemini",
        r"^workers-ai$",
        r"^thesys-",  # Generative UI
        r"^elevenlabs-",  # Voice AI
    ],
    "Frontend & UI": [
        r"^tailwind-",
        r"^react-(?!native)",  # React but not react-native
        r"^tanstack-",
        r"^nextjs$",
        r"^hono-",
        r"^zustand-",
        r"^auto-animate$",
        r"^motion$",
        r"^tiptap$",
        r"^responsive-images$",
        r"^accessibility$",
    ],
    "Authentication": [
        r"^clerk-",
        r"^better-auth$",
        r"^azure-auth$",
        r"^oauth-",
        r"^firebase-auth$",
    ],
    "Database & Storage": [
        r"^drizzle-(?!orm-d1)",  # Drizzle except d1-specific
        r"^neon-",
        r"^vercel-kv$",
        r"^vercel-blob$",
        r"^firebase-firestore$",
        r"^firebase-storage$",
        r"^snowflake-",
    ],
    "Content Management": [
        r"^tinacms$",
        r"^sveltia-",
        r"^wordpress-",
    ],
    "MCP & Tooling": [
        r"^typescript-mcp$",
        r"^fastmcp$",
        r"^ts-agent-sdk$",
        r"^mcp-",
    ],
    "Planning & Workflow": [
        r"^project-",
        r"^docs-workflow$",
        r"^skill-",
        r"^sub-agent-",
    ],
    "Google Cloud & Workspace": [
        r"^google-",
        r"^django-cloud-sql",
        r"^streamlit-snowflake$",
    ],
    "Desktop & Mobile": [
        r"^electron-",
        r"^react-native-",
    ],
    "Python": [
        r"^fastapi$",
        r"^flask$",
    ],
    "Utilities": [
        r"^color-palette$",
        r"^favicon-",
        r"^icon-",
        r"^image-",
        r"^seo-",
        r"^email-gateway$",
        r"^firecrawl-",
        r"^playwright-",
        r"^office$",
        r"^jquery-",
        r"^open-source-",
    ],
    "Developer Workflow": [
        r"^agent-development$",
        r"^developer-toolbox$",
        r"^deep-debug$",
    ],
}

# Fallback category for unmatched skills
DEFAULT_CATEGORY = "Other"


def parse_yaml_frontmatter(content: str) -> dict:
    """Extract YAML frontmatter from markdown content."""
    if not content.startswith("---"):
        return {}

    # Find closing ---
    end_match = re.search(r'\n---\s*\n', content[3:])
    if not end_match:
        return {}

    yaml_content = content[3:end_match.start() + 3]

    # Simple YAML parsing (handles our specific format)
    result = {}
    current_key = None
    current_value = []

    for line in yaml_content.split('\n'):
        # Check for key: value or key: |
        key_match = re.match(r'^(\w[\w-]*?):\s*(.*?)$', line)
        if key_match:
            # Save previous key if exists
            if current_key:
                result[current_key] = '\n'.join(current_value).strip()

            current_key = key_match.group(1)
            value = key_match.group(2)

            if value == '|' or value == '>':
                current_value = []
            else:
                current_value = [value]
        elif current_key and line.startswith('  '):
            # Continuation of multi-line value
            current_value.append(line.strip())

    # Save last key
    if current_key:
        result[current_key] = '\n'.join(current_value).strip()

    return result


def extract_error_count(description: str) -> int:
    """Extract 'Prevents X errors' count from description."""
    match = re.search(r'[Pp]revents?\s+(\d+)\s+(?:documented\s+)?errors?', description)
    if match:
        return int(match.group(1))
    return 0


def extract_triggers(content: str) -> list[str]:
    """Extract trigger keywords from SKILL.md README section or separate README.md."""
    # Look for Keywords section
    keywords_match = re.search(
        r'##\s*(?:Keywords|Triggers|Auto-Trigger Keywords)\s*\n+(.*?)(?=\n##|\n---|\Z)',
        content,
        re.IGNORECASE | re.DOTALL
    )
    if keywords_match:
        text = keywords_match.group(1)
        # Extract items from backticks, quotes, or list items
        # Match: `keyword`, "keyword", or - keyword
        items = re.findall(r'`([^`]+)`|"([^"]+)"|-\s*([^\n,`"]+)', text)
        triggers = []
        for match in items:
            # Get whichever group matched
            t = match[0] or match[1] or match[2]
            if t:
                t = t.strip()
                # Skip metadata-like entries
                if t and not t.startswith('*') and len(t) < 50:
                    triggers.append(t)
        return triggers[:4]  # Limit to 4 triggers for cleaner output
    return []


def categorize_skill(skill_name: str) -> str:
    """Determine category for a skill based on name patterns."""
    for category, patterns in CATEGORY_PATTERNS.items():
        for pattern in patterns:
            if re.match(pattern, skill_name):
                return category
    return DEFAULT_CATEGORY


def scan_skills(skills_dir: Path) -> list[dict]:
    """Scan skills directory and extract metadata from each skill."""
    skills = []

    for skill_path in sorted(skills_dir.iterdir()):
        if not skill_path.is_dir():
            continue

        skill_md = skill_path / "SKILL.md"
        if not skill_md.exists():
            print(f"Warning: No SKILL.md in {skill_path.name}", file=sys.stderr)
            continue

        content = skill_md.read_text()
        frontmatter = parse_yaml_frontmatter(content)

        if not frontmatter.get('name'):
            print(f"Warning: No name in frontmatter for {skill_path.name}", file=sys.stderr)
            continue

        name = frontmatter['name']
        description = frontmatter.get('description', '')

        # Also check README.md for triggers
        readme_path = skill_path / "README.md"
        readme_content = ""
        if readme_path.exists():
            readme_content = readme_path.read_text()

        triggers = extract_triggers(content) or extract_triggers(readme_content)

        # Use directory name for categorization (more reliable than frontmatter name)
        dir_name = skill_path.name

        skills.append({
            'name': name,
            'dir_name': dir_name,
            'description': description.split('\n')[0][:200],  # First line, max 200 chars
            'full_description': description,
            'error_count': extract_error_count(description),
            'triggers': triggers,
            'category': categorize_skill(dir_name),  # Use dir_name for categorization
            'user_invocable': frontmatter.get('user-invocable', 'false').lower() == 'true',
        })

    return skills


def generate_catalog(skills: list[dict]) -> str:
    """Generate markdown catalog content."""
    # Group by category
    categories = {}
    for skill in skills:
        cat = skill['category']
        if cat not in categories:
            categories[cat] = []
        categories[cat].append(skill)

    # Calculate totals
    total_skills = len(skills)
    total_errors = sum(s['error_count'] for s in skills)

    lines = [
        "# Skills Catalog",
        "",
        f"**{total_skills} production-ready skills** organized by category.",
        "",
        f"Total errors prevented: **{total_errors}+**",
        "",
        f"*Auto-generated on {date.today().isoformat()} by `scripts/generate-skills-catalog.py`*",
        "",
        "---",
        "",
        "## Quick Navigation",
        "",
    ]

    # Table of contents
    for cat in CATEGORY_PATTERNS.keys():
        if cat in categories:
            count = len(categories[cat])
            anchor = cat.lower().replace(' ', '-').replace('&', '').replace('  ', '-')
            lines.append(f"- [{cat}](#{anchor}) ({count} skills)")

    # Add Other category if exists
    if DEFAULT_CATEGORY in categories:
        count = len(categories[DEFAULT_CATEGORY])
        lines.append(f"- [{DEFAULT_CATEGORY}](#other) ({count} skills)")

    lines.extend(["", "---", ""])

    # Generate each category
    for cat in list(CATEGORY_PATTERNS.keys()) + [DEFAULT_CATEGORY]:
        if cat not in categories:
            continue

        cat_skills = categories[cat]
        lines.extend([
            f"## {cat} ({len(cat_skills)} skills)",
            "",
        ])

        for skill in sorted(cat_skills, key=lambda s: s['name']):
            # Skill header
            lines.append(f"### {skill['name']}")

            # Description (first sentence/line)
            desc = skill['description']
            if desc:
                # Clean up description - extract the main part
                desc_clean = re.sub(r'\s*[Pp]revents?\s+\d+.*$', '', desc).strip()
                if desc_clean:
                    lines.append(desc_clean)

            # Error count
            if skill['error_count'] > 0:
                lines.append(f"**Prevents {skill['error_count']} errors.**")

            # Triggers
            if skill['triggers']:
                trigger_str = ', '.join(f'`{t}`' for t in skill['triggers'][:4])
                lines.append(f"")
                lines.append(f"**Triggers**: {trigger_str}")

            lines.extend(["", "---", ""])

    return '\n'.join(lines)


def main():
    dry_run = '--dry-run' in sys.argv

    # Find repository root
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent
    skills_dir = repo_root / "skills"
    output_file = repo_root / "docs" / "SKILLS_CATALOG.md"

    if not skills_dir.exists():
        print(f"Error: Skills directory not found: {skills_dir}", file=sys.stderr)
        sys.exit(1)

    print(f"Scanning {skills_dir}...", file=sys.stderr)
    skills = scan_skills(skills_dir)
    print(f"Found {len(skills)} skills", file=sys.stderr)

    catalog = generate_catalog(skills)

    if dry_run:
        print("\n--- DRY RUN OUTPUT ---\n")
        print(catalog)
        print(f"\n--- Would write to {output_file} ---")
    else:
        output_file.write_text(catalog)
        print(f"Wrote {output_file}", file=sys.stderr)

        # Print summary
        categories = {}
        for skill in skills:
            cat = skill['category']
            categories[cat] = categories.get(cat, 0) + 1

        print("\nCategory breakdown:", file=sys.stderr)
        for cat, count in sorted(categories.items(), key=lambda x: -x[1]):
            print(f"  {cat}: {count}", file=sys.stderr)


if __name__ == "__main__":
    main()

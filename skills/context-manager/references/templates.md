# Templates

Reference templates for CLAUDE.md files, rules topic files, and sub-directory context. Use these when creating new files or restructuring existing ones.

## Root CLAUDE.md (Minimal)

For simple projects with a single developer:

```markdown
# [Project Name]

[One-line description]

## Stack

[Tech stack summary]

## Commands

| Command | Purpose |
|---------|---------|
| `npm run dev` | Start dev server |
| `npm run build` | Production build |
| `npm run deploy` | Deploy to [platform] |

## Gotchas

- [Non-obvious thing 1]
- [Non-obvious thing 2]
```

Target: 30-60 lines.

## Root CLAUDE.md (Comprehensive)

For projects with external integrations, multiple contributors, or complex workflows:

```markdown
# [Project Name]

**Repository**: [URL]
**Owner**: [Name]

[One-line description]

## Stack

[Tech stack with key decisions noted]

## Directory Structure

[Annotated tree of key directories]

## Commands

| Command | Purpose |
|---------|---------|
| `npm run dev` | Start dev server |
| `npm run build` | Production build |
| `npm run deploy` | Deploy to [platform] |
| `npm test` | Run test suite |

## Key Files

| File | Purpose |
|------|---------|
| `src/index.ts` | Entry point |
| `wrangler.jsonc` | Cloudflare config |

## Critical Rules

- [Never do X because Y]
- [Always do A before B]

## Gotchas

- [Non-obvious thing 1]
- [Non-obvious thing 2]
```

Target: 60-150 lines.

## Sub-Directory CLAUDE.md

For directories with external integrations, non-obvious config, or common gotchas:

```markdown
# [Component Name]

## Key Integrations

- **[Service]**: [endpoint], [auth method], [secret location]

## Commands

[Directory-specific commands if different from root]

## Gotchas

- [Non-obvious thing specific to this directory]
```

Target: 15-50 lines.

**Don't create when**: parent CLAUDE.md covers it, directory is self-explanatory, content would be under 10 lines.

## Rules Topic File (.claude/rules/*.md)

For correction rules, patterns, and technical facts that apply across projects:

```markdown
# [Topic Name]

## [Pattern/Rule Category]

| If Claude suggests... | Use instead... |
|----------------------|----------------|
| [Wrong pattern] | [Correct pattern] |

[Code example if helpful]

**Last Updated**: [date]
```

Target: 20-80 lines per topic file.

## Section Placement Guide

| Content Type | Where It Goes |
|-------------|---------------|
| Project name, owner, purpose | Root CLAUDE.md |
| Tech stack, architecture overview | Root CLAUDE.md |
| Build/deploy/test commands | Root CLAUDE.md |
| Critical "never do X" rules | Root CLAUDE.md |
| Directory structure | Root CLAUDE.md |
| External service integrations | Sub-directory CLAUDE.md (near the code that uses them) |
| Directory-specific gotchas | Sub-directory CLAUDE.md |
| Correction rules (training cutoff) | `.claude/rules/<topic>.md` |
| Coding patterns for this project | `.claude/rules/<topic>.md` or root CLAUDE.md |
| Session-specific discoveries | Auto-memory (managed by Claude Code, not this skill) |

## Anti-Patterns

- Verbose explanations of standard tools or frameworks
- Changelogs or version history (use git)
- Content Claude already knows from training
- Duplicating parent CLAUDE.md content in child files
- Generic best practices not specific to the project
- Empty template sections with placeholder text

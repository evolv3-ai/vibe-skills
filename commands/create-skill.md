# Create Skill

You are creating a new Claude Code skill from the standard template.

## Command Usage

`/create-skill <skill-name>`

Example: `/create-skill cloudflare-analytics`

## Validation

**Skill name requirements:**
- Lowercase letters, digits, and hyphens only
- Must start with a letter
- Max 40 characters
- No underscores or spaces

If name is invalid, explain why and suggest a corrected version.

## Process

### 1. Check if skill exists

```bash
ls skills/<skill-name>/
```

If exists, ask user: "Skill `<skill-name>` already exists. Overwrite? [y/N]"

### 2. Ask about skill type (interactive)

Present options to customize the template:

```
What type of skill is this?

1. **Cloudflare** - Workers, D1, R2, KV, AI, etc.
2. **AI/ML** - OpenAI, Anthropic, Gemini, AI SDK
3. **Frontend** - React, UI libraries, styling
4. **Auth** - Authentication providers
5. **Database** - ORMs, data stores
6. **Tooling** - CLI tools, build systems, MCPs
7. **Generic** - Standard template (no customization)

Your choice [1-7]:
```

### 3. Create skill directory structure

```bash
# Copy skeleton
cp -r templates/skill-skeleton/ skills/<skill-name>/
```

### 4. Auto-populate fields in SKILL.md

Replace these automatically:
- `name:` → the skill name provided
- `Last Updated` → today's date (YYYY-MM-DD)
- `Verified` date → today's date

### 5. Apply type-specific customizations

Based on skill type choice, provide guidance:

**Cloudflare skills:**
- Remind to check cloudflare-docs MCP for accuracy
- Suggest prerequisite: `cloudflare-worker-base`
- Add wrangler.jsonc to Configuration section
- Reference: `skills/cloudflare-d1/` as example

**AI/ML skills:**
- Remind to verify model names/versions are current
- Add model configuration patterns
- Include rate limiting considerations
- Reference: `skills/ai-sdk-core/` as example

**Frontend skills:**
- Add component patterns section
- Include TypeScript types
- Reference: `skills/tailwind-v4-shadcn/` as example

**Auth skills:**
- Security considerations section
- Token handling patterns
- Reference: `skills/clerk-auth/` as example

**Database skills:**
- Schema patterns section
- Migration workflow
- Reference: `skills/drizzle-orm-d1/` as example

**Tooling skills:**
- CLI usage patterns
- Integration examples
- Reference: `skills/fastmcp/` as example

### 6. Create README.md with auto-trigger keywords

The README.md should include:
```markdown
# <Skill Name>

Auto-trigger keywords: <technology>, <use-case>, <common-errors>

See SKILL.md for full documentation.
```

### 7. Run metadata check

```bash
./scripts/check-metadata.sh <skill-name>
```

Report any issues found.

### 8. Install the skill

```bash
./scripts/install-skill.sh <skill-name>
```

## Output

After creating:

```markdown
## Skill Created: `<skill-name>`

**Location**: `skills/<skill-name>/`
**Type**: [Selected type]
**Installed**: ~/.claude/skills/<skill-name> → skills/<skill-name>

### Files Created:
- `SKILL.md` - Main documentation (fill [TODO] markers)
- `README.md` - Auto-trigger keywords
- `scripts/` - Helper scripts
- `references/` - Documentation files
- `assets/` - Templates, images

### Next Steps:

1. **Fill TODOs** - Search for `[TODO:` in SKILL.md and replace all
2. **Add content** - Write the actual skill knowledge
3. **Test discovery** - Ask Claude Code to use your skill
4. **Verify** - Run `./scripts/check-metadata.sh <skill-name>`
5. **Commit** - `git add skills/<skill-name> && git commit -m "Add <skill-name> skill"`

### Reference Examples:
- Similar skill: `skills/[reference-skill]/`
- Template guide: `templates/SKILL-TEMPLATE.md`
- Checklist: `ONE_PAGE_CHECKLIST.md`

### Quick Test:
Ask Claude Code: "Use the <skill-name> skill to..."
```

## Important Notes

- Skills are symlinked to `~/.claude/skills/` for Claude Code to discover
- The [TODO] markers in SKILL.md are intentional - fill them all before committing
- Description should be 250-350 characters (max 1024) with "Use when:" scenarios
- Include keywords IN the description text (NOT in metadata - metadata field is not recognized)
- ONLY valid frontmatter fields: `name`, `description`, `allowed-tools`
- Do NOT use `license:` or `metadata:` - they break skill discovery
- Test with `check-metadata.sh` before committing

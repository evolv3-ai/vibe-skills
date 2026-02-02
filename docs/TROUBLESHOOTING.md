# Troubleshooting Guide

Solutions to common issues when using Claude Code skills.

**Last Updated**: 2026-02-02

---

## Quick Fixes

Most issues are solved by one of these:

| Issue | Quick Fix |
|-------|-----------|
| Skill not found | Restart Claude Code |
| Changes not appearing | Reinstall + restart |
| Marketplace errors | Remove and re-add marketplace |
| YAML errors | Check frontmatter syntax |

---

## Skill Discovery Issues

### "Claude doesn't suggest my skill"

**Symptoms:**
- You ask about a topic your skill covers
- Claude doesn't mention or suggest the skill
- Skill works when explicitly invoked

**Causes & Solutions:**

1. **Skill not installed**
   ```bash
   /plugin list
   # If not listed, install it:
   /plugin install ./skills/my-skill
   ```

2. **Claude Code not restarted**
   ```bash
   exit
   claude
   ```

3. **Missing or invalid YAML frontmatter**

   Check `skills/my-skill/SKILL.md` starts with:
   ```yaml
   ---
   name: my-skill
   description: |
     Brief description of what this skill does.
     Use when: [specific scenarios].
   ---
   ```

   Common YAML errors:
   - Missing `---` markers
   - Indentation issues (use 2 spaces, not tabs)
   - Special characters not quoted

4. **Missing trigger keywords in README.md**

   Check `skills/my-skill/README.md` has a Keywords section:
   ```markdown
   ## Keywords

   `my-technology`, `my-use-case`, `related-term`
   ```

5. **Description too vague**

   Claude uses the description to match user requests. Include:
   - Technology names explicitly
   - "Use when:" scenarios
   - Common error messages the skill prevents

### "Skill used to work but stopped"

**Causes & Solutions:**

1. **Plugin cache corrupted**
   ```bash
   /plugin marketplace remove jezweb-skills
   /plugin marketplace add jezweb/claude-skills
   /plugin install cloudflare@jezweb-skills
   exit
   claude
   ```

2. **Skill was updated with breaking changes**
   ```bash
   # Pull latest
   cd ~/Documents/claude-skills
   git pull

   # Reinstall
   /plugin install ./skills/my-skill
   exit
   claude
   ```

---

## Installation Issues

### "Marketplace not found"

**Error:** `Marketplace 'jezweb-skills' not found`

**Solution:**
```bash
# Re-add the marketplace
/plugin marketplace add jezweb/claude-skills

# Or use full URL
/plugin marketplace add https://github.com/jezweb/claude-skills
```

### "Plugin installation failed"

**Causes & Solutions:**

1. **Network issue**
   ```bash
   # Check you can reach GitHub
   curl -I https://github.com/jezweb/claude-skills

   # Retry installation
   /plugin install cloudflare@jezweb-skills
   ```

2. **Invalid plugin name**
   ```bash
   # List available plugins
   /plugin marketplace list jezweb-skills

   # Use correct name
   /plugin install cloudflare@jezweb-skills  # Not "cloudflare-skills"
   ```

3. **Local path issues**
   ```bash
   # Use relative path from current directory
   /plugin install ./skills/my-skill

   # Or absolute path
   /plugin install /home/user/claude-skills/skills/my-skill
   ```

### "Permission denied" during installation

**Solution:**
```bash
# Check directory permissions
ls -la ~/.claude/plugins/

# Fix if needed
chmod -R u+rw ~/.claude/plugins/
```

---

## Template Issues

### "Template doesn't work"

**Symptoms:**
- Code from skill templates has errors
- Imports don't resolve
- Types are wrong

**Causes & Solutions:**

1. **Outdated package versions**

   Check your `package.json` matches versions in the skill:
   ```bash
   # See what versions the skill recommends
   grep -A5 "Latest Versions" skills/cloudflare-worker-base/SKILL.md

   # Update your packages
   npm update
   ```

2. **Missing dependencies**

   Templates assume certain packages are installed:
   ```bash
   # Check skill's Quick Start section for required packages
   npm install [missing-package]
   ```

3. **Wrong framework version**

   Some skills target specific versions (e.g., Tailwind v4, React 19):
   ```bash
   # Check your versions
   npm list tailwindcss react

   # Compare with skill requirements
   ```

### "Config files don't match"

**Symptoms:**
- `wrangler.jsonc` has wrong structure
- `vite.config.ts` missing options
- TypeScript errors in config

**Solution:**

Don't copy config files blindly. Skills show patterns, but your project may differ:

1. Read the skill's "Configuration" section
2. Adapt patterns to your existing config
3. Keep your project's existing structure where possible

---

## Claude Behavior Issues

### "Claude keeps suggesting the wrong skill"

**Symptoms:**
- Ask about Topic A, get Skill B suggested
- Multiple skills compete for same keywords

**Solutions:**

1. **Be more specific in your request**
   ```
   ❌ "Help me with database"
   ✅ "Help me with Cloudflare D1 database migrations"
   ```

2. **Explicitly request the skill**
   ```
   "Use the cloudflare-d1 skill to help me set up migrations"
   ```

3. **Check for keyword conflicts**

   If your skill and another share keywords, make yours more specific.

### "Claude doesn't follow skill patterns"

**Symptoms:**
- Claude knows the skill but doesn't use its templates
- Suggests outdated patterns despite skill having current ones

**Causes:**

1. **Skill not fully loaded** - Restart Claude Code
2. **Context window full** - Start a new conversation
3. **Conflicting instructions** - Check your CLAUDE.md for conflicts

**Solution:**
```
"Please read the cloudflare-d1 skill completely and follow its
Quick Start section exactly."
```

---

## Development Issues

### "My changes aren't appearing"

After editing a skill:

1. **Reinstall the skill**
   ```bash
   /plugin install ./skills/my-skill
   ```

2. **Restart Claude Code**
   ```bash
   exit
   claude
   ```

3. **Verify the file was saved**
   ```bash
   cat skills/my-skill/SKILL.md | head -20
   ```

4. **Check for syntax errors**
   ```bash
   # Validate YAML frontmatter
   ./scripts/check-metadata.sh my-skill
   ```

### "Skill works locally but not after push"

**Causes:**

1. **Marketplace not updated**
   ```bash
   # After pushing, update marketplace
   /plugin marketplace update jezweb-skills
   ```

2. **Missing plugin manifest**
   ```bash
   # Generate manifest
   ./scripts/generate-plugin-manifests.sh my-skill
   git add skills/my-skill/.claude-plugin/
   git commit -m "Add plugin manifest"
   git push
   ```

3. **File not committed**
   ```bash
   git status
   # Make sure all skill files are committed
   ```

---

## YAML Frontmatter Errors

### "Invalid YAML" or skill not loading

**Check these common issues:**

1. **Missing document markers**
   ```yaml
   ---
   name: my-skill
   description: My description
   ---
   ```
   Both `---` markers are required.

2. **Bad indentation**
   ```yaml
   # Wrong (tabs or inconsistent spaces)
   description: |
   	This uses a tab

   # Correct (2 spaces)
   description: |
     This uses spaces
   ```

3. **Unquoted special characters**
   ```yaml
   # Wrong
   description: Use when: setting up D1

   # Correct
   description: "Use when: setting up D1"
   # Or use multiline
   description: |
     Use when: setting up D1
   ```

4. **Invalid field names**
   ```yaml
   # Wrong - non-standard fields
   keywords: [a, b, c]
   version: 1.0.0

   # Correct - only standard fields
   name: my-skill
   description: |
     Description here
   ```

### Validating YAML

```bash
# Use the metadata checker
./scripts/check-metadata.sh my-skill

# Or manually check with Python
python3 -c "import yaml; yaml.safe_load(open('skills/my-skill/SKILL.md').read().split('---')[1])"
```

---

## Performance Issues

### "Skills make Claude slow"

**Causes:**

1. **Too many skills installed** - Only install what you need
2. **Large skill files** - Skills should be <5k words
3. **Complex templates** - Templates are loaded on demand

**Solutions:**

```bash
# Check installed plugins
/plugin list

# Remove unused plugins
/plugin uninstall unused-plugin@jezweb-skills
```

### "Context window fills up quickly"

Skills add to context when used. To minimize:

1. Be specific about which skill to use
2. Start new conversations for different topics
3. Don't ask Claude to "use all skills"

---

## Getting Help

### Self-Diagnosis Checklist

Before asking for help, check:

- [ ] Is the skill installed? (`/plugin list`)
- [ ] Did you restart Claude Code?
- [ ] Is YAML frontmatter valid?
- [ ] Are trigger keywords in README.md?
- [ ] Does the skill path exist?
- [ ] Are you using the correct plugin name?

### Reporting Issues

If you've tried the above and still have issues:

1. **GitHub Issues**: https://github.com/jezweb/claude-skills/issues
2. **Include**:
   - Skill name
   - Error message (if any)
   - Steps to reproduce
   - Your environment (OS, Claude Code version)

---

## Related Documentation

- [PLUGIN_INSTALLATION_GUIDE.md](PLUGIN_INSTALLATION_GUIDE.md) - Installation details
- [MARKETPLACE.md](MARKETPLACE.md) - Marketplace information
- [../CONTRIBUTING.md](../CONTRIBUTING.md) - Creating skills
- [../ONE_PAGE_CHECKLIST.md](../ONE_PAGE_CHECKLIST.md) - Quality checklist

---

**Maintainer**: Jeremy Dawes | Jezweb

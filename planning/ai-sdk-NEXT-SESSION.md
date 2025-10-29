# AI SDK Skills - Ready to Build

**Created**: 2025-10-21
**Status**: Planning Complete ✅ - Ready for Execution

---

## 📋 What We Did (This Session)

✅ **Research Complete**
- Comprehensive research on Vercel AI SDK v5
- Documented 24 known issues (12 Core + 12 UI)
- Catalogued 15+ v4→v5 breaking changes
- Verified package versions (ai@5.0.76, providers@2.0+)
- Analyzed 25+ providers (focusing on top 4)
- Tested integration patterns (Cloudflare Workers, Next.js)

✅ **Specifications Created**
- **ai-sdk-core-spec.md** (970 lines) - Complete blueprint for backend skill
- **ai-sdk-ui-spec.md** (968 lines) - Complete blueprint for frontend skill
- **research-logs/ai-sdk.md** (592 lines) - All research findings

✅ **Roadmap Updated**
- Added both skills to Batch 2
- Updated progress tracking
- Defined priorities (ai-sdk-core first, then ai-sdk-ui)

---

## 🚀 Next Steps (Fresh Context)

### Session 1: Build ai-sdk-core (6-8 hours)

**What to Do:**
1. Read `/home/jez/Documents/claude-skills/planning/ai-sdk-core-spec.md`
2. Follow the specification exactly
3. Create skill structure
4. Write SKILL.md (800-1000 lines)
5. Create 13 templates
6. Create 5 reference docs
7. Test all templates
8. Verify auto-discovery

**File Locations:**
- Skill directory: `/home/jez/Documents/claude-skills/skills/ai-sdk-core/`
- Specification: `/home/jez/Documents/claude-skills/planning/ai-sdk-core-spec.md`
- Research log: `/home/jez/Documents/claude-skills/planning/research-logs/ai-sdk.md`

**Key Points:**
- Focus on v5 (stable), NOT v6 beta
- Top 4 providers: OpenAI, Anthropic, Google, Cloudflare (in that order)
- Don't prioritize workers-ai-provider (it's one option among many)
- Document top 12 errors, link to docs for rest
- Include v4→v5 migration guide
- Link to advanced topics (don't replicate)

### Session 2: Build ai-sdk-ui (5-7 hours)

**What to Do:**
1. Read `/home/jez/Documents/claude-skills/planning/ai-sdk-ui-spec.md`
2. Follow the specification exactly
3. Create skill structure
4. Write SKILL.md (700-900 lines)
5. Create 11 templates
6. Create 5 reference docs
7. Test all templates
8. Verify auto-discovery

**File Locations:**
- Skill directory: `/home/jez/Documents/claude-skills/skills/ai-sdk-ui/`
- Specification: `/home/jez/Documents/claude-skills/planning/ai-sdk-ui-spec.md`
- Research log: `/home/jez/Documents/claude-skills/planning/research-logs/ai-sdk.md`

**Key Points:**
- Focus on v5 breaking changes (especially useChat input management)
- Next.js App Router + Pages Router examples
- Document top 12 UI errors
- Message rendering patterns
- Link to Generative UI / RSC (don't replicate)

---

## 📦 Specifications Overview

### ai-sdk-core

**Scope:**
- generateText, streamText, generateObject, streamObject
- Tool calling & Agent class
- Multi-step execution (stopWhen)
- OpenAI, Anthropic, Google, Cloudflare providers
- v4→v5 migration guide
- Top 12 errors with solutions

**Files to Create:**
```
skills/ai-sdk-core/
├── SKILL.md
├── README.md
├── templates/ (13 files)
│   ├── generate-text-basic.ts
│   ├── stream-text-chat.ts
│   ├── generate-object-zod.ts
│   ├── stream-object-zod.ts
│   ├── tools-basic.ts
│   ├── agent-with-tools.ts
│   ├── multi-step-execution.ts
│   ├── openai-setup.ts
│   ├── anthropic-setup.ts
│   ├── google-setup.ts
│   ├── cloudflare-worker-integration.ts
│   ├── nextjs-server-action.ts
│   └── package.json
├── references/ (5 files)
│   ├── providers-quickstart.md
│   ├── v5-breaking-changes.md
│   ├── top-errors.md
│   ├── production-patterns.md
│   └── links-to-official-docs.md
└── scripts/
    └── check-versions.sh
```

### ai-sdk-ui

**Scope:**
- useChat, useCompletion, useObject hooks
- v4→v5 migration (useChat input management)
- Next.js App Router & Pages Router
- Message rendering, persistence, tool calling UI
- Top 12 UI errors with solutions

**Files to Create:**
```
skills/ai-sdk-ui/
├── SKILL.md
├── README.md
├── templates/ (11 files)
│   ├── use-chat-basic.tsx
│   ├── use-chat-tools.tsx
│   ├── use-chat-attachments.tsx
│   ├── use-completion-basic.tsx
│   ├── use-object-streaming.tsx
│   ├── nextjs-chat-app-router.tsx
│   ├── nextjs-chat-pages-router.tsx
│   ├── nextjs-api-route.ts
│   ├── message-persistence.tsx
│   ├── custom-message-renderer.tsx
│   └── package.json
├── references/ (5 files)
│   ├── use-chat-migration.md
│   ├── streaming-patterns.md
│   ├── top-ui-errors.md
│   ├── nextjs-integration.md
│   └── links-to-official-docs.md
└── scripts/
    └── check-versions.sh
```

---

## 🎯 Success Criteria

**ai-sdk-core:**
- [x] SKILL.md 800-1000 lines
- [x] 13 working templates
- [x] Top 12 errors documented
- [x] v5 breaking changes guide
- [x] 4 providers covered
- [x] Token savings ≥ 55%

**ai-sdk-ui:**
- [x] SKILL.md 700-900 lines
- [x] 11 working templates
- [x] Top 12 UI errors documented
- [x] v5 migration (useChat)
- [x] Next.js examples (both routers)
- [x] Token savings ≥ 50%

---

## 📊 Quick Reference

**Package Versions:**
- ai: 5.0.76+
- @ai-sdk/openai: 2.0.53+
- @ai-sdk/anthropic: 2.0.x
- @ai-sdk/google: 2.0.x
- workers-ai-provider: 2.0.0
- zod: 3.23.8+
- react: 18.2.0+ or 19.0.0-rc
- next: 14.0.0+ or 15.x.x

**Official Docs:**
- https://ai-sdk.dev/docs
- https://ai-sdk.dev/docs/ai-sdk-core/overview
- https://ai-sdk.dev/docs/ai-sdk-ui/overview
- https://ai-sdk.dev/docs/migration-guides/migration-guide-5-0
- https://ai-sdk.dev/docs/troubleshooting
- https://ai-sdk.dev/docs/reference/ai-sdk-errors

**Research Log:**
- `/home/jez/Documents/claude-skills/planning/research-logs/ai-sdk.md`

---

## 🔑 Key Decisions Made

1. **Split into two skills** - Core (backend) + UI (frontend) for context management
2. **Focus on v5 stable** - NOT v6 beta
3. **Top 4 providers** - OpenAI, Anthropic, Google, Cloudflare (in order)
4. **Don't prioritize workers-ai-provider** - One option among many
5. **Link to advanced topics** - Embeddings, image gen, Generative UI (don't replicate)
6. **Document top 12 errors** - Link to official docs for full catalog
7. **Include v4→v5 migration** - Major breaking changes (15+)
8. **Next.js examples** - App Router + Pages Router (not full CI/CD)

---

## 💡 Important Notes

### Do's:
✅ Follow specifications exactly
✅ Test all templates
✅ Copy-paste must work
✅ Link to official docs for advanced topics
✅ Emphasize v5 breaking changes
✅ Include practical examples

### Don'ts:
❌ Don't replicate all 28 error types
❌ Don't cover v6 beta
❌ Don't replicate full provider catalog
❌ Don't include full CI/CD
❌ Don't prioritize workers-ai-provider
❌ Don't replicate Generative UI docs

---

## 🚦 Execution Checklist

### Before Starting ai-sdk-core:
- [ ] Clear context window
- [ ] Read ai-sdk-core-spec.md
- [ ] Read research-logs/ai-sdk.md
- [ ] Verify package versions (npm view)
- [ ] Start fresh TodoWrite

### After Completing ai-sdk-core:
- [ ] Test all 13 templates
- [ ] Verify auto-discovery
- [ ] Install to ~/.claude/skills/
- [ ] Test with Claude Code
- [ ] Measure token savings
- [ ] Commit to git
- [ ] Clear context for ai-sdk-ui

### After Completing ai-sdk-ui:
- [ ] Test all 11 templates
- [ ] Verify auto-discovery
- [ ] Install to ~/.claude/skills/
- [ ] Test with Claude Code
- [ ] Test full-stack scenario (Core + UI)
- [ ] Measure token savings
- [ ] Commit to git
- [ ] Update roadmap with completion

---

## 📁 File Summary

**Planning Files Created:**
- `planning/ai-sdk-core-spec.md` (970 lines)
- `planning/ai-sdk-ui-spec.md` (968 lines)
- `planning/research-logs/ai-sdk.md` (592 lines)
- `planning/ai-sdk-NEXT-SESSION.md` (this file)

**Total Lines**: 2,530+ lines of planning

**Roadmap Updated**: ✅

---

**Ready to build! Clear context and start with ai-sdk-core.** 🚀

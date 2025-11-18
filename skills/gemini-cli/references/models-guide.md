# Gemini Models Comparison Guide

Based on systematic testing (2025-11-08)

---

## Available Models

### gemini-2.5-flash (Default)

**Characteristics**:
- Fast response time: ~5-25 seconds (average ~20s)
- Good quality for most tasks: ⭐⭐⭐⭐
- Prioritizes: Performance, simplicity, speed
- Safe with directory scanning
- Lower cost

**Best For**:
- Code reviews
- Debugging (root cause analysis is strong)
- Directory/file scanning
- General questions
- When speed matters

**Example**:
```bash
cat src/auth.ts | gemini -p "Review this code"
echo "Error message here" | gemini -p "Help debug this error"
```

---

### gemini-2.5-pro

**Characteristics**:
- Response time: ~15-30 seconds (average ~23s, often similar to Flash!)
- Excellent quality: ⭐⭐⭐⭐⭐
- Prioritizes: Correctness, consistency, thoroughness
- May get confused with directory scanning (tries to use tools)
- Higher cost

**Best For**:
- Architecture decisions (critical)
- Security audits (thorough)
- Complex reasoning tasks
- When accuracy > speed
- Major refactoring plans

**Example**:
```bash
gemini -m gemini-2.5-pro -p "Should I use D1 or KV for session storage? Explain trade-offs."
cat ./src/api/* | gemini -m gemini-2.5-pro -p "Perform a security audit on this code"
```

---

### gemini-2.5-flash-lite

**Status**: ❌ **Not accessible via Gemini CLI**

Model exists in Gemini API but returns 404 error when accessed via CLI. Do not use.

---

## When Models Disagree

**Critical Finding**: Flash and Pro can give **opposite recommendations** for the same question, and **both can be valid**.

**Example** (D1 vs KV for sessions):
- **Flash**: Recommends KV
  - Prioritizes: Performance, edge caching, TTL
  - "Usually acceptable" eventual consistency

- **Pro**: Recommends D1
  - Prioritizes: Strong consistency, SQL queries
  - "Critical" consistency for sessions

**Why This Happens**:
- Flash: Performance-focused
- Pro: Consistency-focused

**How to Handle**:
1. For critical/security decisions → Prefer Pro's perspective
2. For performance-sensitive apps → Consider Flash's perspective
3. For major architectural choices → Get both viewpoints:
   ```bash
   gemini -p "Question?"  # Flash (default)
   gemini -m gemini-2.5-pro -p "Same question"  # Pro
   ```

---

## Model Selection Matrix

| Task Type | Recommended Model | Why |
|-----------|-------------------|-----|
| Quick questions | Flash | Acceptable quality, fast |
| Architecture decisions | **Pro** | More thorough trade-off analysis |
| Security reviews | **Pro** | Catches subtle issues |
| Debug assistance | Flash | Root cause analysis is good enough |
| Code review | Flash | Comprehensive enough for most cases |
| Directory scanning | Flash | Pro may get confused, use tools |
| Whole project analysis | Pro | Better with 1M context |

---

## Performance Comparison

Based on testing with same question ("D1 vs KV for sessions"):

| Model | Time | Quality | Recommendation |
|-------|------|---------|----------------|
| Flash | ~25s | ⭐⭐⭐⭐ | KV (performance) |
| Pro | ~23s | ⭐⭐⭐⭐⭐ | D1 (consistency) |
| Flash-lite | 404 error | N/A | Not accessible |

**Key Finding**: Pro isn't significantly slower than Flash on many queries!

---

## Override Default Model

```bash
# Use Pro for single command
gemini -m gemini-2.5-pro -p "Review this code" < src/auth.ts

# Or set as environment variable for all commands in session
export GEMINI_MODEL=gemini-2.5-pro
gemini -p "Review this code" < src/auth.ts
gemini -p "Architecture question here"
```

---

## Recommendations

**Default Strategy**: Use Flash for most tasks, Pro for critical decisions

**When to Always Use Pro**:
- Architectural decisions
- Security audits
- Major refactors
- Production deployment reviews

**When Flash is Better**:
- Quick code reviews
- Debugging
- Directory/file scanning
- Non-critical questions

**When to Get Both Perspectives**:
- Critical architectural decisions
- Technology choices that affect entire project
- Performance vs consistency trade-offs

---

**Last Updated**: 2025-11-08
**Source**: Systematic testing documented in `gemini-experiments.md`

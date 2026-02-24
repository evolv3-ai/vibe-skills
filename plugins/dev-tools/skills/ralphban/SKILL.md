---
name: ralphban
description: |
  Create structured task files for the Ralphban VS Code extension - a visual Kanban board for LLM agent workflows. Generate valid task JSON with proper schema, status tracking, dependencies, and priority levels.

  Use when: breaking down features into agent-executable tasks, creating PRD files for Ralph-style workflows, visualizing LLM task graphs, or troubleshooting "Invalid task schema", "Task not found", "missing description field".
---

# Ralphban Task Creator

## Quick Start (2 Minutes)

### 1. Create a Task File

Create a JSON file matching Ralphban's file patterns (default: `*.prd.json`, `prd.json`, `tasks.json`):

```bash
touch prd.json
```

### 2. Add Tasks with Proper Schema

```json
[
  {
    "category": "backend",
    "description": "Design task execution loop",
    "status": "pending",
    "priority": "high",
    "steps": [
      "Define task state transitions",
      "Handle retries and failures",
      "Persist progress"
    ],
    "dependencies": [],
    "passes": null
  }
]
```

**CRITICAL:**
- `description` is the unique identifier - must be unique across all tasks
- `category`, `description`, and `steps` are required fields
- `status` defaults to `pending` if omitted

### 3. Visualize in VS Code

Open the file in VS Code with Ralphban extension installed. The Kanban board appears in the sidebar.

---

## Task Schema Reference

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `category` | string | Task category (configurable, defaults below) |
| `description` | string | Unique task identifier and display text |
| `steps` | string[] | Ordered list of steps to complete |

### Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `status` | enum | `"pending"` | `pending`, `in_progress`, `completed`, `cancelled` |
| `priority` | enum | none | `high`, `medium`, `low` |
| `dependencies` | string[] | `[]` | Descriptions of tasks that must complete first |
| `passes` | boolean\|null | `null` | Explicit pass/fail (overrides status if set) |

### Default Categories

```
frontend, backend, database, testing, documentation, infrastructure, security, functional
```

Custom categories can be configured in VS Code settings: `ralphban.categories`.

---

## Critical Rules

### Always Do

- Use unique `description` values - this is the task's ID
- Include at least one step in the `steps` array (can be empty `[]`)
- Set `status` to `in_progress` when an agent starts working on a task
- Use `dependencies` array to express task ordering for agents
- Name files to match patterns: `*.prd.json`, `prd.json`, or `tasks.json`

### Never Do

- Duplicate `description` values across tasks - causes lookup failures
- Move completed tasks back to pending (extension enforces this)
- Use `passes: true` without also setting `status: "completed"`
- Omit required fields (`category`, `description`, `steps`)
- Put task files outside workspace root without updating `filePatterns`

---

## Status State Machine

```
pending ──────> in_progress ──────> completed
    |               |                    ^
    |               |                    |
    └───────────────┴──> cancelled ──────┘
                              (passes: false)
```

**Status meanings:**
- `pending`: Not started, waiting in backlog
- `in_progress`: Agent is actively working on this task
- `completed`: Task finished successfully
- `cancelled`: Task abandoned or blocked

**The `passes` field:**
- `null` or undefined: Use `status` to determine completion
- `true`: Explicitly passed (forces completed state)
- `false`: Explicitly failed (forces cancelled state)

---

## Common Patterns

### Pattern 1: Feature Breakdown PRD

```json
[
  {
    "category": "backend",
    "description": "Create user authentication API",
    "status": "pending",
    "priority": "high",
    "steps": [
      "Define auth endpoints (/login, /logout, /refresh)",
      "Implement JWT token generation",
      "Add password hashing with bcrypt",
      "Create middleware for protected routes"
    ],
    "dependencies": []
  },
  {
    "category": "frontend",
    "description": "Build login form component",
    "status": "pending",
    "priority": "high",
    "steps": [
      "Create LoginForm.tsx with email/password fields",
      "Add form validation with error states",
      "Connect to auth API endpoints",
      "Handle loading and error states"
    ],
    "dependencies": ["Create user authentication API"]
  },
  {
    "category": "testing",
    "description": "Write auth integration tests",
    "status": "pending",
    "priority": "medium",
    "steps": [
      "Test successful login flow",
      "Test invalid credentials handling",
      "Test token refresh mechanism",
      "Test logout and session cleanup"
    ],
    "dependencies": [
      "Create user authentication API",
      "Build login form component"
    ]
  }
]
```

**When to use**: Breaking down features into agent-executable tasks with clear dependencies.

### Pattern 2: Agent Status Updates

When an agent picks up a task:

```json
{
  "description": "Create user authentication API",
  "status": "in_progress"
}
```

When task completes:

```json
{
  "description": "Create user authentication API",
  "status": "completed",
  "passes": true
}
```

When task fails:

```json
{
  "description": "Create user authentication API",
  "status": "cancelled",
  "passes": false
}
```

### Pattern 3: Minimal Task (Agent-Generated)

```json
{
  "category": "functional",
  "description": "Verify checkout flow handles empty cart",
  "steps": [
    "Navigate to checkout with empty cart",
    "Verify error message appears",
    "Confirm redirect to cart page"
  ]
}
```

Status and other fields default appropriately for pending tasks.

---

## File Pattern Configuration

Ralphban discovers task files via glob patterns. Default patterns:

```json
{
  "ralphban.filePatterns": [
    "**/*.prd.json",
    "**/prd.json",
    "**/tasks.json"
  ]
}
```

**Recommended naming conventions:**
- `prd.json` - Main project PRD in repo root
- `feature-name.prd.json` - Feature-specific task files
- `plans/sprint-1.prd.json` - Organized by sprint/phase

---

## Integration with LLM Agents

### Bash Script Pattern (from Matt Pocock)

```bash
#!/bin/bash
# Process tasks one at a time

TASKS_FILE="prd.json"

# Get next pending task
NEXT_TASK=$(jq -r '[.[] | select(.status == "pending")][0].description' "$TASKS_FILE")

if [ -n "$NEXT_TASK" ] && [ "$NEXT_TASK" != "null" ]; then
  # Mark as in_progress
  jq --arg desc "$NEXT_TASK" \
    '(.[] | select(.description == $desc)).status = "in_progress"' \
    "$TASKS_FILE" > tmp.json && mv tmp.json "$TASKS_FILE"

  # Feed to agent
  echo "Working on: $NEXT_TASK"
  # ... agent execution here ...

  # Mark complete
  jq --arg desc "$NEXT_TASK" \
    '(.[] | select(.description == $desc)).status = "completed" |
     (.[] | select(.description == $desc)).passes = true' \
    "$TASKS_FILE" > tmp.json && mv tmp.json "$TASKS_FILE"
fi
```

### Dependency Resolution

Before starting a task, check that all dependencies are completed:

```bash
# Check if task is ready (all deps completed)
is_ready() {
  local task_desc="$1"
  local deps=$(jq -r --arg desc "$task_desc" \
    '.[] | select(.description == $desc).dependencies // []' "$TASKS_FILE")

  for dep in $(echo "$deps" | jq -r '.[]'); do
    status=$(jq -r --arg d "$dep" \
      '.[] | select(.description == $d).status' "$TASKS_FILE")
    if [ "$status" != "completed" ]; then
      return 1
    fi
  done
  return 0
}
```

---

## Known Issues Prevention

This skill prevents **3** documented issues:

### Issue #1: Task Not Found on Status Update
**Error**: `Task "..." not found`
**Source**: Tasks are matched by exact `description` string
**Why It Happens**: Description was modified or has whitespace differences
**Prevention**: Never modify `description` after creation; use exact match when updating

### Issue #2: Invalid Schema Validation
**Error**: `Invalid task file: missing required field`
**Source**: AJV schema validation in `jsonParser.ts`
**Why It Happens**: Missing `category`, `description`, or `steps` field
**Prevention**: Always include all three required fields, even if `steps: []`

### Issue #3: Completed Tasks Revert
**Error**: Tasks snap back to completed column
**Source**: Business rule in UI prevents completed -> pending/in_progress
**Why It Happens**: Attempting to move completed tasks backward
**Prevention**: Once completed, create new task if retry needed; don't modify status backward

---

## VS Code Configuration

```json
{
  "ralphban.filePatterns": ["**/*.prd.json", "**/tasks.json"],
  "ralphban.categories": [
    "frontend",
    "backend",
    "database",
    "testing",
    "documentation",
    "infrastructure",
    "security",
    "functional"
  ],
  "ralphban.featureFlags.enablePercentageCounter": true,
  "ralphban.featureFlags.enableDragDrop": true,
  "ralphban.featureFlags.enableFilters": true
}
```

---

## Troubleshooting

### Problem: Tasks not appearing in Kanban
**Solution**: Verify file matches `ralphban.filePatterns` glob. Check Output -> Ralphban for errors.

### Problem: Drag and drop not working
**Solution**: Check `ralphban.featureFlags.enableDragDrop` is `true`. Completed tasks cannot move backward.

### Problem: Schema validation errors
**Solution**: Ensure valid JSON array, each task has `category`, `description`, `steps`. Use VS Code's JSON validation.

### Problem: Dependencies not visualized
**Solution**: Dependencies reference other tasks by exact `description` string. Typos break the link.

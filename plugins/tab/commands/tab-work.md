---
name: tab-work
description: "Tab project workflow: load a Tab project, research codebase, plan from Tab tasks, create a branch, run sub-agents to implement and review (tracking progress via Tab tasks), then commit (never push). Use when working on a Tab project — e.g. 'work on doot', 'tackle the doot project', 'implement doot tasks', 'do tab project X'. Also handles 'save our work' by updating Tab project and progress notes."
---

# Tab Work

Complete a **Tab project** using **sub-agents to preserve main context**. The main conversation is an **orchestrator** — it holds the plan, delegates heavy work to sub-agents, tracks progress in Tab, and gets back summaries.

## When this skill applies

- User wants to **implement**, **tackle**, or **work on** a Tab project
- User references a project by name (e.g. "work on doot", "implement the doot tasks")
- User says **"save our work"** / **"save progress"** → update Tab project + progress notes
- **Triggers**: "work on {project}", "tackle {project}", "implement {project} tasks", "do tab project {name}", "continue {project}"

## Project Types

Detect the project type from the Tab project title — if it starts with a Jira key (e.g. `IO-2097:`), it's a PlexTrac project.

| | PlexTrac | Personal |
|---|---------|----------|
| **Detect by** | Title starts with Jira key (e.g. `IO-2097:`) | No Jira key in title |
| **Workspace** | `~/workspaces/plextrac/{repo}` | `~/workspaces/{project-slug}` |
| **Notes** | `~/workspaces/plextrac/notes/{TICKET-KEY}/` | `{project-dir}/notes/` |
| **Branch** | `{TICKET-KEY}-{kebab}` | `{project-slug}-{kebab}` |
| **Commit** | `{TICKET-KEY}: description` | Short descriptive message |
| **Standards** | PlexTrac CLAUDE.md for target repo | Language conventions |
| **Verification** | `/verify` (repo-specific) | `/tab-verify` (auto-detect) |
| **PR template** | PlexTrac `.github/PULL_REQUEST_TEMPLATE.md` | None required |
| **Never push** | Yes — user pushes | Yes — user pushes |

---

## Tab as Source of Truth

Tab replaces both Jira (ticket source) and local spec files:

| Concept | plextrac-work (Jira) | tab-work (Tab) |
|---------|---------------------|----------------|
| Ticket/project | Jira issue | Tab project (goal, requirements, design) |
| Plan | `notes/{KEY}/plan.md` | Tab tasks (all fields populated) |
| Task tracking | Internal TaskCreate/TaskUpdate | Tab task status (todo → in_progress → done) |
| Research notes | `notes/{KEY}/research.md` | Local notes + Tab project design field |
| Progress log | `notes/{KEY}/progress.md` | Local notes + Tab task statuses |
| Reference docs | `reference/*.md` in plugins | Tab documents (shared KB, attached to projects) |

### Notes folder

Each project still gets a local folder for research and progress:
`~/workspaces/{project-slug}/notes/` or `./notes/` in the project directory.

| File | Purpose | Written when |
|------|---------|--------------|
| `research.md` | Codebase findings, approaches, tradeoffs | Step 1 (research sub-agent) |
| `progress.md` | Running journal of what was done | "Save our work" trigger |

The **plan lives in Tab tasks** — no separate `plan.md` needed.

---

## Task Completeness — REQUIRED

**GATE: ALL fields must be populated at task creation time — not backfilled later.** This applies to every task, including review findings, branch creation, and PR tasks. Done tasks serve as reference for future projects, so they need complete `plan` and `implementation` fields too.

**For done tasks:** `implementation` should include links (PR URLs, branch names) and a summary of what was built. `plan` should capture the approach and key decisions so future projects can reference the pattern.

Every Tab task MUST have these fields:

| Field | Required | Example |
|-------|----------|---------|
| **title** | Yes | "Create pyproject.toml with console_scripts entry point" |
| **description** | Yes | "Minimal pyproject.toml that defines doot as a console script..." |
| **implementation** | Yes | Exact code snippets, file paths, function signatures, step-by-step |
| **acceptance_criteria** | Yes | "- `pip install -e .` succeeds\n- `doot` command is on PATH" |
| **category** | Yes | feature / bugfix / refactor / test / perf / infra / docs / security / design / chore |
| **effort** | Yes | trivial / low / medium / high / extreme |
| **impact** | Yes | trivial / low / medium / high / extreme |
| **group_key** | Yes | Logical grouping, max 32 chars (e.g. "setup", "core", "testing") |
| **plan** | Optional | High-level approach if different from implementation details |

**Before Step 4 begins, the orchestrator MUST:**
1. List all `todo` tasks for the project
2. Check each task has `implementation` and `acceptance_criteria` populated
3. If any task is missing fields, stop and fill them in (with user if needed)
4. Only proceed to implementation once all tasks pass the completeness check

---

## Sub-Agent Architecture

The main conversation is an **orchestrator**. Heavy work is delegated to sub-agents.

| Agent | Type | Role | Reads | Writes |
|-------|------|------|-------|--------|
| **Planner** | `tab-workflow:planner` | Decompose work into tasks with plans and criteria | Tab project, KB documents, codebase | Tab tasks (plan, acceptance_criteria) |
| **Research** | Explore | Explore codebase and identify affected areas | Tab project, KB documents, codebase | `research.md` |
| **Implement** | general-purpose | Write code for a specific task | Tab tasks, KB documents, source files | Source code |
| **Test** | general-purpose | Write and run tests | Changed files, existing tests | Test files |
| **QA** | `tab-workflow:qa` | Validate work against plans and criteria | Tab tasks, codebase, KB documents | Tab tasks (qa-findings) |
| **Documenter** | `tab-workflow:documenter` | Extract knowledge from completed work | Completed tasks, codebase, KB documents | Tab documents |
| **Review** | code-reviewer | Review changed files for code quality | All changed files | Nothing (report only) |
| **Fix** | general-purpose | Apply fixes from review/QA findings | Review findings, source | Source fixes |
| **Verify** | general-purpose | Run lint/typecheck/tests | Changed files | Nothing (report only) |

### Rules for sub-agents
- Each gets a **self-contained prompt** with everything it needs
- Sub-agents **do not talk to the user** — only the orchestrator does
- Launch **parallel sub-agents** for independent tasks
- Pass **KB document IDs** to sub-agents (not full content) — they fetch what they need
- Use **named agents** (`tab-workflow:planner`, `tab-workflow:qa`, `tab-workflow:documenter`) when spawning specialist sub-agents
- Update Tab task status as work progresses

---

## Step 0: Load project from Tab

1. If user gives a project name, search with `mcp__tab-for-projects__list_projects`
2. Load the project (goal, requirements, design)
3. Load all tasks with `mcp__tab-for-projects__list_tasks` (filter by project_id)
4. **Load attached documents** with `mcp__tab-for-projects__list_documents({ project_id: "<pid>" })`, then `get_document` for each — these are the project's knowledge base
5. Show the user a summary: project goal, task count by status, what's todo, attached documents

**Resuming a previous session:**
- Check for tasks stuck in `in_progress` status (stale from a prior session)
- Reset stale `in_progress` tasks back to `todo`, or ask the user what to do with them
- Read `notes/progress.md` if it exists for context on what was done before

If no Tab project exists yet, suggest running the **tab-brainstorming** skill first.

---

## Step 1: Research (sub-agent)

- **Check KB documents first**: Search `mcp__tab-for-projects__list_documents` for documents tagged with relevant domains (e.g. `integration`, `architecture`). Load and pass to the research sub-agent as pre-existing context.
- **Check notes first**: If `notes/research.md` exists in the project dir, read it and skip to Step 2.
- **Otherwise**: Launch a **Research sub-agent** (`subagent_type: "Explore"`):

```
You are researching the "{project_title}" project.

Project goal: {goal}
Requirements: {requirements}
Design: {design}
Knowledge base documents:
{attached_document_contents}

Your job:
1. Explore the codebase to understand affected areas
2. Read affected files, trace call paths, understand current behavior
3. Identify touch points, risks, and potential approaches
4. Write findings to {project_dir}/notes/research.md
5. Return a 2-3 paragraph summary
```

**After research completes — sync to Tab:**

Append the research summary to the Tab project's `design` field so it's available cross-session:

```
mcp__tab-for-projects__update_project({
  items: [{
    id: "<pid>",
    design: "{existing_design}\n\n## Research Findings\n{research_summary}"
  }]
})
```

---

## Step 2: Plan with user (main context)

**Tab tasks ARE the plan.** If the project already has tasks with implementation details, present them to the user.

- **Tasks exist with all fields populated**: Summarize the task list, confirm execution order with user
- **Tasks exist but missing fields**: Fill in missing fields (implementation, acceptance_criteria, effort, impact, category, group_key)
- **No tasks**: Use **tab-brainstorming** skill to create them, or work with user to break the design into tasks

**Spawn planner agent for task decomposition:**

If the design needs to be broken into tasks, spawn the planner agent:

```
Agent(
  description: "Plan tasks for {project_title}",
  subagent_type: "tab-workflow:planner",
  prompt: "Project ID: {pid}\n\nWork to decompose: {design_summary}\n\nKnowledgebase document IDs: {doc_ids}\n\nBreak this into actionable tasks with implementation plans and acceptance criteria.",
  run_in_background: true
)
```

**When creating or updating tasks, ALWAYS populate ALL fields:**
```
mcp__tab-for-projects__create_task({
  items: [{
    project_id: "<pid>",
    title: "Imperative description of what to do",
    description: "Full context of what needs to happen and why",
    implementation: "Exact steps:\n1. Create file X\n2. Add function Y with signature Z\n```python\ndef example():\n    pass\n```",
    acceptance_criteria: "- Specific check 1\n- Specific check 2\n- Command to verify",
    category: "feature",
    effort: "low",
    impact: "high",
    group_key: "core"
  }]
})
```

**Ensure test tasks exist.** If the project doesn't already have tasks with `category: "test"`, create them:
```
mcp__tab-for-projects__create_task({
  items: [{
    project_id: "<pid>",
    title: "Write tests for {feature}",
    description: "Cover happy path, edge cases, error paths",
    implementation: "Test files to create, test cases to cover, frameworks to use",
    acceptance_criteria: "- All tests pass\n- Coverage meets project standard",
    category: "test",
    effort: "medium",
    impact: "high",
    group_key: "testing"
  }]
})
```

---

## Step 3: Create branch (main context)

- **Standard**: `{project-slug}-{short-description}` (e.g. `doot-initial-implementation`)
- No type prefix (no `feature/`, `fix/`, etc.)
- Branch from default (e.g. `main`). Confirm with user if ambiguous.
- If no git repo exists yet, offer to `git init`.

---

## Step 4: Execute (sub-agents)

### Pre-flight: Task Completeness Check

**Before launching any sub-agent, verify ALL tasks pass the completeness gate:**

```
mcp__tab-for-projects__list_tasks({ project_id: "<pid>", status: "todo" })
```

For each task, confirm it has: `title`, `description`, `implementation`, `acceptance_criteria`, `category`, `effort`, `impact`, `group_key`. If any task is incomplete, fill in the missing fields before proceeding.

### Tab Task Lifecycle

As you work through tasks, update their status in Tab:

```
# Mark task as in progress
mcp__tab-for-projects__update_task({
  items: [{ id: "<id>", project_id: "<pid>", status: "in_progress" }]
})

# Mark task as done
mcp__tab-for-projects__update_task({
  items: [{ id: "<id>", project_id: "<pid>", status: "done" }]
})
```

### Design Sync — Keep project design field current

**When a task with `category: "design"` is marked done, update the project's `design` field to reflect the decision.** Design decisions made during implementation can cause the project-level design to drift from reality. Sync it immediately:

```
mcp__tab-for-projects__update_project({
  items: [{
    id: "<pid>",
    design: "{updated design incorporating the new decision}"
  }]
})
```

This prevents stale designs from misleading future sessions that load the project.

### Verification Loop — use tab-verify

**Every time code changes, invoke the `tab-verify` skill.** It will:
1. Auto-detect project type and run appropriate checks (lint, typecheck, tests)
2. Create Tab bug tasks for any failures (`group_key: "verification-failures"`)
3. Dispatch fix sub-agents to resolve them
4. Re-verify until clean (max 3 cycles)

```
Implement → /tab-verify → Test → /tab-verify → Review → Fix → /tab-verify → Commit
```

### 4a. Implementation sub-agent(s)

Launch one sub-agent per Tab task (or group of related tasks). Mark task `in_progress` in Tab before launching.

```
You are implementing task "{task_title}" for the {project_title} project.

Task description: {description}
Implementation plan: {implementation}
Acceptance criteria: {acceptance_criteria}

Reference documents:
{relevant_document_contents}

Working directory: {project_dir}
Branch: {branch_name}

Implement the changes. When done, return:
- List of files changed with one-line description each
- Any questions or ambiguities
```

**→ Run `/tab-verify`. Mark task `done` in Tab if verification passes.**

### 4b. Test sub-agent

Mark the test task `in_progress` in Tab before launching.

```
You are writing tests for the {project_title} project.

Files changed: {list from implementation}
Tasks implemented: {task titles}

Write tests covering: happy path, edge cases, error paths.
Run tests and report pass/fail.
```

**→ Run verification. Mark test task `done` in Tab.**

### 4c. Code review sub-agent — MANDATORY

**GATE: MUST run before commit. Even for small changes.**

Use `subagent_type: "superpowers:code-reviewer"` or the appropriate reviewer agent.

```
Review the changes for the {project_title} project on branch {branch}.

Return only actionable findings:
- File and line number
- What's wrong
- Suggested fix
```

### 4c-alt. QA agent (for thorough validation)

For thorough validation beyond code style, spawn the QA agent:

```
Agent(
  description: "QA validation for {project_title}",
  subagent_type: "tab-workflow:qa",
  prompt: "Project ID: {pid}\n\nScope: full\n\nKnowledgebase document IDs: {doc_ids}\n\nValidate all completed work against plans and acceptance criteria. Create qa-findings tasks for any issues.",
  run_in_background: true
)
```

QA creates tasks with `group_key: "qa-findings"`. These must be resolved before commit (same gate as review-findings).

### 4c-post. Orchestrator: Create Tab tasks from review findings

**When the review sub-agent returns findings, the orchestrator MUST create Tab tasks for each finding:**

```
mcp__tab-for-projects__create_task({
  items: findings.map(f => ({
    project_id: "<pid>",
    title: "Fix: {short description of finding}",
    description: "**File:** {file}:{line}\n**Issue:** {what's wrong}\n**Suggested fix:** {fix}",
    plan: "1. Read the affected file\n2. Apply the suggested fix\n3. Re-verify ESLint + typecheck",
    implementation: "File: {file}:{line}\nChange: {description of what to change}",
    acceptance_criteria: "- Finding resolved\n- ESLint + typecheck clean after fix",
    category: "bugfix",
    effort: "trivial",
    impact: "medium",
    group_key: "review-findings"
  }))
})
```

If the review returns **no findings**, create a single task to record a clean review:
```
mcp__tab-for-projects__create_task({
  items: [{
    project_id: "<pid>",
    title: "Code review: passed clean",
    description: "No actionable findings from code review",
    plan: "Run code-reviewer sub-agent on all changed files",
    implementation: "Ran {reviewer_type} on {files}. No actionable findings.",
    acceptance_criteria: "- Code review ran on all changed files\n- No findings returned",
    category: "chore",
    effort: "trivial",
    impact: "trivial",
    group_key: "review-findings",
    status: "done"
  }]
})
```

### 4d. Fix sub-agent (if review has findings)

Launch a fix sub-agent for the review-findings tasks. Mark each `in_progress` before starting, `done` after fixing.

```
Fix these code review findings for the {project_title} project:
{findings from Tab tasks with group_key "review-findings"}

Fix each finding. Return list of fixes applied.
```

**→ Run verification.**
**→ Mark fixed tasks as `done` in Tab. Any deferred findings stay as `todo`.**

### 4e. Verification sub-agent

```
Verify {project_title} changes on branch {branch}.

Run project checks and report pass/fail for each.
Do NOT fix anything — just report.
```

---

## Step 5: Commit (main context)

**GATE: Do NOT commit unless ALL of these are true:**
1. Code review ran and findings were created as Tab tasks (group_key: "review-findings")
2. All review-findings tasks are `done` (fixed) or explicitly deferred by the user
3. All qa-findings tasks are `done` (fixed) or explicitly deferred by the user
4. All verification-failures tasks are `done`
5. Verification passed after most recent code change
6. All implemented Tab tasks are marked `done`

**Pre-commit Tab check:**
```
# Check for unresolved review findings
mcp__tab-for-projects__list_tasks({
  project_id: "<pid>",
  group_key: "review-findings",
  status: "todo"
})

# Check for unresolved QA findings
mcp__tab-for-projects__list_tasks({
  project_id: "<pid>",
  group_key: "qa-findings",
  status: "todo"
})

# Check for unresolved verification failures
mcp__tab-for-projects__list_tasks({
  project_id: "<pid>",
  group_key: "verification-failures",
  status: "todo"
})

# Check all implementation tasks are done
mcp__tab-for-projects__list_tasks({
  project_id: "<pid>",
  status: "in_progress"
})
```

If any remain unresolved, they must be fixed or the user must explicitly approve deferring them.

- Commit message: short descriptive message
- **Never run `git push`.** Remind user: "Branch is committed; push when ready."

---

## Step 5.5: Knowledge extraction (documenter agent)

After committing, spawn the documenter agent to extract reusable knowledge:

```
Agent(
  description: "Extract knowledge from {project_title}",
  subagent_type: "tab-workflow:documenter",
  prompt: "Project ID: {pid}\n\nTask IDs of completed work: {done_task_ids}\n\nExisting knowledgebase document IDs: {doc_ids}\n\nExtract architectural decisions, patterns, and gotchas from the completed work. Write to the Tab knowledge base and attach documents to the project.",
  run_in_background: true
)
```

Skip this step if the work was purely mechanical (simple bugfix with no novel patterns). The documenter agent will decide what's worth documenting.

---

## Step 6: Handoff (main context)

**Query Tab for final status:**
```
mcp__tab-for-projects__list_tasks({ project_id: "<pid>", status: "done" })
mcp__tab-for-projects__list_tasks({ project_id: "<pid>", status: "todo" })
```

Present to user:
- **Summary**: What was implemented, which files changed
- **Branch name** and **commit hash(es)**
- **Tab status**: `{done_count} tasks done, {todo_count} remaining`
- **Remaining tasks**: List any `todo` tasks still in the backlog
- Optional: suggested PR title/description
- Reminder to push when ready

**Update Tab project if design evolved:**
```
mcp__tab-for-projects__update_project({
  items: [{
    id: "<pid>",
    design: "{updated design reflecting any changes made during implementation}"
  }]
})
```

---

## "Save our work" / Save progress

When the user says **"save our work"**, **"save progress"**, etc.:

1. **Update Tab task statuses** to reflect current state (any in-flight work → keep `in_progress`)
2. **Update Tab project** design field if design evolved during the session:
   ```
   mcp__tab-for-projects__update_project({
     items: [{ id: "<pid>", design: "{updated design}" }]
   })
   ```
3. **Back up Tab database** to Google Drive:
   ```
   /Users/parker/.local/bin/tab-db-backup.sh
   ```
4. If there are uncommitted changes, offer to commit

---

## Parallel opportunities

**Can parallelize:**
- Independent Tab tasks (different group_keys, no dependencies)
- Tests for completed code while implementing next task

**Must be sequential:**
- Research → Plan → Branch → Implement → Verify → Test → Verify → Review → Fix → Verify → Commit

---

## Tab MCP Quick Reference

```python
# List projects
mcp__tab-for-projects__list_projects()

# Get specific project
mcp__tab-for-projects__list_projects({ id: "<project_id>" })

# List tasks for a project
mcp__tab-for-projects__list_tasks({ project_id: "<id>" })

# Filter tasks
mcp__tab-for-projects__list_tasks({ project_id: "<id>", status: "todo" })
mcp__tab-for-projects__list_tasks({ project_id: "<id>", group_key: "core" })
mcp__tab-for-projects__list_tasks({ project_id: "<id>", category: "bugfix" })

# Create project
mcp__tab-for-projects__create_project({ items: [{ title, goal, requirements, design }] })

# Update project
mcp__tab-for-projects__update_project({ items: [{ id, goal, requirements, design }] })

# Create tasks (ALL fields required)
mcp__tab-for-projects__create_task({
  items: [{
    project_id, title, description, implementation,
    acceptance_criteria, category, effort, impact, group_key
  }]
})

# Update task status/details
mcp__tab-for-projects__update_task({
  items: [{ id, project_id, status, implementation, acceptance_criteria }]
})

# Documents (Knowledge Base)
mcp__tab-for-projects__list_documents()                              # all documents
mcp__tab-for-projects__list_documents({ tag: "architecture" })       # filter by tag
mcp__tab-for-projects__list_documents({ project_id: "<id>" })        # attached to project
mcp__tab-for-projects__get_document({ id: "<doc_id>" })              # full content

# Create document
mcp__tab-for-projects__create_document({
  items: [{ title, content, tags: ["integration", "architecture"] }]
})

# Update document
mcp__tab-for-projects__update_document({
  items: [{ id, content, tags }]
})

# Attach/detach documents to project
mcp__tab-for-projects__update_project({
  items: [{ id: "<pid>", attach_documents: ["<doc_id>"] }]
})
mcp__tab-for-projects__update_project({
  items: [{ id: "<pid>", detach_documents: ["<doc_id>"] }]
})
```

### Document tags
| Category | Tags |
|----------|------|
| **Domain** | `ui`, `data`, `integration`, `infra`, `domain` |
| **Content** | `architecture`, `conventions`, `guide`, `reference`, `decision`, `troubleshooting` |
| **Concern** | `security`, `performance`, `testing`, `accessibility` |

### Task fields — ALL required before implementation
- **title**: Imperative form ("Create pyproject.toml")
- **description**: What needs to be done and why
- **implementation**: Exact code, file paths, function signatures, steps
- **acceptance_criteria**: Specific pass/fail checks
- **plan**: (Optional) High-level approach if different from implementation
- **status**: todo → in_progress → done (or archived)
- **group_key**: Logical grouping, max 32 chars (e.g. "setup", "core", "testing", "review-findings", "verification-failures")
- **effort**: trivial / low / medium / high / extreme
- **impact**: trivial / low / medium / high / extreme
- **category**: feature / bugfix / refactor / test / perf / infra / docs / security / design / chore

---

## Superpowers Integration

| Step | Skill | When |
|------|-------|------|
| Planning (new project) | **tab-brainstorming** | Design-heavy or ambiguous work |
| Implementation | **subagent-driven-development** | Executing tasks in current session |
| Implementation | **test-driven-development** | During implementation |
| Code review | **code-review-excellence** | Mandatory before commit |
| Pre-commit | **verification-before-completion** | Run checks, confirm passing |
| Handoff | **finishing-a-development-branch** | Present options (never push) |

---

## References

- **Tab brainstorming**: tab-brainstorming skill (idea → design → Tab project + tasks)
- **Code review**: code-review-excellence skill
- **Verification**: verify skill (for PlexTrac repos) or project-specific checks

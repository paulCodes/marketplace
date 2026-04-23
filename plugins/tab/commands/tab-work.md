---
name: tab-work
description: "Tab project workflow: load a Tab project, research codebase, plan from Tab tasks, create a branch, run sub-agents to implement and review (tracking progress via Tab tasks), then commit (never push). Use when working on a Tab project — e.g. 'work on doot', 'tackle the doot project', 'implement doot tasks', 'do tab project X'. Also handles 'save our work' by updating Tab project and progress notes."
---

# Tab Work

Complete a **Tab project** using **sub-agents to preserve main context**. The main conversation is an **orchestrator**. It holds the plan, delegates heavy work to sub-agents, tracks progress in Tab, and gets back summaries.

## When this skill applies

- User wants to **implement**, **tackle**, or **work on** a Tab project
- User references a project by name (e.g. "work on doot", "implement the doot tasks")
- User says **"save our work"** / **"save progress"** --> update Tab project + progress notes
- **Triggers**: "work on {project}", "tackle {project}", "implement {project} tasks", "do tab project {name}", "continue {project}"

## Project Types

| | Personal |
|---|----------|
| **Workspace** | `~/workspaces/{project-slug}` |
| **Notes** | `{project-dir}/notes/` |
| **Branch** | `{project-slug}-{kebab}` |
| **Commit** | Short descriptive message |
| **Standards** | Language conventions + CLAUDE.md |
| **Verification** | `/tab-verify` (auto-detect) |
| **Never push** | Yes, user pushes |

---

## Tab as Source of Truth

| Concept | Tab |
|---------|-----|
| Project | Tab project (goal, requirements, design) |
| Plan | Tab tasks (all fields populated) |
| Task tracking | Tab task status (todo --> in_progress --> done) |
| Research notes | Local notes + Tab project design field |
| Progress log | Tab "Session Progress Log" document + local notes |
| Reference docs | Tab documents (shared KB, attached to projects) |

### Notes folder

Each project still gets a local folder for research and progress:
`~/workspaces/{project-slug}/notes/` or `./notes/` in the project directory.

| File | Purpose | Written when |
|------|---------|--------------|
| `research.md` | Codebase findings, approaches, tradeoffs | Step 1 (research sub-agent) |
| `progress.md` | Running journal of what was done | "Save our work" trigger |

The **plan lives in Tab tasks**, no separate `plan.md` needed.

---

## Orchestrator Discipline

Hard rules. No exceptions.

- **NEVER** read source code files (.py, .ts, .tsx, .js, .lua, etc.). Only read notes, CLAUDE.md, git state.
- **NEVER** use Edit, Write, or Bash to create or modify source code or tests.
- **NEVER** run tests, linters, or typecheckers directly. Delegate to agents or `/tab-verify`.
- **NEVER** do agent work when agents fail. Debug the issue and re-spawn instead.
- **NEVER** present agent deviations as positive design decisions without user approval.
- **NEVER** skip ceremony gates ("it's a small change"). Use a lightweight workflow instead.

**What the orchestrator CAN read/write:**
- Notes folder (`{project-dir}/notes/*`)
- CLAUDE.md files (for context on conventions)
- Git state (via Bash: `git status`, `git branch`, `git log`)
- Agent output summaries
- Tab project data (via MCP)

**The orchestrator's value is coordination, not implementation.** Every time it reads source code or writes code, it pollutes context with details it does not need, bypasses quality gates, and produces unreviewed output.

**When agents fail:**
- Agent runs out of turns: re-spawn with handoff report. Do NOT pick up the task.
- Agent produces incomplete results: send a follow-up or re-spawn with clearer instructions.
- Agent errors out: report to the user and ask how to proceed.

---

## Task Completeness -- REQUIRED

**GATE: ALL fields must be populated at task creation time, not backfilled later.**

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

**For done tasks:** `implementation` should include links (PR URLs, branch names) and a summary of what was built. `plan` should capture the approach and key decisions so future projects can reference the pattern.

**Before Step 4 begins, the orchestrator MUST:**
1. List all `todo` tasks for the project
2. Check each task has `implementation` and `acceptance_criteria` populated
3. If any task is missing fields, stop and fill them in (with user if needed)
4. Only proceed to implementation once all tasks pass the completeness check

---

## Automatic Session Progress Saves (applies to ALL steps)

Maintain a "Session Progress Log" Tab document for the active project. This section applies throughout the entire workflow.

**Initialization (synchronous, do once at session start):**
Call `mcp__tab-for-projects__list_documents({ project_id: "<pid>" })` and look for a document titled "Session Progress Log". If none exists, create one synchronously with `create_document` and store the returned ID.

**Save triggers:**
- **After each task marked done** -- append what was completed (background agent)
- **Before dispatching sub-agents** -- log what is about to happen. **This save MUST be synchronous** (crash recovery point).
- **After sub-agents return** -- log results and decisions (background agent)
- **On any blocker or significant decision** -- log context for future sessions (background agent)
- **Do not dispatch two progress-save agents concurrently.** Write a single combined entry after batches.

---

## Sub-Agent Architecture

The main conversation is an **orchestrator**. Heavy work is delegated to sub-agents.

| Agent | Role | Reads | Writes |
|-------|------|-------|--------|
| **Classifier** | Recommend workflow variant | Tab project data | Nothing (report only) |
| **Research** | Explore codebase, identify affected areas | Tab project, KB docs, codebase | `research.md` |
| **Planner** | Decompose work into tasks with plans and criteria | Tab project, KB docs, codebase | Tab tasks |
| **Implement** | Write code for a specific task | Tab tasks, KB docs, source files | Source code |
| **Test** | Write and run tests | Changed files, existing tests | Test files |
| **Code Reviewer** | Review against CLAUDE.md standards | All changed files | Nothing (report only) |
| **Acceptance QA** | Validate against acceptance criteria | Tab tasks, changed files | Nothing (report only) |
| **Edge Case QA** | Boundary conditions, error paths, race conditions | Changed files | Nothing (report only) |
| **Code Smells** | Fowler catalog smells, maintainability | Changed files (skips tests) | Nothing (report only) |
| **Test Reviewer** | Test quality, hollow assertions, over-mocking | Test files only | Nothing (report only) |
| **Documentarian** | Extract knowledge, update docs | Completed tasks, codebase | Tab documents |
| **Fix** | Apply fixes from review/QA findings | Review findings, source | Source fixes |
| **Verify** | Run lint/typecheck/tests | Changed files | Nothing (report only) |

### Rules for sub-agents
- Each gets a **self-contained prompt** with everything it needs
- Sub-agents **do not talk to the user**, only the orchestrator does
- Launch **parallel sub-agents** for independent tasks
- Pass **KB document IDs** to sub-agents (not full content), they fetch what they need
- Update Tab task status as work progresses

### Turn limit recovery

Add this note to every implementation/fix agent prompt:

> **Turn limit recovery:** When running low on turns (below ~20 remaining), stop and return a structured handoff report instead of trying to squeeze in more work.
>
> Handoff report format:
> - **Completed:** what is done
> - **In progress:** current state of unfinished work
> - **Remaining:** what still needs to happen
> - **Files changed:** list with one-line descriptions
> - **How to continue:** specific instructions for the next spawn (exact file, function, error, next step)
>
> The "how to continue" must be specific enough for the next spawn to pick up without re-reading the codebase.

The orchestrator re-spawns with the handoff report as context and remaining tasks only.

---

## Step 0: Load project from Tab

1. If user gives a project name, search with `mcp__tab-for-projects__list_projects`
2. Load the project (goal, requirements, design)
3. Load all tasks with `mcp__tab-for-projects__list_tasks` (filter by project_id)
4. **Load attached documents** with `mcp__tab-for-projects__list_documents({ project_id: "<pid>" })`, then `get_document` for each
5. Show the user a summary: project goal, task count by status, what is todo, attached documents

**Resuming a previous session:**
- Check for tasks stuck in `in_progress` status (stale from a prior session)
- Reset stale `in_progress` tasks back to `todo`, or ask the user what to do with them
- Read `notes/progress.md` if it exists for context on what was done before

If no Tab project exists yet, suggest running the **tab-brainstorming** skill first.

---

## Step 0.5: Route Workflow (classifier agent)

Spawn a **1-turn haiku classifier agent** that reads the project goal, requirements, design, and task list. It returns a workflow recommendation.

```
You are a workflow classifier. Read the project context below and recommend a workflow variant.

Project goal: {goal}
Requirements: {requirements}
Design: {design}
Task count: {count}
Task titles: {titles}

Return EXACTLY this format:

WORKFLOW PLAN

Workflow: standard | lightweight | thorough | custom
Rationale: {1-3 sentences}
Skipped: {what would be skipped and why, if any}
Flags: {risks or special considerations}

Classification signals:
- standard: multi-file change, 3+ tasks, database/API work, async code, cross-module
- lightweight: single file/module, 1-2 tasks, additive-only, config changes
- thorough: security-sensitive, new subsystem, public API changes
- custom: tests-only, refactor with no behavior change, docs-only

If uncertain, default to standard. A false "thorough" is better than a false "lightweight."
```

**Show the recommendation to the user.** They can override the workflow choice.

The workflow choice affects Step 4c (quality gate depth).

---

## Step 1: Research (sub-agent)

- **Check KB documents first**: Search `mcp__tab-for-projects__list_documents` for documents tagged with relevant domains. Load and pass to the research sub-agent as pre-existing context.
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
4. Check for nested CLAUDE.md files in directories you explore, note their presence/absence
5. Write findings to {project_dir}/notes/research.md
6. Return a 2-3 paragraph summary
```

**After research completes, sync to Tab:**

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

**Ensure test tasks exist.** If the project has no tasks with `category: "test"`, create them.

---

## Step 3: Create branch (main context)

- **Standard**: `{project-slug}-{short-description}` (e.g. `doot-initial-implementation`)
- No type prefix (no `feature/`, `fix/`, etc.)
- Branch from default (e.g. `main`). Confirm with user if ambiguous.
- If no git repo exists yet, offer to `git init`.

---

## Step 4: Execute (sub-agents)

### Pre-flight: Task Completeness Check

Before launching any sub-agent, verify ALL tasks pass the completeness gate:

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

### Design Sync

When a task with `category: "design"` is marked done, update the project's `design` field to reflect the decision. This prevents stale designs from misleading future sessions.

### Verification Loop

**Every time code changes, invoke the `tab-verify` skill.** It will:
1. Auto-detect project type and run appropriate checks (lint, typecheck, tests)
2. Create Tab bug tasks for any failures (`group_key: "verification-failures"`)
3. Dispatch fix sub-agents to resolve them
4. Re-verify until clean (max 3 cycles)

```
Implement --> /tab-verify --> Test --> /tab-verify --> Review --> Fix --> /tab-verify --> Commit
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

CLAUDE.md maintenance: When working in a directory, check if a CLAUDE.md exists at that level.
- If none exists: create a lean one (purpose, key files, patterns, dependencies)
- If one exists: update it if the work meaningfully changes the module's shape
- Skip for trivial changes (typos, renames)
- Keep it lean. Only non-obvious things that help future agents.

Turn limit recovery: If running low on turns (below ~20 remaining), stop and return a handoff report:
- Completed / In progress / Remaining / Files changed / How to continue
- "How to continue" must name the exact file, function, and next step.

Implement the changes. When done, return:
- List of files changed with one-line description each
- Any CLAUDE.md files created or updated (and why)
- Any questions or ambiguities
- Any deviations from the plan (and why)
```

**After each implementation agent returns:**

1. **Deviation detection.** Compare the agent's output against the Tab task plan. For each task the agent worked on, check: did it follow the implementation plan? If the agent deviated, report it clearly: "Plan said [A], agent did [B] because [reason]." NEVER present deviations positively. Ask the user to approve or fix. This matters because deviations can break assumptions other tasks depend on.

2. **Run `/tab-verify`.** Mark task `done` in Tab if verification passes.

### 4b. Test sub-agent

Mark the test task `in_progress` in Tab before launching.

```
You are writing tests for the {project_title} project.

Files changed: {list from implementation}
Tasks implemented: {task titles}

Write tests covering: happy path, edge cases, error paths.
Run tests and report pass/fail.

Turn limit recovery: If running low on turns, return a handoff report
with Completed / In progress / Remaining / Files changed / How to continue.
```

**Run verification. Mark test task `done` in Tab.**

### 4c. Quality Gate -- MANDATORY

**GATE: MUST run before commit. Even for small changes.**

The workflow variant (from Step 0.5) determines the quality gate depth.

#### Standard workflow -- 5 parallel review agents:

1. **Code Reviewer** (sonnet) -- reviews against CLAUDE.md standards, returns file:line findings with severity (critical/high/medium/low)
2. **Acceptance QA** (haiku) -- reads each Tab task's acceptance_criteria, returns per-criterion PASS/PARTIAL/FAIL with evidence
3. **Edge Case QA** (sonnet) -- boundary conditions, null handling, error paths, race conditions, async edge cases. Risk levels: critical/high/medium/low
4. **Code Smells** (sonnet) -- Fowler catalog smells (long methods, feature envy, data clumps, coupling). Skips test files. Severity: high/medium/low
5. **Test Reviewer** (sonnet) -- **only spawns if changeset includes test files.** Catches hollow assertions, over-mocking, AI-generated test smells (mirror structure, narration comments, verbose setup, defensive over-assertion)

#### Lightweight workflow -- 2-3 agents:

- Code Reviewer + Code Smells + Test Reviewer (if tests present)

#### Thorough workflow -- standard + extras:

- All 5 standard agents + Documentarian agent

#### Dynamic specialist agents (conditional):

Spawn additional reviewers when the changeset contains specific artifact types:

| Artifact | Trigger | Agent Focus |
|----------|---------|-------------|
| Claude/AI skill files | Any SKILL.md or agent def modified | Trigger accuracy, correctness vs codebase |
| Database migrations | Any migration file | Schema safety, rollback plan, data loss risk |
| CI/CD config | Any workflow/pipeline change | Correctness, security, performance |
| Docker/infra | Dockerfile, compose files | Security, layer efficiency, env leaks |

These spawn in parallel alongside the standard/lightweight agents.

**After all agents return:**
1. Deduplicate findings at the same file:line (keep higher severity)
2. Sort: critical > high > medium > low
3. Consolidate into a single findings list

### 4c-walk. Finding Walk-Through -- MANDATORY

After consolidating findings, walk through them **one at a time**. Never batch all findings into one question.

For each finding:
1. Present it individually: number, severity, file:line, description, which agent found it
2. Ask: **"Fix, defer, or disagree?"**
3. If a finding is related to a previous one, cross-reference it
4. If a finding would be covered by another's fix, note that and offer to skip

After the walk-through, present the final list of findings the user chose to fix.

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

### 4c-post. Create Tab tasks from findings

When the review agents return findings that the user chose to fix, the orchestrator creates Tab tasks for each:

```
mcp__tab-for-projects__create_task({
  items: findings.map(f => ({
    project_id: "<pid>",
    title: "Fix: {short description of finding}",
    description: "**File:** {file}:{line}\n**Issue:** {what's wrong}\n**Suggested fix:** {fix}",
    implementation: "File: {file}:{line}\nChange: {description of what to change}",
    acceptance_criteria: "- Finding resolved\n- Verification clean after fix",
    category: "bugfix",
    effort: "trivial",
    impact: "medium",
    group_key: "review-findings"
  }))
})
```

If the review returns **no findings**, create a single task recording a clean review:
```
mcp__tab-for-projects__create_task({
  items: [{
    project_id: "<pid>",
    title: "Code review: passed clean",
    description: "No actionable findings from code review",
    implementation: "Ran quality gate on all changed files. No actionable findings.",
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

Turn limit recovery: If running low on turns, return a handoff report
with Completed / In progress / Remaining / Files changed / How to continue.
```

**Run verification.**
**Mark fixed tasks as `done` in Tab. Any deferred findings stay as `todo`.**

### 4e. Verification sub-agent

```
Verify {project_title} changes on branch {branch}.

Run project checks and report pass/fail for each.
Do NOT fix anything, just report.
```

---

## Step 5: Commit (main context)

**Run the full commit gate:** Invoke `/tab-verify --commit-gate` for the project. This checks both technical (lint, typecheck, tests) and workflow (review findings resolved, QA findings resolved, all tasks done, no governance items) gates in one pass.

If the commit gate fails, fix the issues first. The user can explicitly defer workflow items, but technical failures must be resolved.

Once the gate passes:
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

Skip this step if the work was purely mechanical (simple bugfix with no novel patterns).

---

## Step 5.6: Documentation health check

Check if the implementation changed anything that documentation should reflect:

1. **README.md** -- still accurate? New commands/features documented? Install instructions correct?
2. **Tab project design field** -- reflects what was actually built?
3. **Tab KB documents** -- attached documents still accurate? New patterns established that are not documented?
4. **Code comments** -- any TODO/FIXME/HACK comments added that need Tab tasks?

Spawn a background agent to audit. If it finds issues, present them:

> "Found {N} documentation updates needed. Want to tackle them now or add them to the backlog?"

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

1. **Update Tab task statuses** to reflect current state (any in-flight work stays `in_progress`)
2. **Update Tab project** design field if design evolved during the session
3. **Back up Tab database** to Google Drive:
   ```
   ~/.local/bin/tab-db-backup.sh
   ```
4. If there are uncommitted changes, offer to commit

---

## Parallel opportunities

**Can parallelize:**
- Independent Tab tasks (different group_keys, no dependencies)
- Tests for completed code while implementing next task
- All quality gate agents (by design)

**Must be sequential:**
- Research --> Plan --> Branch --> Implement --> Verify --> Test --> Verify --> Review --> Walk-through --> Fix --> Verify --> Commit

---

## Tab MCP Quick Reference

```python
# Projects
mcp__tab-for-projects__list_projects()
mcp__tab-for-projects__list_projects({ id: "<project_id>" })
mcp__tab-for-projects__create_project({ items: [{ title, goal, requirements, design }] })
mcp__tab-for-projects__update_project({ items: [{ id, goal, requirements, design }] })

# Tasks (ALL fields required at creation)
mcp__tab-for-projects__list_tasks({ project_id: "<id>" })
mcp__tab-for-projects__list_tasks({ project_id: "<id>", status: "todo" })
mcp__tab-for-projects__list_tasks({ project_id: "<id>", group_key: "core" })
mcp__tab-for-projects__create_task({
  items: [{
    project_id, title, description, implementation,
    acceptance_criteria, category, effort, impact, group_key
  }]
})
mcp__tab-for-projects__update_task({
  items: [{ id, project_id, status, implementation, acceptance_criteria }]
})

# Documents (Knowledge Base)
mcp__tab-for-projects__list_documents({ project_id: "<id>" })
mcp__tab-for-projects__get_document({ id: "<doc_id>" })
mcp__tab-for-projects__create_document({ items: [{ title, content, tags: ["tag"] }] })
mcp__tab-for-projects__update_document({ items: [{ id, content, tags }] })

# Attach/detach documents
mcp__tab-for-projects__update_project({
  items: [{ id: "<pid>", attach_documents: ["<doc_id>"] }]
})
```

---

## References

- **Tab brainstorming**: tab-brainstorming skill (idea --> design --> Tab project + tasks)
- **Verification**: tab-verify skill (auto-detect project type, run checks, create bug tasks)

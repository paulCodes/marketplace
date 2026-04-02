---
name: tab-refinement
description: "Facilitate backlog refinement — walk through Tab project tasks with the user to ensure they're understood, well-specified, and actionable before implementation. Use when user says 'refine', 'groom', 'review backlog', or before starting /tab-work on a project."
---

# Tab Refinement

Facilitate a backlog refinement session — walk through Tab project tasks to ensure they're understood, well-specified, and actionable before implementation begins.

## When to use

- `/tab-refinement` — before starting implementation on a Tab project
- User says "refine tasks", "groom the backlog", "review tasks before we start"
- Between `/tab-brainstorming` (design) and `/tab-work` (implementation)

## Step 1: Resolve project

1. If user provides a project name, search with `mcp__tab-for-projects__list_projects`
2. Load the project (goal, requirements, design)
3. Load attached documents with `mcp__tab-for-projects__list_documents({ project_id: "<pid>" })`

## Step 2: Load active backlog

```
mcp__tab-for-projects__list_tasks({ project_id: "<pid>", status: "todo" })
mcp__tab-for-projects__list_tasks({ project_id: "<pid>", status: "in_progress" })
```

Present an overview:
- Project name and goal
- Task count by status
- Scannable task list (title + effort + category)
- Call out **under-specified tasks** (missing implementation, acceptance_criteria, or effort)

## Step 3: Refinement loop

Walk through each task with the user. For each task:

### 3a. Present the task

Load full details with `mcp__tab-for-projects__get_task({ id: "<task_id>" })`. Show:
- Title and description
- Current effort/impact estimates
- Plan and implementation (if populated)
- Acceptance criteria (if populated)
- **Gaps** — highlight missing or vague fields

### 3b. Discuss and research

This is conversational — follow the user's energy:
- Clarify intent: "What does this actually need to do?"
- Validate scope: "Is this one task or should we split it?"
- Identify unknowns: "Do we know how X works yet?"
- **Spawn research agents in background** when you hit unknowns:

```
Agent(
  description: "Research {unknown}",
  prompt: "Investigate {specific question} in the codebase at {project_dir}. Return findings.",
  subagent_type: "Explore",
  run_in_background: true
)
```

Don't guess — investigate.

- Estimate effort with the user
- Define "done" — what are the acceptance criteria?

### 3c. Update task immediately

Write refinements to Tab as you go — don't wait for end of session:

```
mcp__tab-for-projects__update_task({
  items: [{
    id: "<task_id>",
    description: "{refined description}",
    implementation: "{refined implementation plan}",
    acceptance_criteria: "{refined criteria}",
    effort: "{updated effort}",
    impact: "{updated impact}"
  }]
})
```

## Step 4: Backlog health check

After walking through tasks, assess the overall backlog:
- **Duplicates/overlap?** — merge or clarify boundaries
- **Gaps?** — missing tasks that the design implies but aren't captured
- **Ordering?** — are group_keys logical? Should tasks be reordered?
- **Dependencies?** — note if task B can't start until task A is done (capture in description)

Create new tasks for any gaps discovered:

```
mcp__tab-for-projects__create_task({
  items: [{
    project_id: "<pid>",
    title: "Gap: {what's missing}",
    description: "Discovered during refinement: {context}",
    category: "{appropriate}",
    effort: "{estimate}",
    impact: "{estimate}",
    group_key: "{appropriate group}"
  }]
})
```

## Step 5: QA check (optional)

If the user wants a thorough gap analysis, spawn the QA agent:

```
Agent(
  description: "QA gap check for {project}",
  prompt: "You are the QA agent for the '{project_title}' project (ID: {pid}).

  Validate the backlog for completeness:
  1. Fetch all todo tasks
  2. Check each task has: description, implementation plan, acceptance criteria
  3. Look for gaps between the project design and the task list
  4. Create new tasks for any gaps found (group_key: 'qa-findings')
  5. Return a summary of findings",
  run_in_background: true
)
```

## Step 6: Wrap up

Summarize what changed:
- Tasks refined (count)
- Tasks created (gaps found)
- Tasks still needing attention
- Note if any background agents are still running

> "Backlog refined. {N} tasks ready for implementation. Run `/tab-work` when you're ready to start."

## Principles

- **Conversational, not mechanical** — follow the user's energy, don't force every task through a checklist
- **Update MCP in real-time** — every decision written immediately (session crash = partial progress saved)
- **Spawn research agents on unknowns** — don't guess, investigate
- **One task at a time** — depth over breadth
- **Respect the user's time** — if a task is already well-specified, say so and move on

---
name: tab-feedback
description: "Generate a Tab for Projects feedback report. Compiles raw API logs, session observations, feature requests, and friction points into a clean markdown file the Tab creator can use to create a project. Invoke with /tab-feedback to generate the report."
---

# Tab Feedback Report Generator

Compile Tab for Projects feedback into a structured markdown report that the Tab creator can import as a project.

## When to invoke

- `/tab-feedback` — generate or update the feedback report
- End of a session that heavily used Tab
- When the user says "generate tab feedback", "update tab feedback", "what do we have for tab"

## The Feedback File

Reports are dated: `~/.claude/tab-feedback/{YYYY-MM-DD}-report.md`

Each run creates a new dated file (never overwrites previous reports). Hand it to the Tab creator and he can create a Tab project from it.

## Generating the Report

When invoked:

1. **Read raw API logs** from `~/.claude/tab-feedback/{YYYY-MM-DD}.jsonl` (dated files)
   - Check for today's file and recent days' files
   - Count total calls per tool
   - Identify errors and what caused them
   - Note which tools are used most/least
   - **Error attribution warning**: Errors with `request-id` format `req_...` and body `{"type":"error","error":{"type":"api_error"}}` are from the **Anthropic API** (Claude's own backend), NOT from Tab. Tab MCP errors have a different format. Do NOT attribute Anthropic API errors to Tab in the feedback report.

2. **Create today's feedback report** at `~/.claude/tab-feedback/{YYYY-MM-DD}-report.md`
   - Each day gets its own report — never overwrite previous days

3. **Review the current session** — think about:
   - What Tab features did we use? What worked well?
   - Where did we hit friction? What was the workaround?
   - What features are missing that we had to build around?
   - What would make the workflow smoother?
   - Any API ergonomic issues (field limits, missing filters, etc.)?

4. **Write/update the report** in this format:

```markdown
# Tab for Projects — Feedback Report

Generated: {date}
Sessions reviewed: {count}

## What's Working Great
- {things that work well and should not change}

## Feature Requests

### {Feature Name}
**Priority:** high / medium / low
**Context:** {what we were doing when we needed this}
**Current workaround:** {what we do instead}
**Suggestion:** {what we'd like to see}

## Friction Points

### {Issue}
**Severity:** blocker / annoying / minor
**Context:** {when this happens}
**Details:** {what goes wrong}
**Suggestion:** {how to fix}

## API Ergonomics

### {Observation}
**Tool:** {which MCP tool}
**Issue:** {what's awkward}
**Suggestion:** {improvement}

## Usage Patterns
- Most used tools: {from JSONL logs}
- Least used tools: {from JSONL logs}
- Error rate: {from JSONL logs}
- Common filter combinations: {from JSONL logs}

## Wish List
- {things that would be amazing but aren't critical}
```

## Known Feedback to Seed

These are observations from building the Tab workflow skills:

### Feature Requests — Already Identified

1. **Task dependencies (blocked_by / blocks)**
   - Priority: high
   - Context: During tab-work, we sequence tasks manually because there's no way to express "task B depends on task A"
   - Workaround: We use group_keys and manual ordering in the skill instructions
   - Suggestion: Add `blocked_by: [task_id]` and `blocks: [task_id]` fields to tasks

2. **Task assignment (owner field)**
   - Priority: medium
   - Context: When dispatching parallel sub-agents, we want to track which agent owns which task
   - Workaround: We use Claude Code's internal TaskCreate for in-session tracking
   - Suggestion: Add an `owner` or `assigned_to` string field to tasks

3. **Project status field**
   - Priority: medium
   - Context: No way to mark a project as active/done/archived at the project level
   - Workaround: We infer status from task completion counts
   - Suggestion: Add `status` field to projects (e.g. active, completed, archived)

4. **Agents/Jobs not yet wired**
   - Priority: low (for now)
   - Context: We registered 6 agent blueprints but can't dispatch jobs yet
   - Workaround: We use Claude Code's native Agent tool for sub-agents
   - Suggestion: Wire up the job lifecycle (todo → running → done/failed) so skills can dispatch and track agent work through Tab

### Friction Points — Already Identified

1. **No way to query tasks by multiple group_keys**
   - Severity: minor
   - Context: Commit gate needs to check both "review-findings" and "verification-failures" groups
   - Workaround: Two separate list_tasks calls
   - Suggestion: Support `group_key` as array or comma-separated filter

### What's Working Great — Already Identified

- Project CRUD is clean and fast
- Task filtering by status, group_key, and category is exactly what we need
- All task fields (implementation, acceptance_criteria, effort, impact) are well-designed
- The `group_key` concept is perfect for organizing different types of work within a project
- Batch operations (creating multiple tasks in one call) are efficient

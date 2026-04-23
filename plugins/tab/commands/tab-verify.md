---
name: tab-verify
description: "Run verification checks (lint, typecheck, tests), create Tab bug tasks for any failures, and dispatch sub-agents to fix them. Use anytime with /tab-verify to check code health and auto-triage failures into Tab."
---

# Tab Verify

Run project verification checks, create Tab tasks for failures, and dispatch fix sub-agents. Works standalone or as part of the tab-work workflow.

## When to use

- `/tab-verify` — run checks anytime
- After any code change during tab-work
- Before committing
- To check overall project health

## How it works

```
Run checks → Parse failures → Create Tab bug tasks → Dispatch fix agents → Re-verify
                                                          ↑ still failing
                                                          └── re-fix ──┘
```

## Verification staleness

A verification result is stale the moment any file changes. Never trust a previous run after:
- An implementation agent modified files
- A fix agent applied changes
- Test files were added or modified
- Review findings were fixed

When in doubt, re-run. Verification is cheap compared to a rollback.

## Step 1: Detect project and Tab context

1. Identify the project type and verification commands:
   - **TypeScript/Node**: `npx eslint {files}` → `npm run typecheck` → `npm run test:unit`
   - **Python**: `make lint` or `ruff check` → `make typecheck` or `mypy` → `make test` or `pytest`
   - **Go**: `go vet ./...` → `go test ./...`
   - **Other**: Look for Makefile, package.json scripts, or ask user

2. Find the active Tab project:
   - `mcp__tab-for-projects__list_projects()` → match by project name or ask user
   - If no Tab project exists, run checks anyway but skip Tab task creation

3. **Check for troubleshooting documents**: Search `mcp__tab-for-projects__list_documents({ tag: "troubleshooting" })` for known issue patterns. If verification failures match a documented issue, include the fix from the document instead of dispatching a generic fix agent.

## Step 2: Run all checks

Run each check and capture output:

```bash
# Example for TypeScript
npx eslint {changed_files}     # → lint results
npm run typecheck               # → type errors
npm run test:unit               # → test results
```

**Parse each failure into a structured finding:**
- **Check type**: lint / typecheck / test
- **File**: path and line number
- **Error**: the specific error message
- **Rule/code**: eslint rule, TS error code, or test name

## Step 3: Report results

Show the user a summary:

```
Tab Verify Results:
  Lint:      3 errors
  Typecheck: 1 error
  Tests:     2 failures
  ──────────
  Total:     6 issues → creating Tab tasks
```

If all checks pass:
```
Tab Verify Results:
  Lint:      ✓ clean
  Typecheck: ✓ clean
  Tests:     ✓ all passing
  ──────────
  All clear — no tasks to create.
```

## Step 4: Create Tab bug tasks for each failure

**Group by check type using `group_key`:**

```
mcp__tab-for-projects__create_task({
  items: failures.map(f => ({
    project_id: "<pid>",
    title: "Fix: {short description}",
    description: "**Check:** {lint|typecheck|test}\n**File:** {file}:{line}\n**Error:** {error_message}\n**Rule:** {rule_or_code}",
    implementation: "Suggested fix based on the error",
    acceptance_criteria: "- {specific check} passes for this file\n- No regressions introduced",
    category: "bugfix",
    effort: "trivial",
    impact: "high",
    group_key: "verification-failures"
  }))
})
```

**Consolidate related failures:** If multiple errors are in the same file and likely the same root cause, create ONE task covering all of them instead of one per error.

## Step 5: Dispatch fix sub-agents

Launch sub-agents to fix the failures. Mark each task `in_progress` before launching.

**Strategy:**
- **Independent failures** (different files, different causes) → parallel sub-agents
- **Related failures** (same file, cascading errors) → single sub-agent

```
You are fixing verification failures for the {project_title} project.

Failures to fix:
{list from Tab tasks with group_key "verification-failures", status "todo"}

For each failure:
1. Read the file and understand the error
2. Apply the minimal fix
3. Run the specific check to confirm it passes

Return: list of fixes applied, any that couldn't be fixed and why.
```

**KB-assisted fixes:** Before dispatching fix agents, check if any `troubleshooting` documents match the failure pattern. If so, include the document content in the fix agent's prompt:

```
Known fix from KB document "{doc_title}":
{document_content}

Apply this known fix first. Only investigate further if it doesn't resolve the issue.
```

**→ Mark fixed tasks `done` in Tab.**

## Step 6: Re-verify

After all fix agents complete, re-run ALL checks (not just the ones that failed):

```bash
npx eslint {changed_files}
npm run typecheck
npm run test:unit
```

- **All pass**: Report success, done
- **New failures**: Go back to Step 4 (create new tasks, dispatch new fix agents)
- **Max 3 fix cycles** — if still failing after 3 rounds, stop and ask the user

## Step 7: Update KB with new troubleshooting knowledge

If a verification failure required a **non-obvious fix** that would help future projects, create a troubleshooting document:

```
mcp__tab-for-projects__create_document({
  items: [{
    title: "Fix: {short description of the issue}",
    content: "## Symptom\n{error message}\n\n## Cause\n{root cause}\n\n## Fix\n{solution}",
    tags: ["troubleshooting"]
  }]
})
```

Skip this for routine fixes (typos, missing imports, etc.). Only document patterns that would save time if encountered again.

## Commit Gate Mode

When invoked with `--commit-gate` or called from tab-work Step 5, run the FULL pre-commit checklist. This goes beyond lint/typecheck/tests to verify the entire workflow completed correctly.

### The checklist

```
Commit Gate -- {project_title}

Technical:
- [ ] Lint passes on all changed files
- [ ] Typecheck passes
- [ ] Tests pass (unit + integration if applicable)
- [ ] No verification-failures tasks remain open

Workflow:
- [ ] Quality gate ran (review agents were dispatched)
- [ ] All review-findings tasks are done or deferred
- [ ] All qa-findings tasks are done or deferred
- [ ] All implementation tasks marked done in Tab
- [ ] No unaddressed [GOVERNANCE] items

Staleness:
- [ ] Verification ran after the most recent code change
```

### How it checks workflow items

Query Tab for each workflow gate:

```
# Unresolved verification failures
mcp__tab-for-projects__list_tasks({ project_id: "<pid>", group_key: "verification-failures", status: "todo" })

# Unresolved review findings
mcp__tab-for-projects__list_tasks({ project_id: "<pid>", group_key: "review-findings", status: "todo" })

# Unresolved QA findings
mcp__tab-for-projects__list_tasks({ project_id: "<pid>", group_key: "qa-findings", status: "todo" })

# Tasks still in progress
mcp__tab-for-projects__list_tasks({ project_id: "<pid>", status: "in_progress" })
```

### Presenting the checklist

Show the full checklist with pass/fail for each item. If any item fails:
- Technical failures: offer to fix (standard verify flow)
- Workflow failures: tell the user what's missing and how to resolve it
- Staleness failures: offer to re-run verification

**The commit gate MUST pass before committing.** If the user overrides, note it in the Session Progress Log as an explicit override.

## Integration with tab-work

tab-work invokes tab-verify at these points:
- After Step 4a (implementation) -- verify implementation compiles and passes
- After Step 4b (tests) -- verify new tests pass
- After Step 4d (review fixes) -- verify fixes don't introduce regressions
- **Step 5 (commit)** -- invoke with `--commit-gate` for the full pre-commit checklist

When called without `--commit-gate`, tab-verify runs technical checks only (lint, typecheck, tests). The commit gate adds workflow checks (review findings, QA findings, task statuses).

## Standalone usage

When invoked standalone (not part of tab-work):
1. Auto-detect project type from current directory
2. Find or ask for Tab project
3. Run checks, create tasks, fix, re-verify
4. Show final status

```
/tab-verify                    # run all checks
/tab-verify --commit-gate      # full pre-commit checklist (technical + workflow)
/tab-verify --lint-only        # just lint
/tab-verify --tests-only       # just tests
/tab-verify --no-fix           # report only, don't dispatch fix agents
```

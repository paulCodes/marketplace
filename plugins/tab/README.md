# Tab Workflow Plugin (v2.0.0)

A Claude Code plugin that turns [Tab for Projects](https://github.com/4lt7ab/Tab) into a full project lifecycle manager. One command (`/tab`) routes between brainstorming, refinement, implementation, code review, PR review, and verification, with all state persisted in Tab.

This is not a wrapper around `git commit`. It is a multi-agent orchestration system that manages research, planning, parallel implementation, a 5-agent quality gate, finding walk-throughs, deviation detection, crash recovery, and knowledge extraction across your entire project lifecycle.

## Three-Tier Architecture

The plugin uses three layers that work together:

| Layer | File | When it runs | What it does |
|-------|------|--------------|--------------|
| **Rule** | `tab-discipline.md` | Every session (always on) | Enforces Tab-first behavior: load context before work, save incrementally, maintain progress logs |
| **Router** | `tab.md` (`/tab`) | When you invoke `/tab` | Loads your project, detects intent, routes to the right workflow |
| **Sub-skills** | `tab-work.md`, `tab-verify.md`, etc. | When the router dispatches | Detailed workflow playbooks for each phase |

## Commands

| Command | Description | When to use |
|---------|-------------|-------------|
| `/tab` | **Unified entry point.** Detects project and intent, routes automatically. | Always. This is the main command. |
| `/tab-brainstorming` | Ideas to designs to Tab project (direct access) | Skip the router for brainstorming |
| `/tab-refinement` | Walk through tasks to ensure they are well-specified | Direct access to refinement |
| `/tab-work` | Load project, dispatch agents, implement tasks | Direct access to implementation |
| `/tab-verify` | Lint/typecheck/tests with auto-fix loop and commit gate | Direct access to verification |
| `/tab-pr-review` | Multi-agent PR review with voice-controlled comment posting | Review PRs with parallel agents |
| `/tab-feedback` | Compile feedback report for Tab creator | Alpha testing feedback |

### Using `/tab` (recommended)

```
/tab                              Show project status, ask what to do
/tab I want to build X            Start brainstorming
/tab work on doot                 Implement a project
/tab continue                     Resume where you left off
/tab verify                       Run checks
/tab save                         Save progress
/tab refine                       Review backlog
```

## The Lifecycle

A project flows through these phases:

```
Brainstorm --> Refine --> Implement --> Verify --> Review --> Commit
     ^                                                  |
     +------------ Tab has full state at every step ----+
```

### Brainstorm

`/tab I have an idea for X`

- Collaborative dialogue: one question at a time, multiple choice when possible
- Creates a draft Tab project immediately (crash recovery from the first minute)
- Proposes 2-3 approaches with trade-offs
- Saves KB documents as discoveries happen, not at the end
- Produces: Tab project with goal, requirements, design, and task backlog

### Refine

`/tab refine` or auto-detected when tasks lack detail

- Walks through each task to ensure it is well-specified
- Spawns research agents for unknowns instead of guessing
- Updates Tab tasks in real-time as decisions are made
- Every task gets: description, implementation plan, acceptance criteria, effort, impact

### Implement

`/tab work on X` or `/tab continue`

The implementation orchestrator is the core of the plugin. It never writes code itself. Instead, it coordinates sub-agents while tracking all progress in Tab.

**Workflow routing.** A classifier agent reads the project context and recommends one of four workflow variants:

| Variant | When | Quality gate depth |
|---------|------|--------------------|
| **Standard** | Multi-file changes, 3+ tasks, cross-module work | 5 parallel review agents |
| **Lightweight** | Single file/module, 1-2 tasks, config changes | 2-3 agents (code review + smells + test review) |
| **Thorough** | Security-sensitive, new subsystems, public API changes | Standard + documentarian |
| **Custom** | Tests-only, refactor with no behavior change, docs-only | Tailored to the scope |

The user can override the recommendation.

**5-agent quality gate.** Before any commit, the plugin runs parallel review agents:

1. **Code Reviewer** validates against CLAUDE.md standards
2. **Acceptance QA** checks each Tab task's acceptance criteria (PASS/PARTIAL/FAIL with evidence)
3. **Edge Case QA** probes boundary conditions, null handling, race conditions, error paths
4. **Code Smells** runs Fowler catalog analysis (skips test files)
5. **Test Reviewer** catches hollow assertions, over-mocking, and AI-generated test smells (only spawns when tests are in the changeset)

**Dynamic specialist agents.** Additional reviewers spawn automatically when the changeset contains specific artifacts:

| Artifact | Trigger | Focus |
|----------|---------|-------|
| Claude/AI skill files | Any SKILL.md or agent definition modified | Trigger accuracy, codebase correctness |
| Database migrations | Any migration file | Schema safety, rollback plan, data loss risk |
| CI/CD config | Any workflow/pipeline change | Correctness, security, performance |
| Docker/infra | Dockerfile, compose files | Security, layer efficiency, env leaks |

**Finding walk-through.** After review agents return, findings are deduplicated, sorted by severity, and presented one at a time. For each finding, you choose: fix, defer, or disagree. Related findings are cross-referenced. Findings covered by another fix are flagged so you can skip them. No batching everything into one wall of text.

**Agent deviation detection.** After each implementation agent returns, the orchestrator compares its output against the Tab task plan. Deviations are reported clearly ("Plan said A, agent did B because reason") and never presented as positive design decisions. You approve or reject.

**Turn limit recovery.** Every implementation and fix agent includes a handoff protocol. When an agent runs low on turns, it stops and returns a structured report (completed, in progress, remaining, files changed, how to continue). The orchestrator re-spawns with that context. No work is lost.

### Verify

`/tab-verify` or automatically after every code change

- Auto-detects project type (TypeScript, Python, Go, etc.)
- Runs lint, typecheck, and tests
- Creates Tab tasks for each failure
- Dispatches fix agents and re-verifies (max 3 cycles)
- Checks KB for known troubleshooting patterns before dispatching generic fix agents

**Commit gate mode** (`/tab-verify --commit-gate`): Goes beyond technical checks to verify the full workflow completed correctly.

```
Commit Gate

Technical:
- [ ] Lint passes on all changed files
- [ ] Typecheck passes
- [ ] Tests pass
- [ ] No verification-failures tasks remain open

Workflow:
- [ ] Quality gate ran (review agents were dispatched)
- [ ] All review-findings tasks are done or deferred
- [ ] All qa-findings tasks are done or deferred
- [ ] All implementation tasks marked done in Tab
- [ ] No unaddressed governance items

Staleness:
- [ ] Verification ran after the most recent code change
```

### PR Review

`/tab-pr-review {url}` or `/tab-pr-review` for dashboard

A standalone multi-agent PR review pipeline:

- **Dashboard mode**: shows all open PRs across repos, numbered for quick selection
- **Review mode**: 5-7 parallel agents analyze the diff (edge case QA, acceptance QA, researcher, code reviewer, code smells, test reviewer, dynamic specialists)
- **Tab project lookup**: when a Tab project matches the PR, acceptance criteria from Tab tasks are used to verify the code, not just the PR description
- **Finding walk-through**: same one-at-a-time protocol as the implementation quality gate
- **Voice-controlled posting**: comments are drafted in a human voice (no AI tells, no em dashes, no "Hey!" openers), reviewed by you, then batch-posted via the GitHub API
- **Backport detection**: recognizes cherry-picks targeting release branches and offers skip, quick diff, or full review

### Crash Recovery

The plugin is designed to survive session crashes:

- Draft projects are created at the start of brainstorming, not after approval
- Tab is updated after every state change (questions, decisions, task completions)
- Session Progress Log is updated synchronously before dispatching sub-agents
- On resume, stale `in_progress` tasks are detected and the user is asked what to do

### Knowledge Base

Reusable knowledge (architecture patterns, API limitations, conventions, troubleshooting) is saved as Tab documents and attached to projects. KB docs are saved immediately when discoveries happen, not gated on session end or design approval. Troubleshooting documents are checked before dispatching fix agents so known issues get resolved faster.

## Agents

These are spawned by the workflow commands. You do not invoke them directly.

| Agent | Role | Spawned by |
|-------|------|-----------|
| `planner` | Decompose work into tasks with plans and acceptance criteria | tab-work, tab-refinement |
| `qa` | Validate work against plans, find gaps, create qa-findings tasks | tab-work, tab-refinement |
| `documenter` | Extract knowledge from completed work into Tab KB documents | tab-work |

The workflows also spawn purpose-built agents at runtime: classifier, research, implement, test, code reviewer, acceptance QA, edge case QA, code smells, test reviewer, fix, and verify. These are defined inline in the workflow prompts, not as separate files.

## Prerequisites

- **[Tab for Projects](https://github.com/4lt7ab/Tab)** MCP server running locally (default: `http://localhost:5069/mcp`)
- **Claude Code** with MCP support

## Install

### Via Claude Code marketplace (recommended)

```bash
claude plugin marketplace add paulCodes/marketplace
claude plugin install tab-workflow
```

### Manual install

```bash
git clone git@github.com:paulCodes/marketplace.git ~/workspaces/marketplace

# Copy commands
cp ~/workspaces/marketplace/plugins/tab/commands/*.md ~/.claude/commands/

# Copy agents
mkdir -p ~/.claude/agents
cp ~/workspaces/marketplace/plugins/tab/agents/*.md ~/.claude/agents/

# Copy rules
cp ~/workspaces/marketplace/plugins/tab/rules/*.md ~/.claude/rules/
```

## Alpha Testing

If you are helping test Tab for Projects, the plugin includes hooks for automatic feedback collection. The `tab-alpha-testing.md` rule observes Tab API interactions in-session. The steps below add hook scripts for automated log capture.

### Install feedback hooks

**Mac/Linux:**
```bash
cp ~/workspaces/marketplace/plugins/tab/scripts/tab-feedback-logger.sh ~/.claude/hooks/
cp ~/workspaces/marketplace/plugins/tab/scripts/tab-feedback-summary.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/tab-feedback-*.sh
```
Requires `jq` (`brew install jq`).

**Windows (PowerShell):**
```powershell
Copy-Item ~/workspaces/marketplace/plugins/tab/scripts/tab-feedback-logger.ps1 ~/.claude/hooks/
Copy-Item ~/workspaces/marketplace/plugins/tab/scripts/tab-feedback-summary.ps1 ~/.claude/hooks/
```

### Configure hooks in settings.json

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "mcp__tab-for-projects__*",
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/tab-feedback-logger.sh",
        "timeout": 5
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "~/.claude/hooks/tab-feedback-summary.sh",
        "timeout": 5
      }]
    }]
  }
}
```

Windows: replace `.sh` with `.ps1` and prefix with `powershell -File `.

### Generate feedback

Run `/tab-feedback` to compile observations. All feedback lives in `~/.claude/tab-feedback/`:

```
~/.claude/tab-feedback/
  2026-04-03.jsonl          (raw API logs)
  2026-04-03-report.md      (compiled report)
  2026-04-04.jsonl
  2026-04-04-report.md
```

Dated files, nothing gets overwritten.

## Architecture

```
marketplace/
  plugins/tab/
    commands/
      tab.md                  Unified router (entry point)
      tab-brainstorming.md    Brainstorm flow (incremental saves)
      tab-work.md             Implementation orchestrator (workflow routing, quality gate)
      tab-verify.md           Verification + commit gate + auto-fix loop
      tab-refinement.md       Backlog grooming
      tab-pr-review.md        Multi-agent PR review with voice-controlled posting
      tab-feedback.md         Feedback report compiler
    agents/
      planner.md              Task decomposition
      qa.md                   Work validation
      documenter.md           Knowledge extraction
    rules/
      tab-discipline.md       Always-on Tab-first discipline
      tab-alpha-testing.md    Feedback collection (optional)
    scripts/
      tab-feedback-logger.*   PostToolUse hook
      tab-feedback-summary.*  Stop hook
```

## Credits

Built on [Tab for Projects](https://github.com/4lt7ab/Tab) by [@4lt7ab](https://github.com/4lt7ab).

Skill architecture inspired by [Everything Claude Code](https://github.com/affaan-m/everything-claude-code) patterns (three-tier: rules, skills, agents).

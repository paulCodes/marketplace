# Tab for Projects Plugin (v1.1.0)

A Claude Code plugin that turns [Tab for Projects](https://github.com/4lt7ab/Tab) into a complete project lifecycle manager. One command (`/tab`) handles everything — brainstorming, refinement, implementation, verification, and progress tracking.

## How the Workflow Works

### The Three-Tier Architecture

The plugin uses three layers that work together:

| Layer | File | When it's active | What it does |
|-------|------|-------------------|--------------|
| **Rule** | `tab-discipline.md` | Every session (always on) | Enforces Tab-first behavior: load context before work, save incrementally, maintain progress logs |
| **Router** | `tab.md` (`/tab`) | When you invoke `/tab` | Loads your project, detects what you want to do, routes to the right workflow |
| **Sub-skills** | `tab-work.md`, etc. | When the router dispatches them | Detailed workflow playbooks for each phase |

### The Lifecycle

A project flows through these phases:

```
Brainstorm → Refine → Implement → Verify → Review → Commit
     ↑                                              |
     └──────── Tab has full state at every step ────┘
```

**1. Brainstorm** (`/tab I have an idea for X`)
- Collaborative dialogue: one question at a time, multiple choice when possible
- Creates a draft Tab project IMMEDIATELY (crash recovery — nothing is lost)
- Proposes 2-3 approaches with trade-offs
- Saves KB documents as discoveries happen (not at the end)
- Produces: Tab project with goal, requirements, design, and task backlog

**2. Refine** (`/tab refine` or auto-detected when tasks lack detail)
- Walks through each task with you to ensure it's well-specified
- Spawns research agents for unknowns (doesn't guess)
- Updates Tab tasks in real-time as decisions are made
- Every task gets: description, implementation plan, acceptance criteria, effort, impact

**3. Implement** (`/tab work on X` or `/tab continue`)
- Loads project from Tab, creates a branch
- Dispatches sub-agents in parallel for independent tasks
- Tracks progress via Tab task statuses (todo → in_progress → done)
- Maintains a Session Progress Log in Tab (auto-updated after every task)
- The orchestrator NEVER writes code — always delegates to sub-agents

**4. Verify** (`/tab verify`)
- Auto-detects project type (TypeScript, Python, Go, etc.)
- Runs lint, typecheck, and tests
- Creates Tab tasks for each failure
- Dispatches fix agents and re-verifies (max 3 cycles)

**5. Review + Commit**
- Code review is mandatory before commit
- Review findings become Tab tasks that must be resolved
- Commit gate checks: all review-findings done, all verification-failures done, all tasks done
- Never pushes — that's up to you

### Crash Recovery

The plugin is designed to survive session crashes:

- Draft projects are created at the start of brainstorming (not after approval)
- Tab is updated after every state change (questions, decisions, task completions)
- Session Progress Log is updated synchronously before dispatching sub-agents
- On resume, stale `in_progress` tasks are detected and the user is asked what to do

### Knowledge Base

Reusable knowledge (architecture patterns, API limitations, conventions, troubleshooting) is saved as Tab documents and attached to projects. KB docs are saved immediately when discoveries happen — not gated on session end or design approval.

## Commands

| Command | Description | When to use |
|---------|-------------|-------------|
| `/tab` | **Unified entry point** — detects project and intent, routes automatically | Always. This is the main command. |
| `/tab-brainstorming` | Ideas → designs → Tab project (direct access) | If you want to skip the router |
| `/tab-refinement` | Walk through tasks to ensure they're well-specified | Direct access to refinement |
| `/tab-work` | Load project, dispatch agents, implement tasks | Direct access to implementation |
| `/tab-verify` | Lint/typecheck/tests → Tab tasks → auto-fix | Direct access to verification |
| `/tab-feedback` | Compile feedback report for Tab creator | Alpha testing feedback |

### Using `/tab` (recommended)

```
/tab                              → show project status, ask what to do
/tab I want to build X            → start brainstorming
/tab work on doot                 → implement a project
/tab continue                     → resume where you left off
/tab verify                       → run checks
/tab save                         → save progress
/tab refine                       → review backlog
```

Command names map to filenames: `tab-work.md` becomes `/tab-work`.

## Agents

These are spawned by the workflow commands — you don't invoke them directly:

| Agent | Role | Spawned by |
|-------|------|-----------|
| `planner` | Decompose work into tasks with plans and acceptance criteria | tab-work, tab-refinement |
| `qa` | Validate work against plans, find gaps, create qa-findings tasks | tab-work, tab-refinement |
| `documenter` | Extract knowledge from completed work into Tab KB documents | tab-work |

These are named agents with their own `.md` instruction files. The workflow also spawns general-purpose sub-agents (research, implement, test, fix) using Claude Code's built-in agent types — those are not separate files.

## Prerequisites

- **[Tab for Projects](https://github.com/4lt7ab/Tab)** MCP server running locally (default: `http://localhost:5069/mcp` — check your Tab config if connection fails)
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

## Alpha Testing (optional)

If you're helping test Tab for Projects, the plugin includes hooks for automatic feedback collection.

> **Note:** The `tab-alpha-testing.md` rule is included in the base install and will observe Tab API interactions in-session. The steps below add **hook scripts** for automated log capture to a JSONL file.

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
├── 2026-04-03.jsonl          (raw API logs)
├── 2026-04-03-report.md      (compiled report)
├── 2026-04-04.jsonl
└── 2026-04-04-report.md
```

Dated files, nothing gets overwritten.

## Architecture

```
marketplace/
└── plugins/tab/
    ├── commands/
    │   ├── tab.md                  ← Unified router (entry point)
    │   ├── tab-brainstorming.md    ← Brainstorm flow (incremental saves)
    │   ├── tab-work.md             ← Implementation orchestrator (auto progress saves)
    │   ├── tab-verify.md           ← Verification + auto-fix loop
    │   ├── tab-refinement.md       ← Backlog grooming
    │   └── tab-feedback.md         ← Feedback report compiler
    ├── agents/
    │   ├── planner.md              ← Task decomposition
    │   ├── qa.md                   ← Work validation
    │   └── documenter.md           ← Knowledge extraction
    ├── rules/
    │   ├── tab-discipline.md       ← Always-on Tab-first discipline
    │   └── tab-alpha-testing.md    ← Feedback collection (optional)
    └── scripts/
        ├── tab-feedback-logger.*   ← PostToolUse hook
        └── tab-feedback-summary.*  ← Stop hook
```

## Credits

Built on [Tab for Projects](https://github.com/4lt7ab/Tab) by [@4lt7ab](https://github.com/4lt7ab).

Skill architecture inspired by [Everything Claude Code](https://github.com/affaan-m/everything-claude-code) patterns (three-tier: rules → skills → agents).

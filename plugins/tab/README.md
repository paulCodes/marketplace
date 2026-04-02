# Tab for Projects Plugin

A Claude Code plugin for the **Tab for Projects** workflow -- brainstorming ideas into designs, implementing with sub-agents, verifying code health, and collecting structured feedback.

## Overview

This plugin provides 6 commands and 3 named agents that form a complete project lifecycle:

### Commands

| Command | Description | When to use |
|---------|-------------|-------------|
| `/tab-brainstorming` | Turn ideas into designs through collaborative dialogue, persist to Tab | Starting any new feature, component, or project |
| `/tab-refinement` | Walk through backlog tasks with user to ensure they're well-specified | Before implementation, after brainstorming |
| `/tab-work` | Load a Tab project and execute tasks with sub-agents | Implementing, tackling, or continuing a Tab project |
| `/tab-verify` | Run lint/typecheck/tests, create bug tasks, auto-fix | After any code change, before committing, health checks |
| `/tab-feedback` | Compile feedback into a structured report | End of session, or on demand |
| `/listen` | Enter silence mode — user thinks out loud, then synthesis | When you need to think through something uninterrupted |

### Agents (spawned by commands)

| Agent | Role | Spawned by |
|-------|------|-----------|
| `tab-workflow:planner` | Decompose work into tasks with plans and acceptance criteria | tab-work, tab-refinement |
| `tab-workflow:qa` | Validate work against plans, find gaps, create qa-findings tasks | tab-work, tab-refinement |
| `tab-workflow:documenter` | Extract knowledge from completed work into Tab KB documents | tab-work |

## Prerequisites

- **Tab for Projects MCP server** running at `http://localhost:5069/mcp`
- **Claude Code** with MCP support
- Optionally: **Jira MCP server** (for PlexTrac integration with ticket-based projects)

## Install

Add the marketplace and install the plugin:

```bash
claude marketplace add https://github.com/paulCodes/claude-marketplace
claude plugin install tab-workflow
```

## Usage

### Brainstorming a new project

```
/tab-brainstorming
> Let's build a CLI tool called doot that prints ASCII art
```

The command walks you through clarifying questions, proposes approaches, presents a design for approval, then saves everything to Tab (project + tasks with full implementation details).

### Working on a Tab project

```
/tab-work
> Work on doot
```

Loads the project from Tab, researches the codebase, creates a branch, dispatches sub-agents to implement each task, runs code review, and commits. Never pushes -- that's up to you.

### Verifying code health

```
/tab-verify
```

Auto-detects project type (TypeScript, Python, Go, etc.), runs appropriate checks, creates Tab bug tasks for failures, dispatches fix agents, and re-verifies. Max 3 fix cycles before asking for help.

### Generating feedback

```
/tab-feedback
```

Compiles session observations, API logs, feature requests, and friction points into `~/.claude/tab-feedback-report.md` for the Tab creator.

## Alpha Testing Setup (optional)

The plugin includes hooks and a rule for actively collecting feedback while using Tab. This is optional but recommended if you're helping test Tab.

### 1. Install the feedback rule

Copy the rule so Claude actively observes Tab interactions:

```bash
cp plugins/tab/rules/tab-alpha-testing.md ~/.claude/rules/
```

### 2. Install the feedback hooks

Copy the hook scripts:

```bash
cp plugins/tab/scripts/tab-feedback-logger.sh ~/.claude/hooks/
cp plugins/tab/scripts/tab-feedback-summary.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/tab-feedback-logger.sh ~/.claude/hooks/tab-feedback-summary.sh
```

Then add to your `~/.claude/settings.json` (merge into existing hooks):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "mcp__tab-for-projects__*",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/tab-feedback-logger.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/tab-feedback-summary.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**Requires:** `jq` on PATH (the hooks use it to parse JSON).

### 3. Generate feedback

Run `/tab-feedback` anytime to compile observations into a report at `~/.claude/tab-feedback-report.md`.

---

## How it works

The workflow follows this progression:

```
Brainstorm → Design → Tab Project → Tasks → Implement → Verify → Review → Commit
```

- **Tab is the source of truth** -- all project state (goals, requirements, design, tasks) lives in Tab, not local files
- **Sub-agent architecture** -- heavy work is delegated to sub-agents while the main conversation orchestrates
- **Knowledge base** -- reusable knowledge (architecture decisions, conventions, troubleshooting) is extracted into Tab documents and attached to projects

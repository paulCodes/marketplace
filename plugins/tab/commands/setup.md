---
name: setup
description: "First-time setup wizard for the Tab Workflow plugin. Checks prerequisites, installs rules, configures optional hooks, and verifies everything works."
---

# Tab Workflow Setup Wizard

You are running the first-time setup wizard for the Tab Workflow plugin. Walk through each step sequentially. Show results as you go, then move to the next step.

## Step 1: Welcome

Print this message:

```
Setting up Tab Workflow. This will:
  1. Check that the Tab MCP server is running
  2. Clean up any old standalone install files
  3. Install recommended rules
  4. Show available commands

Let's go.
```

## Step 2: Check Tab for Projects MCP Server

Try calling `mcp__tab-for-projects__list_projects()`.

**If it succeeds:**
Print: "Tab MCP server is running. Found {N} project(s)."
Move to Step 3.

**If it fails (tool not found, connection refused, etc.):**
Print setup instructions and STOP:

```
Tab MCP server is not reachable.

To set it up:

  1. Clone the Tab for Projects repo:
     git clone https://github.com/4lt7ab/Tab

  2. Follow the README to start the server (default: http://localhost:5069/mcp)

  3. Add the MCP server to your Claude Code settings. In ~/.claude.json, add:

     "mcpServers": {
       "tab-for-projects": {
         "type": "streamable-http",
         "url": "http://localhost:5069/mcp",
         "headers": {
           "Accept": "application/json, text/event-stream"
         }
       }
     }

  4. Restart Claude Code, then run /tab-workflow:setup again.
```

Do NOT continue past this step if the MCP server is unreachable. The rest of the wizard requires it.

## Step 3: Clean Up Old Standalone Install

Check whether any of these files exist in `~/.claude/commands/`:

- `tab.md`
- `tab-work.md`
- `tab-brainstorming.md`
- `tab-refinement.md`
- `tab-verify.md`
- `tab-feedback.md`

Also check `~/.claude/agents/` for:

- `documenter.md`
- `planner.md`
- `qa.md`

Use bash to check for their existence (e.g., `ls -la ~/.claude/commands/tab*.md ~/.claude/agents/documenter.md ~/.claude/agents/planner.md ~/.claude/agents/qa.md 2>/dev/null`).

**If none found:**
Print: "No old standalone files detected. Skipping cleanup."
Move to Step 4.

**If any found:**
List the files found and print:

```
Detected old standalone Tab Workflow files that will conflict with the plugin:

  {list each file path found}

These should be removed so the plugin versions are used instead.
Remove them? (yes/no)
```

Wait for the user's answer.

- If yes: remove the files with `rm`. Print "Removed {N} old file(s)."
- If no: print "Skipping cleanup. Note: the old files may shadow or conflict with the plugin commands. If you see duplicate or unexpected behavior, remove them manually."

Move to Step 4.

## Step 4: Install Rules

The plugin ships two rule files. Rules are not auto-installed by the plugin system, so offer to copy them to `~/.claude/rules/`.

**IMPORTANT:** Because writing to `~/.claude/` can reset bypass permissions, do NOT write these files directly with the Write or Edit tool. Instead, use a bash `cp` command to copy them from the plugin directory.

The plugin rule files are at:
- `~/workspaces/marketplace/plugins/tab/rules/tab-discipline.md`
- `~/workspaces/marketplace/plugins/tab/rules/tab-alpha-testing.md`

For each rule:

### tab-discipline.md (recommended)

Check if `~/.claude/rules/tab-discipline.md` already exists (bash `test -f`).

- If it exists: print "tab-discipline.md is already installed. Skipping."
- If not: print the description and ask:

```
tab-discipline.md (recommended)
  Enforces Tab-first behavior, incremental saves, and progress logging.
  Install? (yes/no)
```

If yes, run: `cp ~/workspaces/marketplace/plugins/tab/rules/tab-discipline.md ~/.claude/rules/tab-discipline.md`

### tab-alpha-testing.md (optional)

Check if `~/.claude/rules/tab-alpha-testing.md` already exists.

- If it exists: print "tab-alpha-testing.md is already installed. Skipping."
- If not: print the description and ask:

```
tab-alpha-testing.md (optional)
  Collects feedback while using Tab MCP tools. For alpha testers.
  Install? (yes/no)
```

If yes, run: `cp ~/workspaces/marketplace/plugins/tab/rules/tab-alpha-testing.md ~/.claude/rules/tab-alpha-testing.md`

## Step 5: Companion Plugins

Offer optional companion plugins that extend the Tab workflow.

### code-review (optional)

Print:

```
The code-review plugin provides multi-agent PR reviews with voice-controlled
comment posting. When Tab is available, it verifies code against project
acceptance criteria.

Install it? (yes/no)
```

- If yes: print "Run `/plugin install code-review@paulCodes-marketplace` to install."
- If no: print "Skipping. You can install it later with `/plugin install code-review@paulCodes-marketplace`."

Move to Step 6.

## Step 6: Quick Start Guide

Print:

```
Tab Workflow is ready. Available commands:

  /tab-workflow:main        Router: detects project and intent, routes automatically
  /tab-workflow:brainstorm  Turn ideas into designs with Tab persistence
  /tab-workflow:refine      Walk through tasks to ensure they're well-specified
  /tab-workflow:work        Implement tasks with sub-agents and quality gates
  /tab-workflow:verify      Run lint/typecheck/tests, auto-fix failures
  /tab-workflow:feedback    Compile Tab feedback report

Optional (requires code-review plugin):
  /code-review:review       Multi-agent PR review with voice-controlled posting

Start with:
  /tab-workflow:main              Show project status
  /tab-workflow:brainstorm        Start a new project
  /tab-workflow:main work on X    Resume implementation
```

That's it. Setup is complete.

## Style Rules

- No em dashes in running text
- Keep output conversational but efficient
- Each step is one interaction: show the result, then move on
- Do not over-explain. Users reading this already chose to install the plugin.

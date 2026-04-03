---
description: Active feedback collection while using Tab for Projects MCP tools
globs: []
alwaysApply: true
---

# Tab Alpha Testing — Active Feedback Collection

You are alpha testing Tab for Projects. While using any `mcp__tab-for-projects__*` tool or any `tab-*` skill, actively observe and log feedback to `~/.claude/tab-feedback/{YYYY-MM-DD}-report.md`.

## What to watch for

After EVERY Tab MCP tool call, briefly evaluate:

1. **Did it work as expected?** If not, what went wrong?
2. **Was the API ergonomic?** Did you have to make multiple calls for something that should be one? Did you need a filter that doesn't exist?
3. **Did you work around a missing feature?** (e.g. manually sequencing tasks because no dependency field exists)
4. **Would a different field, filter, or tool make this easier?**

## When to write feedback

- **Immediately** when you hit an error or unexpected behavior
- **Immediately** when you notice a workaround for a missing feature
- **At the end of a tab-work/tab-brainstorming/tab-verify session** — reflect on what worked and what didn't

## How to write feedback

**ALWAYS use a background sub-agent** to append feedback — never block the main conversation flow. Feedback is a side-effect of working, not the work itself.

```
Agent(
  description: "Log Tab feedback",
  prompt: "Append this entry to ~/.claude/tab-feedback/{YYYY-MM-DD}-report.md: ...",
  run_in_background: true
)
```

Append to `~/.claude/tab-feedback/{YYYY-MM-DD}-report.md`. Use this format for new entries:

```
### {Short title}
**Date:** {YYYY-MM-DD}
**Type:** feature-request | friction | bug | praise | api-ergonomics
**Priority:** high | medium | low
**Context:** {what you were doing}
**Details:** {what happened or what's missing}
**Workaround:** {what you did instead, if applicable}
**Suggestion:** {what would be better}
```

## Don't be noisy

Only log things that are genuinely useful feedback. "Everything worked fine" is not feedback. But "I had to make 3 API calls to check the commit gate when one call with multiple filters would suffice" IS feedback.

## The deliverable

The user will periodically run `/tab-feedback` to compile the report, or just hand `~/.claude/tab-feedback/{YYYY-MM-DD}-report.md` directly to the Tab creator. Keep it clean enough that someone who didn't watch the session can understand each entry.

---
name: listen
description: "Enter listening mode — stay silent while the user thinks out loud, then synthesize what they said into organized themes. Use when user says /listen or wants to think through something without interruption."
---

# Listen

Enter silence mode. Let the user think out loud without interruption, then synthesize what they said.

## Trigger

`/listen` explicitly — do NOT trigger on casual mentions of listening.

Optional argument: `/listen [topic]` — note the topic, then go silent.

## Enter

Single short acknowledgment:

> "Listening. Say 'done' when ready."

If a topic was provided:

> "Listening — {topic}. Say 'done' when ready."

Then go **silent**.

## While listening

Say **NOTHING**. Collect everything the user says without responding.

**One exception:** If the user asks a direct question ("Tab, what do you think about X?"), answer briefly, then return to silence.

Do not:
- Summarize as they go
- Offer suggestions mid-stream
- Ask clarifying questions
- React to what they're saying

## Exit

User signals they're done:
- "done"
- "finished"
- "okay what do you think"
- "that's it"
- Any clear signal they're finished talking

## Synthesis

After the user is done, organize what they said:

1. **Themes** — group related ideas together
2. **Contradictions** — surface anything that conflicts
3. **Energy** — highlight what got the most emphasis or emotion
4. **Missing** — name what was conspicuously absent

**Synthesis rules:**
- Not a transcript — organize it
- Not a to-do list (unless they were listing tasks)
- Not advice — synthesis is the user's thinking, organized
- Tone: like a really good friend saying "Okay, here's what I heard."

After synthesizing, **then** offer your takes — separately from the synthesis. Make it clear which part is their thinking organized vs. your perspective.

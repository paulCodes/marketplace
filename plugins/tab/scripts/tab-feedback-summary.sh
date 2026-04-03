#!/bin/bash
# On session stop, if there are Tab feedback entries from this session,
# remind the user to review them.

TODAY=$(date -u +"%Y-%m-%d")
FEEDBACK_FILE="$HOME/.claude/tab-feedback/${TODAY}.jsonl"

if [ ! -f "$FEEDBACK_FILE" ]; then
  exit 0
fi

# Count entries from today's file
TODAY_COUNT=$(wc -l < "$FEEDBACK_FILE" 2>/dev/null || echo "0")
ERROR_COUNT=$(jq -r 'select(.is_error == true)' "$FEEDBACK_FILE" 2>/dev/null | wc -l 2>/dev/null || echo "0")

if [ "$TODAY_COUNT" -gt 0 ]; then
  echo "{\"systemMessage\":\"Tab feedback: $TODAY_COUNT API calls logged today ($ERROR_COUNT errors). Review with: cat ~/.claude/tab-feedback.jsonl | jq .\"}"
fi

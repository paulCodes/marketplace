#!/bin/bash
# On session stop, if there are Tab feedback entries from this session,
# remind the user to review them.

FEEDBACK_FILE="$HOME/.claude/tab-feedback.jsonl"

if [ ! -f "$FEEDBACK_FILE" ]; then
  exit 0
fi

# Count entries from today
TODAY=$(date -u +"%Y-%m-%d")
TODAY_COUNT=$(grep -c "$TODAY" "$FEEDBACK_FILE" 2>/dev/null || echo "0")
ERROR_COUNT=$(jq -r 'select(.is_error == true)' "$FEEDBACK_FILE" 2>/dev/null | grep -c "$TODAY" 2>/dev/null || echo "0")

if [ "$TODAY_COUNT" -gt 0 ]; then
  echo "{\"systemMessage\":\"Tab feedback: $TODAY_COUNT API calls logged today ($ERROR_COUNT errors). Review with: cat ~/.claude/tab-feedback.jsonl | jq .\"}"
fi

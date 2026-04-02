#!/bin/bash
# Log Tab MCP tool usage, errors, and friction for feedback to the Tab creator.
# Fires on PostToolUse for any tab-for-projects tool.
# Appends entries to ~/.claude/tab-feedback.jsonl

FEEDBACK_FILE="$HOME/.claude/tab-feedback.jsonl"

# Read stdin (hook input JSON)
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // {}')
TOOL_RESPONSE=$(echo "$INPUT" | jq -c '.tool_response // {}')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Check if the response indicates an error
IS_ERROR=$(echo "$TOOL_RESPONSE" | jq -r 'if type == "object" then (.error // .isError // false) else false end')

# Build the log entry
jq -n \
  --arg ts "$TIMESTAMP" \
  --arg tool "$TOOL_NAME" \
  --argjson input "$TOOL_INPUT" \
  --argjson response "$TOOL_RESPONSE" \
  --arg is_error "$IS_ERROR" \
  '{
    timestamp: $ts,
    tool: $tool,
    input: $input,
    response_preview: ($response | tostring | .[:500]),
    is_error: ($is_error != "false"),
    session_id: env.CLAUDE_SESSION_ID
  }' >> "$FEEDBACK_FILE"

# If it was an error, also output a system message so Claude knows to note it
if [ "$IS_ERROR" != "false" ]; then
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"Tab MCP error logged to ~/.claude/tab-feedback.jsonl — consider noting this as feedback for the Tab creator.\"}}"
fi

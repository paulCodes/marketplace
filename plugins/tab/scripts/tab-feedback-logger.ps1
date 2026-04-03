# Log Tab MCP tool usage, errors, and friction for feedback to the Tab creator.
# Fires on PostToolUse for any tab-for-projects tool.
# Appends entries to ~/.claude/tab-feedback.jsonl
# PowerShell version for Windows.

$Today = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
$FeedbackDir = Join-Path $env:USERPROFILE ".claude\tab-feedback"
if (-not (Test-Path $FeedbackDir)) { New-Item -ItemType Directory -Path $FeedbackDir -Force | Out-Null }
$FeedbackFile = Join-Path $FeedbackDir "${Today}.jsonl"

# Read stdin (hook input JSON)
$Input = $input | Out-String
$Parsed = $Input | ConvertFrom-Json

$ToolName = if ($Parsed.tool_name) { $Parsed.tool_name } else { "unknown" }
$ToolInput = if ($Parsed.tool_input) { $Parsed.tool_input | ConvertTo-Json -Compress -Depth 10 } else { "{}" }
$ToolResponse = if ($Parsed.tool_response) { $Parsed.tool_response | ConvertTo-Json -Compress -Depth 10 } else { "{}" }
$Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Check if the response indicates an error
$IsError = $false
if ($Parsed.tool_response -and ($Parsed.tool_response.error -or $Parsed.tool_response.isError)) {
    $IsError = $true
}

# Truncate response preview to 500 chars
$ResponsePreview = $ToolResponse
if ($ResponsePreview.Length -gt 500) {
    $ResponsePreview = $ResponsePreview.Substring(0, 500)
}

# Build the log entry
$Entry = @{
    timestamp = $Timestamp
    tool = $ToolName
    input = $Parsed.tool_input
    response_preview = $ResponsePreview
    is_error = $IsError
    session_id = $env:CLAUDE_SESSION_ID
} | ConvertTo-Json -Compress -Depth 10

Add-Content -Path $FeedbackFile -Value $Entry

# If it was an error, output a system message
if ($IsError) {
    Write-Output '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"Tab MCP error logged to ~/.claude/tab-feedback.jsonl — consider noting this as feedback for the Tab creator."}}'
}

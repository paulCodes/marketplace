# On session stop, if there are Tab feedback entries from this session,
# remind the user to review them.
# PowerShell version for Windows.

$Today = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
$FeedbackFile = Join-Path $env:USERPROFILE ".claude\tab-feedback\${Today}.jsonl"

if (-not (Test-Path $FeedbackFile)) {
    exit 0
}

$Lines = Get-Content $FeedbackFile -ErrorAction SilentlyContinue
$TodayCount = $Lines.Count
$ErrorCount = ($Lines | Where-Object { $_ -match '"is_error":true' }).Count

if ($TodayCount -gt 0) {
    Write-Output "{`"systemMessage`":`"Tab feedback: $TodayCount API calls logged today ($ErrorCount errors). Review with: Get-Content ~/.claude/tab-feedback.jsonl | ConvertFrom-Json`"}"
}

# Creates (or comments on) a Jira bug when a Jenkins build fails.
# Reads Jira credentials from env vars JIRA_USER / JIRA_TOKEN (injected by Jenkins
# withCredentials) and build context from JOB_NAME / BUILD_NUMBER / BUILD_URL.
# Set JIRA_DRYRUN=1 to build the payload and print it without calling Jira.
#
# Dedup: if an unresolved auto-created bug for this job already exists, a comment
# is added instead of opening a duplicate.

$ErrorActionPreference = 'Stop'

$site       = 'https://makpowerful.atlassian.net'
$projectKey = 'SCRUM'
$bugTypeId  = '10006'   # Bug

$email = $env:JIRA_USER
$token = $env:JIRA_TOKEN
if (-not $email -or -not $token) {
    Write-Host 'JIRA_USER / JIRA_TOKEN not set - skipping Jira bug creation.'
    exit 0
}

$job = $env:JOB_NAME
$num = $env:BUILD_NUMBER
$url = $env:BUILD_URL
if (-not $job) { $job = 'unknown-job' }
if (-not $num) { $num = '0' }

$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${email}:${token}"))

function Write-JsonNoBom($obj, $path) {
    $json = $obj | ConvertTo-Json -Depth 40
    [IO.File]::WriteAllText($path, $json, (New-Object Text.UTF8Encoding $false))
}

# --- Collect failed tests from the JUnit report (if present) ---
$failures = @()
$junit = Join-Path (Get-Location) 'test-results/junit.xml'
if (Test-Path $junit) {
    try {
        [xml]$x = Get-Content $junit -Raw
        foreach ($tc in $x.SelectNodes('//testcase')) {
            if ($tc.failure) {
                $msg = if ($tc.failure.message) { $tc.failure.message } else { [string]$tc.failure.'#text' }
                $msg = ($msg -replace '\s+', ' ').Trim()
                if ($msg.Length -gt 400) { $msg = $msg.Substring(0, 400) + '...' }
                $failures += "$($tc.classname) > $($tc.name) :: $msg"
            }
        }
    } catch {
        Write-Host "Could not parse junit.xml: $($_.Exception.Message)"
    }
}

# --- Build description paragraphs ---
$lines = @(
    "Automated bug: Jenkins build $job #$num FAILED.",
    "Build URL: $url"
)
if ($failures.Count -gt 0) {
    $lines += "Failed tests:"
    $lines += $failures
} else {
    $lines += "The build failed before tests produced results (e.g. a compile or setup error). See the console log."
}

$content = @()
foreach ($line in $lines) {
    $content += @{ type = 'paragraph'; content = @(@{ type = 'text'; text = [string]$line }) }
}

$summary = "CI failure: $job #$num"

# --- Dedup: look for an existing unresolved auto bug for this job ---
$existingKey = $null
try {
    $jql = "project = $projectKey AND statusCategory != Done AND labels = 'ci-auto-failure' AND summary ~ '$job'"
    $searchPayload = @{ jql = $jql; maxResults = 1; fields = @('key') }
    $sTmp = Join-Path $env:TEMP 'jira_search.json'
    Write-JsonNoBom $searchPayload $sTmp
    $sResp = curl.exe -s -X POST -H "Authorization: Basic $b64" -H 'Content-Type: application/json' --data "@$sTmp" "$site/rest/api/3/search/jql"
    $sObj = $sResp | ConvertFrom-Json
    if ($sObj.issues -and $sObj.issues.Count -gt 0) { $existingKey = $sObj.issues[0].key }
} catch {
    Write-Host "Dedup search skipped: $($_.Exception.Message)"
}

if ($env:JIRA_DRYRUN -eq '1') {
    Write-Host "[DRYRUN] summary: $summary"
    Write-Host "[DRYRUN] existing open bug: $existingKey"
    Write-Host "[DRYRUN] description lines:"
    $lines | ForEach-Object { Write-Host "   $_" }
    exit 0
}

if ($existingKey) {
    # Comment on the existing bug instead of duplicating it.
    $comment = @{ body = @{ type = 'doc'; version = 1; content = @(
        @{ type = 'paragraph'; content = @(@{ type = 'text'; text = "Recurred: $job #$num failed again. $url" }) }
    ) } }
    $cTmp = Join-Path $env:TEMP 'jira_comment.json'
    Write-JsonNoBom $comment $cTmp
    $resp = curl.exe -s -w "`n%{http_code}" -X POST -H "Authorization: Basic $b64" -H 'Content-Type: application/json' --data "@$cTmp" "$site/rest/api/3/issue/$existingKey/comment"
    $code = ($resp -split "`n")[-1]
    Write-Host "Commented on existing bug $existingKey (HTTP $code)"
} else {
    $payload = @{ fields = @{
        project     = @{ key = $projectKey }
        issuetype   = @{ id = $bugTypeId }
        summary     = $summary
        labels      = @('ci-auto-failure', 'playwright')
        description = @{ type = 'doc'; version = 1; content = $content }
    } }
    $pTmp = Join-Path $env:TEMP 'jira_create.json'
    Write-JsonNoBom $payload $pTmp
    $resp = curl.exe -s -w "`n%{http_code}" -X POST -H "Authorization: Basic $b64" -H 'Content-Type: application/json' --data "@$pTmp" "$site/rest/api/3/issue"
    $parts = $resp -split "`n"
    $code = $parts[-1]
    $body = ($parts[0..($parts.Count - 2)] -join "`n")
    if ($code -eq '201') {
        $key = ($body | ConvertFrom-Json).key
        Write-Host "Created Jira bug $key (HTTP 201)"
    } else {
        Write-Host "Jira bug creation failed (HTTP $code): $body"
    }
}

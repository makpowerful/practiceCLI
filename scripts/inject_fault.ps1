# Chaos / fault-injection (working copy only - NEVER committed).
# Breaks a locator so the test fails, to verify the pipeline's detect + alert path
# (email + Jira) works end to end. Jenkins force-checks-out the branch on every
# build, so this change is discarded on the next run and never reaches git.

$ErrorActionPreference = 'Stop'

$file   = 'pages/DashboardPage.ts'
$orig   = 'toHaveURL(/#\/dashboard\/cart/)'
$broken = 'toHaveURL(/#\/chaos-injected\/cart/)'

$content = Get-Content $file -Raw
if ($content -notmatch [regex]::Escape($orig)) {
    Write-Host "Fault injection: target locator not found in $file - nothing injected."
    exit 0
}

$content = $content.Replace($orig, $broken)
[IO.File]::WriteAllText((Join-Path (Get-Location) $file), $content, (New-Object Text.UTF8Encoding $false))

Write-Host '================ CHAOS FAULT INJECTED ================'
Write-Host "File:   $file (goToCart URL assertion)"
Write-Host "Before: $orig"
Write-Host "After:  $broken"
Write-Host 'Expectation: checkout test fails at DashboardPage.goToCart,'
Write-Host 'then the email + Jira alerting should fire automatically.'
Write-Host '======================================================'

# Builds a Gmail-safe zip of the Playwright HTML report for emailing.
# Gmail blocks messages whose attachments contain nested archives (.zip) or
# videos, so the trace .zip and .webm files are removed from the emailed copy.
# The full report (with traces and videos) still lives in Jenkins artifacts
# and the published HTML/Allure reports.

$ErrorActionPreference = 'Continue'

if (-not (Test-Path 'playwright-report')) {
    Write-Host 'No playwright-report folder to zip.'
    exit 0
}

$mail = 'report-mail'
Remove-Item -Recurse -Force $mail -ErrorAction SilentlyContinue
Copy-Item -Recurse 'playwright-report' $mail

# Drop Gmail-blocked / heavy content from the emailed copy only.
Get-ChildItem -Recurse $mail -Include *.zip, *.webm -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

Remove-Item -Force 'playwright-report.zip' -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $mail '*') -DestinationPath 'playwright-report.zip' -Force

$kb = (Get-Item 'playwright-report.zip').Length / 1KB
Write-Host ("Email report zip created: {0:N0} KB" -f $kb)

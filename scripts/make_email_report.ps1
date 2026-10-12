# Builds a self-contained, JS-free HTML summary of the test run for emailing.
# Gmail blocks attachments containing .js (the Playwright HTML report needs JS,
# so it can't be emailed). This produces email-report.html - a plain table of
# results with failure messages - which Gmail accepts. The full interactive
# Playwright report and Allure report remain available in Jenkins.

$ErrorActionPreference = 'Continue'

function Esc([string]$s) {
    if ($null -eq $s) { return '' }
    return ($s -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
}

$job = $env:JOB_NAME; if (-not $job) { $job = 'job' }
$num = $env:BUILD_NUMBER; if (-not $num) { $num = '0' }
$result = $env:BUILD_RESULT; if (-not $result) { $result = '' }

$rows = ''
$total = 0; $passed = 0; $failed = 0; $skipped = 0

$junit = 'test-results/junit.xml'
if (Test-Path $junit) {
    [xml]$x = Get-Content $junit -Raw
    foreach ($tc in $x.SelectNodes('//testcase')) {
        $total++
        $name = "$($tc.classname) > $($tc.name)"
        $time = [double]($tc.time); if (-not $time) { $time = 0 }
        if ($tc.failure -or $tc.error) {
            $failed++
            $status = 'FAILED'; $color = '#c0392b'
            $node = if ($tc.failure) { $tc.failure } else { $tc.error }
            $msg = if ($node.message) { $node.message } else { [string]$node.'#text' }
            $msg = ($msg -replace '\s+', ' ').Trim()
            if ($msg.Length -gt 600) { $msg = $msg.Substring(0, 600) + '...' }
        } elseif ($tc.skipped) {
            $skipped++; $status = 'SKIPPED'; $color = '#7f8c8d'; $msg = ''
        } else {
            $passed++; $status = 'PASSED'; $color = '#27ae60'; $msg = ''
        }
        $errCell = if ($msg) { "<div style='color:#c0392b;font-family:monospace;font-size:12px;margin-top:4px'>$(Esc $msg)</div>" } else { '' }
        $rows += "<tr><td style='padding:6px 10px;border-bottom:1px solid #eee'>$(Esc $name)$errCell</td>" +
                 "<td style='padding:6px 10px;border-bottom:1px solid #eee;color:$color;font-weight:bold;white-space:nowrap'>$status</td>" +
                 "<td style='padding:6px 10px;border-bottom:1px solid #eee;text-align:right;white-space:nowrap'>$([math]::Round($time,1))s</td></tr>`n"
    }
}

$overallColor = if ($failed -gt 0) { '#c0392b' } else { '#27ae60' }

$html = @"
<!doctype html>
<html><head><meta charset="utf-8"><title>Test Report - $job #$num</title></head>
<body style="font-family:Arial,Helvetica,sans-serif;color:#2c3e50;margin:0;padding:20px">
  <h2 style="margin:0 0 4px">Playwright Test Report</h2>
  <p style="margin:0 0 16px;color:#7f8c8d">$job #$num</p>
  <p style="font-size:18px;margin:0 0 16px">
    Result: <b style="color:$overallColor">$result</b> &nbsp;|&nbsp;
    Total: <b>$total</b> &nbsp; Passed: <b style="color:#27ae60">$passed</b> &nbsp;
    Failed: <b style="color:#c0392b">$failed</b> &nbsp; Skipped: <b>$skipped</b>
  </p>
  <table style="border-collapse:collapse;width:100%;font-size:14px">
    <thead><tr style="background:#34495e;color:#fff">
      <th style="padding:8px 10px;text-align:left">Test</th>
      <th style="padding:8px 10px;text-align:left">Status</th>
      <th style="padding:8px 10px;text-align:right">Time</th>
    </tr></thead>
    <tbody>
$rows
    </tbody>
  </table>
  <p style="margin-top:16px;color:#7f8c8d;font-size:13px">
    Full interactive Playwright report and Allure report are available on the Jenkins build page.
  </p>
</body></html>
"@

[IO.File]::WriteAllText((Join-Path (Get-Location) 'email-report.html'), $html, (New-Object Text.UTF8Encoding $false))
Write-Host "email-report.html created: total=$total passed=$passed failed=$failed skipped=$skipped"

param(
  [string]$Url = "http://127.0.0.1:4173",
  [int]$Port = 4173
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $workspaceRoot

$outputDir = Join-Path $workspaceRoot "output\playwright"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$startedServer = $false
$serverProc = $null

function Test-WebReady {
  param(
    [Parameter(Mandatory = $true)]
    [string]$TargetUrl
  )
  try {
    $status = (Invoke-WebRequest -Uri $TargetUrl -UseBasicParsing -TimeoutSec 2).StatusCode
    return $status -eq 200
  } catch {
    return $false
  }
}

function Ensure-WebServer {
  if (Test-WebReady -TargetUrl $Url) {
    Write-Host "[info] Web server already ready at $Url"
    return
  }

  Write-Host "[info] Starting flutter web-server on port $Port..."
  $serverProc = Start-Process `
    -FilePath "flutter" `
    -ArgumentList "run -d web-server --web-hostname 127.0.0.1 --web-port $Port" `
    -WorkingDirectory $workspaceRoot `
    -RedirectStandardOutput (Join-Path $outputDir "flutter-web.out.log") `
    -RedirectStandardError (Join-Path $outputDir "flutter-web.err.log") `
    -PassThru
  $script:startedServer = $true

  for ($i = 0; $i -lt 120; $i++) {
    if (Test-WebReady -TargetUrl $Url) {
      Write-Host "[info] Web server is ready."
      return
    }
    Start-Sleep -Milliseconds 500
  }

  throw "Web server startup timed out: $Url"
}

function Run-PlaywrightRegression {
  $codeTemplate = 'async (page) => { const key = ''sb-ndbhxjvrgxeuyykrlyxl-auth-token''; await page.goto(''__URL__'', { waitUntil: ''domcontentloaded'', timeout: 120000 }); await page.evaluate(''localStorage.clear()''); await page.reload({ waitUntil: ''domcontentloaded'', timeout: 120000 }); await page.waitForTimeout(1200); for (let i = 0; i < 4; i++) { await page.keyboard.press(''Tab''); await page.waitForTimeout(100); } await page.keyboard.press(''Enter''); await page.waitForTimeout(2600); let tokenBeforeReload = await page.evaluate((k) => localStorage.getItem(k) !== null, key); if (!tokenBeforeReload) { await page.mouse.click(640, 494); await page.waitForTimeout(2800); tokenBeforeReload = await page.evaluate((k) => localStorage.getItem(k) !== null, key); } await page.reload({ waitUntil: ''domcontentloaded'', timeout: 120000 }); await page.waitForTimeout(2200); const tokenAfterReload = await page.evaluate((k) => localStorage.getItem(k) !== null, key); await page.screenshot({ path: ''output/playwright/01-anon-after-reload.png'', fullPage: true }); await page.mouse.click(30, 30); await page.waitForTimeout(500); await page.mouse.click(90, 560); await page.waitForTimeout(700); await page.mouse.click(715, 407); await page.waitForTimeout(2400); await page.screenshot({ path: ''output/playwright/02-after-logout.png'', fullPage: true }); const afterLogout = await page.evaluate((k) => ({ keyCount: localStorage.length, authToken: localStorage.getItem(k) }), key); return { tokenBeforeReload, tokenAfterReload, localStorageKeysAfterLogout: afterLogout.keyCount, authTokenAfterLogout: afterLogout.authToken }; }'
  $code = $codeTemplate.Replace("__URL__", $Url)

  $raw = & npx --yes --package @playwright/cli playwright-cli run-code "$code" 2>&1 | Out-String
  Write-Host $raw

  $match = [regex]::Match($raw, "(?ms)### Result\s*\r?\n(?<json>\{.*?\})\s*\r?\n### Ran Playwright code")
  if (-not $match.Success) {
    throw "Cannot parse Playwright result JSON."
  }

  $result = $match.Groups["json"].Value | ConvertFrom-Json
  $persistOk = $result.tokenBeforeReload -and $result.tokenAfterReload
  $logoutOk = ($result.localStorageKeysAfterLogout -eq 0) -and ($null -eq $result.authTokenAfterLogout)

  if (-not $persistOk) {
    throw "Anonymous session persistence check failed."
  }
  if (-not $logoutOk) {
    throw "Logout cleanup check failed."
  }

  Write-Host "[pass] Playwright regression passed."
  Write-Host "[pass] Screenshots:"
  Write-Host "  - output/playwright/01-anon-after-reload.png"
  Write-Host "  - output/playwright/02-after-logout.png"
}

try {
  Ensure-WebServer
  Run-PlaywrightRegression
} finally {
  if ($startedServer -and $serverProc) {
    try {
      Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue
      Write-Host "[info] Stopped local web-server PID $($serverProc.Id)"
    } catch {}
  }
}

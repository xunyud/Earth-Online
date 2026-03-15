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
  $script:serverProc = Start-Process `
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
  $codeTemplate = @'
async (page) => {
  const key = "sb-ndbhxjvrgxeuyykrlyxl-auth-token";
  await page.setViewportSize({ width: 1600, height: 900 });
  await page.goto("__URL__", { waitUntil: "domcontentloaded", timeout: 120000 });
  await page.evaluate("localStorage.clear()");
  await page.reload({ waitUntil: "domcontentloaded", timeout: 120000 });
  await page.waitForTimeout(1200);
  for (let i = 0; i < 4; i++) {
    await page.keyboard.press("Tab");
    await page.waitForTimeout(100);
  }
  await page.keyboard.press("Enter");
  await page.waitForTimeout(2600);
  let token = await page.evaluate((k) => localStorage.getItem(k) !== null, key);
  if (!token) {
    await page.mouse.click(640, 494);
    await page.waitForTimeout(2800);
    token = await page.evaluate((k) => localStorage.getItem(k) !== null, key);
  }
  await page.mouse.click(1460, 28);
  await page.waitForTimeout(1100);
  await page.mouse.click(1405, 28);
  await page.waitForTimeout(1100);

  await page.mouse.click(1490, 835);
  await page.waitForTimeout(700);
  await page.keyboard.press("Escape");
  await page.waitForTimeout(900);
  const hasAssertAfterEsc = await page.evaluate(() => document.body.innerText.includes("_dependents.isEmpty"));

  await page.mouse.click(1490, 835);
  await page.waitForTimeout(700);
  await page.mouse.click(835, 675);
  await page.waitForTimeout(900);
  const hasAssertAfterCancel = await page.evaluate(() => document.body.innerText.includes("_dependents.isEmpty"));

  await page.screenshot({ path: "output/playwright/reward-cancel-check.png", fullPage: true });
  return { token, hasAssertAfterEsc, hasAssertAfterCancel };
}
'@
  $code = $codeTemplate.Replace("__URL__", $Url)

  $raw = & npx --yes --package @playwright/cli playwright-cli run-code "$code" 2>&1 | Out-String
  Write-Host $raw

  $match = [regex]::Match($raw, "(?ms)### Result\s*\r?\n(?<json>\{.*?\})\s*\r?\n### Ran Playwright code")
  if (-not $match.Success) {
    throw "Cannot parse Playwright result JSON."
  }

  $result = $match.Groups["json"].Value | ConvertFrom-Json

  if ($result.hasAssertAfterEsc -or $result.hasAssertAfterCancel) {
    throw "Cancel flow still triggers _dependents.isEmpty assertion."
  }

  Write-Host "[pass] Reward cancel regression passed."
  Write-Host "[pass] Screenshot: output/playwright/reward-cancel-check.png"
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

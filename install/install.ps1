#Requires -Version 5.1
<#
  Onboards Super Productivity + its MCP server + its Claude skill for this machine.
  Run via:
    irm https://raw.githubusercontent.com/kailasas-auspicious/super-productivity-mcp/main/install/install.ps1 | iex
#>

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "    $msg" -ForegroundColor Yellow }

$RepoUrl   = "https://github.com/kailasas-auspicious/super-productivity-mcp"
$InstallDir = Join-Path $env:USERPROFILE ".super-productivity-mcp"
$OnboardingSkillDir = Join-Path $env:USERPROFILE ".claude\skills\super-productivity-onboarding"
$DailyScheduleSkillDir = Join-Path $env:USERPROFILE ".claude\skills\super-productivity-daily-schedule"
$BinPath    = Join-Path $InstallDir "super-productivity-mcp.exe"

# 1. Check / install Super Productivity desktop app
Write-Step "Checking for Super Productivity desktop app"
$spInstalled = Get-Command "Super Productivity" -ErrorAction SilentlyContinue
$spProcess = Get-Process -Name "Super Productivity" -ErrorAction SilentlyContinue
if (-not $spProcess -and -not (Test-Path "$env:LOCALAPPDATA\Programs\superproductivity")) {
    Write-Warn2 "Super Productivity doesn't look installed."
    Write-Warn2 "Opening the download page — install it, then re-run this script."
    Start-Process "https://super-productivity.com/"
    Write-Host ""
    Write-Host "After installing Super Productivity, run this installer again." -ForegroundColor Yellow
    exit 0
} else {
    Write-Ok "Super Productivity found"
}

# 2. Ensure Bun is available (used to build a standalone MCP server binary)
Write-Step "Checking for Bun"
$bun = Get-Command bun -ErrorAction SilentlyContinue
if (-not $bun) {
    Write-Warn2 "Bun not found — installing (no admin rights required)"
    powershell -c "irm bun.sh/install.ps1 | iex"
    $env:Path = "$env:USERPROFILE\.bun\bin;$env:Path"
    $bun = Get-Command bun -ErrorAction SilentlyContinue
    if (-not $bun) {
        throw "Bun install did not complete. Restart your terminal and re-run this script."
    }
}
Write-Ok "Bun available: $(bun --version)"

# 3. Fetch the MCP server source and compile a standalone .exe
Write-Step "Building the MCP server"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$srcZip = Join-Path $InstallDir "src.zip"
Invoke-WebRequest -Uri "$RepoUrl/archive/refs/heads/main.zip" -OutFile $srcZip
Expand-Archive -Path $srcZip -DestinationPath $InstallDir -Force
$repoDirName = (Get-ChildItem -Path $InstallDir -Directory | Where-Object { $_.Name -like "*-main" } | Select-Object -First 1).Name
$repoDir = Join-Path $InstallDir $repoDirName

Push-Location $repoDir
bun install
bun build ./src/index.ts --compile --outfile $BinPath
Pop-Location

Remove-Item $srcZip -Force
Write-Ok "Built $BinPath"

# 4. Install the Claude skills
Write-Step "Installing the Claude skills"
New-Item -ItemType Directory -Force -Path $OnboardingSkillDir | Out-Null
New-Item -ItemType Directory -Force -Path $DailyScheduleSkillDir | Out-Null
Copy-Item (Join-Path $repoDir "skill\onboarding\SKILL.md") (Join-Path $OnboardingSkillDir "SKILL.md") -Force
Copy-Item (Join-Path $repoDir "skill\daily-schedule\SKILL.md") (Join-Path $DailyScheduleSkillDir "SKILL.md") -Force
Write-Ok "Skills installed to $OnboardingSkillDir and $DailyScheduleSkillDir"

# 5. Register the MCP server with Claude Code
Write-Step "Registering MCP server with Claude Code"
$claude = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claude) {
    Write-Warn2 "Claude Code CLI ('claude') not found on PATH."
    Write-Warn2 "Install Claude Code, then run:"
    Write-Warn2 "  claude mcp add -s user super-productivity -- `"$BinPath`""
} else {
    claude mcp remove -s user super-productivity 2>$null | Out-Null
    claude mcp add -s user super-productivity -- "$BinPath"
    Write-Ok "Registered 'super-productivity' MCP server (user scope)"
}

# 6. Final manual step
Write-Host ""
Write-Host "One manual step left:" -ForegroundColor Cyan
Write-Host "  Open Super Productivity -> Settings -> Misc -> enable 'Local REST API'" -ForegroundColor Cyan
Write-Host "  (restart the app if the toggle doesn't take effect immediately)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Done. Start a new Claude Code session and ask it about your tasks." -ForegroundColor Green

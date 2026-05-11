#!/usr/bin/env pwsh
# ============================================================================
#  workspace/deploy.ps1 - Build and deploy Jupyter Book to GitHub Pages
#
#  USAGE (from the repository root):
#    .\workspace\deploy.ps1              # build + deploy
#    .\workspace\deploy.ps1 -SkipBuild  # skip Docker build, use existing _build/
#    .\workspace\deploy.ps1 -DryRun     # build but do not push
#
#  WHAT IT DOES
#    1. Runs "docker compose run --rm build" (unless -SkipBuild).
#    2. Clones the gh-pages branch into a temp directory (or inits fresh if the
#       branch does not exist yet).
#    3. Replaces its content with _build/html/ and adds .nojekyll.
#    4. Commits and force-pushes to origin/gh-pages.
#
#  Only the rendered HTML (_build/html/) is ever pushed to GitHub.
#  The markdown source stays local.
# ============================================================================

param(
    [switch]$SkipBuild,
    [switch]$DryRun,
    [string]$Remote = "origin",
    [string]$Branch = "gh-pages"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step { param([string]$Msg) Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$Msg) Write-Host "    OK: $Msg" -ForegroundColor Green }
function Write-Fail { param([string]$Msg) Write-Host "    FAIL: $Msg" -ForegroundColor Red; exit 1 }

# locate paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$BuildDir  = Join-Path $RepoRoot "_build\html"
$TempDir   = Join-Path $env:TEMP "jb-gh-pages-$(Get-Random)"

Set-Location $RepoRoot
Write-Step "Repository root: $RepoRoot"

# step 1: build
if (-not $SkipBuild) {
    Write-Step "Building Jupyter Book via Docker..."
    docker compose run --rm build
    if ($LASTEXITCODE -ne 0) { Write-Fail "Docker build failed. Aborting." }
    Write-OK "Book built successfully."
} else {
    Write-Host "    Skipping build (-SkipBuild)." -ForegroundColor Yellow
}

if (-not (Test-Path $BuildDir)) {
    Write-Fail "_build/html/ not found. Run without -SkipBuild first."
}

# step 2: get the remote URL
$RemoteUrl = (git remote get-url $Remote)
if ($LASTEXITCODE -ne 0) { Write-Fail "Cannot get URL for remote '$Remote'." }

# step 3: prepare temp deploy directory
Write-Step "Preparing deploy directory..."
New-Item -ItemType Directory -Path $TempDir | Out-Null

try {
    Push-Location $TempDir

    # Try to clone the existing gh-pages branch (preserves history)
    git clone --branch $Branch --depth 1 $RemoteUrl . 2>$null
    if ($LASTEXITCODE -ne 0) {
        # Branch does not exist yet - start a fresh orphan repo
        Write-Host "    Branch '$Branch' not found. Initialising fresh." -ForegroundColor Yellow
        git init --quiet
        git remote add $Remote $RemoteUrl
        git checkout --orphan $Branch 2>$null | Out-Null
    }

    # Wipe everything except .git
    Get-ChildItem -LiteralPath $TempDir -Force |
        Where-Object { $_.Name -ne ".git" } |
        Remove-Item -Recurse -Force

    # Copy the built HTML into the deploy dir
    Write-Host "    Copying HTML..."
    Copy-Item -Path "$BuildDir\*" -Destination $TempDir -Recurse -Force

    # Bypass Jekyll processing (needed for _static/ etc.)
    Set-Content -Path (Join-Path $TempDir ".nojekyll") -Value "" -NoNewline

    # commit
    git add -A
    $statusLines = git status --porcelain
    if (-not $statusLines) {
        Write-Host "    Nothing changed - gh-pages is already up to date." -ForegroundColor Yellow
    } else {
        $msg = "Deploy Jupyter Book $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        git commit -m $msg --quiet
        if ($DryRun) {
            Write-Host "    [DRY RUN] Would push to $Remote/$Branch - skipping." -ForegroundColor Yellow
            git log --oneline -1
        } else {
            git push $Remote "HEAD:refs/heads/$Branch" --force --quiet
            Write-OK "Pushed to $Remote/$Branch"
        }
    }

    Pop-Location

} finally {
    if (Test-Path $TempDir) {
        Set-Location $RepoRoot
        Remove-Item $TempDir -Recurse -Force
    }
}

Write-Step "Done!"
if (-not $DryRun) {
    Write-Host "`n  Settings -> Pages -> Deploy from branch -> gh-pages -> / (root)" -ForegroundColor Green
    Write-Host "  Site: https://modestsecdev.github.io/my-books/`n" -ForegroundColor Green
}

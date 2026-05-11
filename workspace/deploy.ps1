#!/usr/bin/env pwsh
# ════════════════════════════════════════════════════════════════════════════════
#  workspace/deploy.ps1 — Build and deploy Jupyter Book to GitHub Pages
#
#  USAGE
#    From the repository root:
#      .\workspace\deploy.ps1
#
#  WHAT IT DOES
#    1. Runs `docker compose run --rm build` to build the book locally.
#    2. If the build succeeds, pushes ONLY the built HTML (_build/html/)
#       to the `gh-pages` branch on origin.
#    3. GitHub Pages then serves from that branch.
#
#  REQUIREMENTS
#    - Docker Desktop running
#    - git remote `origin` pointing to the GitHub repository
#    - `git` available in PATH
#
#  NOTE
#    The markdown source files are NEVER pushed to GitHub.
#    Only the rendered HTML in _build/html/ is published.
# ════════════════════════════════════════════════════════════════════════════════

param(
    [switch]$SkipBuild,        # Skip the Docker build step (use existing _build/)
    [switch]$DryRun,           # Print what would happen without pushing
    [string]$Remote = "origin",
    [string]$Branch = "gh-pages"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── helpers ──────────────────────────────────────────────────────────────────

function Write-Step { param([string]$Msg) Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$Msg) Write-Host "    OK: $Msg" -ForegroundColor Green }
function Write-Fail { param([string]$Msg) Write-Host "    FAIL: $Msg" -ForegroundColor Red }

# ── locate repo root (the directory containing this script's parent) ──────────

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptDir
$BuildDir   = Join-Path $RepoRoot "_build\html"

Set-Location $RepoRoot
Write-Step "Repository root: $RepoRoot"

# ── step 1: build ─────────────────────────────────────────────────────────────

if (-not $SkipBuild) {
    Write-Step "Building Jupyter Book via Docker..."
    docker compose run --rm build
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Docker build failed. Aborting deploy."
        exit 1
    }
    Write-OK "Book built successfully."
} else {
    Write-Host "    Skipping build (-SkipBuild was set)." -ForegroundColor Yellow
}

if (-not (Test-Path $BuildDir)) {
    Write-Fail "_build/html/ not found at: $BuildDir"
    Write-Fail "Run without -SkipBuild, or check that the build completed."
    exit 1
}

# ── step 2: deploy to gh-pages using a git worktree ──────────────────────────

Write-Step "Deploying _build/html/ to branch '$Branch' on '$Remote'..."

$WorktreeDir = Join-Path $env:TEMP "jb-deploy-$(Get-Random)"

try {
    # Ensure the gh-pages branch exists on the remote (create orphan if needed)
    $branchExists = git ls-remote --heads $Remote $Branch 2>&1
    if (-not ($branchExists -match "refs/heads/$Branch")) {
        Write-Host "    Creating orphan branch '$Branch' on $Remote..." -ForegroundColor Yellow
        git checkout --orphan $Branch 2>&1 | Out-Null
        git rm -rf . 2>&1 | Out-Null
        "" | git commit --allow-empty-message -m "Initial gh-pages branch" --quiet
        git push $Remote $Branch --quiet
        git checkout - --quiet
    }

    # Add a worktree pointing to the gh-pages branch in a temp directory
    git worktree add $WorktreeDir $Branch --quiet

    # Sync _build/html/ into the worktree
    Write-Host "    Copying HTML to worktree..."
    $robocopyArgs = @($BuildDir, $WorktreeDir, "/MIR", "/NFL", "/NDL", "/NJH", "/NJS")
    robocopy @robocopyArgs | Out-Null
    # robocopy exit codes 0-7 are success
    if ($LASTEXITCODE -gt 7) {
        Write-Fail "robocopy failed with exit code $LASTEXITCODE"
        exit 1
    }

    # Add a .nojekyll file so GitHub Pages serves all files (including _static/)
    "" | Set-Content (Join-Path $WorktreeDir ".nojekyll") -NoNewline

    Push-Location $WorktreeDir
    try {
        git add -A
        $statusOutput = git status --porcelain
        if (-not $statusOutput) {
            Write-Host "    Nothing changed — gh-pages branch is already up to date." -ForegroundColor Yellow
        } else {
            $commitMsg = "Deploy Jupyter Book $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
            git commit -m $commitMsg --quiet

            if ($DryRun) {
                Write-Host "    [DRY RUN] Would push to $Remote/$Branch." -ForegroundColor Yellow
                git log --oneline -1
            } else {
                git push $Remote $Branch --quiet
                Write-OK "Pushed to $Remote/$Branch"
            }
        }
    } finally {
        Pop-Location
    }

} finally {
    # Always clean up the temporary worktree
    if (Test-Path $WorktreeDir) {
        git worktree remove $WorktreeDir --force 2>&1 | Out-Null
    }
}

Write-Step "Done!"
Write-Host @"

    GitHub Pages will serve the site from the '$Branch' branch.
    Make sure GitHub Pages is configured:
      Settings -> Pages -> Source -> Deploy from branch -> $Branch -> / (root)

    Site URL (after GitHub enables Pages):
      https://<org>.github.io/<repo>/

"@ -ForegroundColor Green

# ============================================
# Friends Of The Field River
# GitHub Pages Deployment
# ============================================

$ErrorActionPreference = "Stop"

# -----------------------------
# CONFIGURATION
# -----------------------------

$GitHubUser = "RealmsAU"
$Repository = "friends-of-the-field-river"

$RemoteUrl = "https://github.com/$GitHubUser/$Repository.git"

# -----------------------------
# MOVE TO SCRIPT LOCATION
# -----------------------------

Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host ""
Write-Host "================================="
Write-Host "Friends Of The Field River"
Write-Host "GitHub Deployment"
Write-Host "================================="
Write-Host ""

# -----------------------------
# CHECK FILES
# -----------------------------

if (-not (Test-Path "home.html")) {
    throw "home.html not found."
}

# -----------------------------
# VERIFY TOOLS
# -----------------------------

git --version | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Git is not installed."
}

gh --version | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "GitHub CLI is not installed."
}

# -----------------------------
# INIT REPO
# -----------------------------

if (-not (Test-Path ".git")) {

    Write-Host "Initializing repository..."

    git init

    git branch -M main
}

# -----------------------------
# CREATE REPOSITORY
# -----------------------------

gh repo view "$GitHubUser/$Repository" 2>$null

if ($LASTEXITCODE -ne 0) {

    Write-Host "Creating GitHub repository..."

    gh repo create `
        "$GitHubUser/$Repository" `
        --public `
        --source . `
        --remote origin
}

# -----------------------------
# REMOTE CHECK
# -----------------------------

$CurrentRemote = git remote get-url origin 2>$null

if (-not $CurrentRemote) {

    git remote add origin $RemoteUrl
}
elseif ($CurrentRemote -ne $RemoteUrl) {

    git remote remove origin
    git remote add origin $RemoteUrl
}

# -----------------------------
# CREATE GITHUB ACTION
# -----------------------------

$WorkflowPath = ".github\workflows"

if (-not (Test-Path $WorkflowPath)) {

    New-Item `
        -ItemType Directory `
        -Path $WorkflowPath `
        -Force | Out-Null
}

@"
name: Deploy Site

on:
  push:
    branches:
      - main

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:

  deploy:

    runs-on: ubuntu-latest

    environment:
      name: github-pages
      url: `${{ steps.deployment.outputs.page_url }}

    steps:

      - uses: actions/checkout@v4

      - uses: actions/configure-pages@v5

      - uses: actions/upload-pages-artifact@v3
        with:
          path: .

      - id: deployment
        uses: actions/deploy-pages@v4
"@ | Set-Content ".github\workflows\deploy.yml"

# -----------------------------
# COMMIT
# -----------------------------

git add .

$changes = git status --porcelain

if ($changes) {

    $Message = "Deploy $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    git commit -m $Message
}

# -----------------------------
# PUSH
# -----------------------------

try {

    git push -u origin main

}
catch {

    git push -u origin main --force
}

# -----------------------------
# ENABLE PAGES
# -----------------------------

try {

    gh api `
        repos/$GitHubUser/$Repository/pages `
        --method POST `
        --field source[branch]=main `
        --field source[path]=/

}
catch {}

# -----------------------------
# COMPLETE
# -----------------------------

$SiteUrl =
"https://$GitHubUser.github.io/$Repository/"

Write-Host ""
Write-Host "================================="
Write-Host "DEPLOYMENT COMPLETE"
Write-Host "================================="
Write-Host ""
Write-Host "Site URL:"
Write-Host $SiteUrl
Write-Host ""
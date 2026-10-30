# Publish a new Web build to GitHub Pages in one go:
#   1. export the "Web" preset headless into build/web
#   2. patch the service worker to network-first
#   3. re-zip build/web for itch.io (build/magic-war-web.zip)
#   4. commit everything (source + build/web) and push - GitHub Actions
#      then deploys build/web to Pages.
#
# Usage (from the project folder):
#   powershell -ExecutionPolicy Bypass -File tools\publish.ps1 "What changed"
# Finds Godot on either of our PCs automatically (see $candidates below);
# set $env:GODOT to override.

param([string]$Message = "")

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

# Godot console exe: $env:GODOT if set, otherwise the first of these that
# exists on this PC. Add a line here for any new machine.
$candidates = @(
    "D:\Godot\Godot_v4.7-stable_win64_console.exe",                         # Desktop (Alon)
    "C:\Users\akore\OneDrive\Godot\Godot_v4.7-stable_win64_console.exe"     # Other PC (akore)
)
$godot = $env:GODOT
if (-not $godot) { $godot = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1 }
if (-not $godot -or -not (Test-Path $godot)) {
    throw "Godot not found. Checked: $($candidates -join ', '). Set `$env:GODOT to your Godot console exe."
}
Write-Host "== Using Godot: $godot"
if (-not $Message) { $Message = "Web build " + (Get-Date -Format "yyyy-MM-dd HH:mm") }

Write-Host "== Exporting Web build..."
New-Item -ItemType Directory -Force build\web | Out-Null
& $godot --headless --export-release "Web" build/web/index.html | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path build\web\index.html)) {
    throw "Godot export failed (exit $LASTEXITCODE). Try exporting from the editor to see the error."
}

Write-Host "== Patching service worker..."
python tools/patch_service_worker.py build/web
if ($LASTEXITCODE -ne 0) { throw "Service worker patch failed." }

Write-Host "== Zipping for itch.io..."
Compress-Archive -Path build\web\* -DestinationPath build\magic-war-web.zip -Force

Write-Host "== Committing and pushing..."
git add -A
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "Nothing changed since the last publish - nothing to push."
    exit 0
}
git commit -m $Message
if ($LASTEXITCODE -ne 0) { throw "git commit failed." }
git push
if ($LASTEXITCODE -ne 0) { throw "git push failed." }

Write-Host ""
Write-Host "Pushed. GitHub is deploying it now (about 1 minute):"
Write-Host "  https://github.com/a-k983/magic-war/actions"
Write-Host "Live at: https://a-k983.github.io/magic-war/"

# Inject BetterTG.Windows sources into a Unigram checkout (best-effort hooks).
param(
  [Parameter(Mandatory = $true)][string]$UnigramRoot,
  [Parameter(Mandatory = $true)][string]$BetterTGWindowsRoot
)

$ErrorActionPreference = "Stop"
$dest = Join-Path $UnigramRoot "Telegram\BetterTG"
Write-Host "Copying BetterTG sources -> $dest"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Recurse -Force (Join-Path $BetterTGWindowsRoot "Models") $dest
Copy-Item -Recurse -Force (Join-Path $BetterTGWindowsRoot "Services") $dest
Copy-Item -Recurse -Force (Join-Path $BetterTGWindowsRoot "Helpers") $dest
Copy-Item -Recurse -Force (Join-Path $BetterTGWindowsRoot "Controls") $dest
Copy-Item -Recurse -Force (Join-Path $BetterTGWindowsRoot "ViewModels") $dest
# XAML pages optional for host; WinUI host uses its own pages later
if (Test-Path (Join-Path $BetterTGWindowsRoot "Docs")) {
  Copy-Item -Recurse -Force (Join-Path $BetterTGWindowsRoot "Docs") (Join-Path $dest "Docs")
}

# Marker file for verification
@"
// Auto-injected by Inject-BetterTG.ps1
// Integrate UI hooks per Docs/INTEGRATION.md and HOOK_SNIPPETS.md
"@ | Set-Content -Encoding UTF8 (Join-Path $dest "INJECTED.txt")

Write-Host "Injection complete. Wire settings navigation and message hooks manually or via follow-up patches."

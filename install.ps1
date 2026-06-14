# Bastion - one-line installer (Windows)
#
#   irm https://raw.githubusercontent.com/kritogmre/bastion/main/install.ps1 | iex
#
# Downloads the latest Windows release (native backend + signed extension),
# verifies integrity (sha256), installs into %LOCALAPPDATA%\Bastion, then runs
# the configurator. Authorized use only.
$ErrorActionPreference = "Stop"

$Owner = "kritogmre"
$Repo  = "bastion"
$InstallDir = Join-Path $env:LOCALAPPDATA "Bastion"
$Api  = "https://api.github.com/repos/$Owner/$Repo/releases/latest"

function Ok($m)   { Write-Host "  [OK] $m"  -ForegroundColor Green }
function Info($m) { Write-Host "  - $m"     -ForegroundColor Cyan }
function Warn($m) { Write-Host "  [!] $m"   -ForegroundColor Yellow }
function Step($m) { Write-Host "`n# $m"     -ForegroundColor Magenta }
function Die($m)  { Write-Host "  [X] $m"   -ForegroundColor Red; exit 1 }

Write-Host "`n   Bastion - installer (Windows)" -ForegroundColor Magenta

# ---------- dernière release ----------
Step "1/3 - Finding the latest version"
try {
  $meta = Invoke-RestMethod -Uri $Api -Headers @{ "User-Agent" = "bastion-installer" }
} catch { Die "Cannot reach the GitHub API ($Api)" }
$asset = $meta.assets | Where-Object { $_.name -like "*-windows.zip" }     | Select-Object -First 1
$shaA  = $meta.assets | Where-Object { $_.name -like "*-windows.zip.sha256" } | Select-Object -First 1
if (-not $asset) { Die "No Windows package in the latest release." }
Ok "version $($meta.tag_name)"

# ---------- télécharger + vérifier ----------
Step "2/3 - Download & verify"
$tmp = Join-Path $env:TEMP ("bastion_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp "bastion.zip"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -Headers @{ "User-Agent" = "bastion-installer" }
if ($shaA) {
  $shaFile = Join-Path $tmp "bastion.zip.sha256"
  Invoke-WebRequest -Uri $shaA.browser_download_url -OutFile $shaFile -Headers @{ "User-Agent" = "bastion-installer" }
  $expect = ((Get-Content -Raw $shaFile) -split '\s+')[0].Trim().ToLower()
  $got = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
  if ($expect -ne $got) { Die "Invalid checksum! (corrupted/tampered download)" }
  Ok "sha256 verified"
} else { Warn "no sha256 published - integrity not verified" }

# ---------- installer ----------
Step "3/3 - Installation"
# stop a running backend (otherwise app\bastion.exe cannot be replaced)
try { schtasks /End /TN "Bastion Backend" 2>$null | Out-Null } catch { $null = $_ }
try { Get-Process bastion -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue } catch { $null = $_ }
Start-Sleep -Milliseconds 600
if (Test-Path (Join-Path $InstallDir "app")) {
  Get-ChildItem $InstallDir -Exclude "bin" | Remove-Item -Recurse -Force -EA SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Expand-Archive -Path $zip -DestinationPath $tmp -Force
# the archive contains a bastion\ folder
Copy-Item -Path (Join-Path $tmp "bastion\*") -Destination $InstallDir -Recurse -Force
Remove-Item -Recurse -Force $tmp -EA SilentlyContinue
Ok "installed in $InstallDir"

$setup = Join-Path $InstallDir "setup.ps1"
if (Test-Path $setup) {
  Info "starting the configurator...`n"
  # same PowerShell engine that launched the installer (5.1 or 7+)
  $psExe = (Get-Process -Id $PID).Path
  if (-not $psExe) { $psExe = "powershell" }
  & $psExe -ExecutionPolicy Bypass -File $setup
} else {
  Warn "setup.ps1 not found - manual setup required."
}

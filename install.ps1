# Bastion - installeur en une ligne (Windows)
#
#   irm https://raw.githubusercontent.com/kritogmre/bastion/main/install.ps1 | iex
#
# Télécharge la dernière release Windows (backend obfusqué + extension signée),
# vérifie l'intégrité (sha256), installe dans %LOCALAPPDATA%\Bastion, puis lance
# le configurateur. Usage strictement autorisé.
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

Write-Host "`n   Bastion - installeur Windows" -ForegroundColor Magenta

# ---------- dernière release ----------
Step "1/3 - Recherche de la dernière version"
try {
  $meta = Invoke-RestMethod -Uri $Api -Headers @{ "User-Agent" = "bastion-installer" }
} catch { Die "Impossible de joindre l'API GitHub ($Api)" }
$asset = $meta.assets | Where-Object { $_.name -like "*-windows.zip" }     | Select-Object -First 1
$shaA  = $meta.assets | Where-Object { $_.name -like "*-windows.zip.sha256" } | Select-Object -First 1
if (-not $asset) { Die "Aucun paquet Windows dans la dernière release." }
Ok "version $($meta.tag_name)"

# ---------- télécharger + vérifier ----------
Step "2/3 - Téléchargement & vérification"
$tmp = Join-Path $env:TEMP ("bastion_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp "bastion.zip"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -Headers @{ "User-Agent" = "bastion-installer" }
if ($shaA) {
  $expect = ((Invoke-WebRequest -Uri $shaA.browser_download_url -Headers @{ "User-Agent" = "bastion-installer" }).Content -split '\s+')[0].Trim().ToLower()
  $got = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
  if ($expect -ne $got) { Die "Somme de contrôle invalide ! (téléchargement corrompu/altéré)" }
  Ok "sha256 vérifié"
} else { Warn "pas de sha256 publié - intégrité non vérifiée" }

# ---------- installer ----------
Step "3/3 - Installation"
if (Test-Path (Join-Path $InstallDir "backend")) {
  Get-ChildItem $InstallDir -Exclude "bin" | Remove-Item -Recurse -Force -EA SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Expand-Archive -Path $zip -DestinationPath $tmp -Force
# l'archive contient un dossier bastion\
Copy-Item -Path (Join-Path $tmp "bastion\*") -Destination $InstallDir -Recurse -Force
Remove-Item -Recurse -Force $tmp -EA SilentlyContinue
Ok "installé dans $InstallDir"

$setup = Join-Path $InstallDir "setup.ps1"
if (Test-Path $setup) {
  Info "lancement du configurateur...`n"
  & powershell -ExecutionPolicy Bypass -File $setup
} else {
  Warn "setup.ps1 introuvable - configuration manuelle requise."
}

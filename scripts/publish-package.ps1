<#!
.SYNOPSIS
  Publishes a package (binary + manifest) to the private winget source staging area.
.DESCRIPTION
  Uses generate-manifest.ps1 if no manifest exists, copies installer to a versioned folder matching expected URL layout, and (optionally) triggers index refresh placeholder.
.EXAMPLE
  ./scripts/publish-package.ps1 -PackageIdentifier 7zip.7zip -PackageVersion 23.01 -InstallerPath C:\temp\7z2301-x64.exe -StagingRoot \\fileserver\winget -UrlBase https://packages.internal.company/winget
#>
param(
  [Parameter(Mandatory)] [string] $PackageIdentifier,
  [Parameter(Mandatory)] [string] $PackageVersion,
  [Parameter(Mandatory)] [string] $InstallerPath,
  [Parameter(Mandatory)] [string] $StagingRoot,
  [string] $UrlBase = 'https://packages.internal.company/winget',
  [string] $Publisher = 'Unknown Publisher',
  [string] $PackageName = 'Unknown Package',
  [string] $InstallerType = 'exe',
  [string] $Architecture = 'x64',
  [switch] $ForceRegenerateManifest,
  [switch] $SkipManifest,
  [switch] $DryRun
)

function Write-Info($m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Write-Warn($m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Write-Err($m){ Write-Host "[ERR ] $m" -ForegroundColor Red }

if (-not (Test-Path $InstallerPath)) { throw "Installer not found: $InstallerPath" }
if (-not (Test-Path $StagingRoot)) { throw "Staging root not found: $StagingRoot" }

$relativePath = Join-Path (Join-Path ($PackageIdentifier -replace '\.', '/') $PackageVersion) (Split-Path $InstallerPath -Leaf)
$targetBinaryPath = Join-Path $StagingRoot $relativePath
$targetDir = Split-Path $targetBinaryPath -Parent

if (-not (Test-Path $targetDir)) { if ($DryRun){ Write-Info "Would create $targetDir" } else { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null } }

if (Test-Path $targetBinaryPath) {
  Write-Warn "Binary already exists at $targetBinaryPath"
} else {
  if ($DryRun){ Write-Info "Would copy $InstallerPath -> $targetBinaryPath" } else { Copy-Item $InstallerPath $targetBinaryPath }
}

$manifestRepoRoot = Split-Path $PSScriptRoot -Parent
$manifestsRoot = Join-Path $manifestRepoRoot 'manifests'
$identifierDir = Join-Path $manifestsRoot $PackageIdentifier
$versionDir = Join-Path $identifierDir $PackageVersion
$manifestFile = Join-Path $versionDir "$(($PackageIdentifier.Split('.')[-1])).installer.yaml"

if ($SkipManifest) {
  Write-Info "Skipping manifest generation by request"
} else {
  $needGen = $ForceRegenerateManifest -or -not (Test-Path $manifestFile)
  if ($needGen) {
    $genParams = @{
      PackageIdentifier = $PackageIdentifier
      PackageVersion = $PackageVersion
      Publisher = $Publisher
      PackageName = $PackageName
      InstallerPath = $InstallerPath
      InstallerType = $InstallerType
      Architecture = $Architecture
      UrlBase = $UrlBase
    }
    if ($DryRun){ Write-Info "Would invoke generate-manifest.ps1 with params: $($genParams | Out-String)" } else {
      $result = & (Join-Path $PSScriptRoot 'generate-manifest.ps1') @genParams
      Write-Info "Manifest generated: $($result.ManifestPath)"
    }
  } else {
    Write-Info "Manifest already exists: $manifestFile"
  }
}

# Placeholder: index rebuild (depends on chosen implementation). E.g. generate a source.json or invoke a custom indexer.
if ($DryRun){
  Write-Info 'Would trigger index refresh (placeholder)'
} else {
  Write-Info 'Index refresh placeholder (implement custom indexer here).'
}

Write-Info 'Publish complete.'

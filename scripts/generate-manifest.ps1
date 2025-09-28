<#!
.SYNOPSIS
  Generates a winget installer manifest YAML for a private source.
.DESCRIPTION
  Computes SHA256, creates directory structure under manifests/, and emits installer YAML.
.EXAMPLE
  ./scripts/generate-manifest.ps1 -PackageIdentifier 7zip.7zip -PackageVersion 23.01 -Publisher "Igor Pavlov" -PackageName "7-Zip" -InstallerPath C:\temp\7z2301-x64.exe -UrlBase https://packages.internal.company/winget
#>
param(
  [Parameter(Mandatory)] [string] $PackageIdentifier,
  [Parameter(Mandatory)] [string] $PackageVersion,
  [Parameter(Mandatory)] [string] $Publisher,
  [Parameter(Mandatory)] [string] $PackageName,
  [Parameter(Mandatory)] [string] $InstallerPath,
  [string] $InstallerType = 'exe',
  [string] $Architecture = 'x64',
  [string] $OutputRoot = (Join-Path $PSScriptRoot '..' 'manifests'),
  [string] $Locale = 'en-US',
  [string] $License = 'Proprietary',
  [string] $ShortDescription = 'Internal application.',
  [string] $UrlBase = 'https://packages.internal.company/winget',
  [string] $SilentSwitch = '/S',
  [string[]] $Tags = @()
)

if (-not (Test-Path $InstallerPath)) { throw "Installer not found: $InstallerPath" }
$hash = (Get-FileHash -Path $InstallerPath -Algorithm SHA256).Hash

# Directory structure: manifests/<Identifier>/<Version>
$manifestDir = Join-Path (Join-Path $OutputRoot $PackageIdentifier) $PackageVersion
if (-not (Test-Path $manifestDir)) { New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null }

$installerFileName = Split-Path $InstallerPath -Leaf
$packageUrl = (Join-Path (Join-Path $UrlBase $PackageIdentifier.Replace('.','/')) (Join-Path $PackageVersion $installerFileName)) -replace '\\','/'

$yamlPath = Join-Path $manifestDir "$($PackageIdentifier.Split('.')[-1]).installer.yaml"

$tagsBlock = ''
if ($Tags.Count -gt 0) {
  $tagsBlock = "Tags:`n" + ($Tags | ForEach-Object { "  - $_" }) -join "`n"
}

$yaml = @"
PackageIdentifier: $PackageIdentifier
PackageVersion: $PackageVersion
PackageLocale: $Locale
Publisher: $Publisher
PackageName: $PackageName
License: $License
ShortDescription: $ShortDescription
$tagsBlock
Installers:
  - Architecture: $Architecture
    InstallerType: $InstallerType
    Scope: machine
    InstallerUrl: $packageUrl
    InstallerSha256: $hash
    InstallerSwitches:
      Silent: $SilentSwitch
      SilentWithProgress: $SilentSwitch
"@

$yaml = $yaml.TrimEnd() + "`n"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($yamlPath, $yaml, $utf8NoBom)

Write-Host "Manifest written to $yamlPath" -ForegroundColor Green
[pscustomobject]@{
  ManifestPath = $yamlPath
  Hash = $hash
  Url = $packageUrl
}

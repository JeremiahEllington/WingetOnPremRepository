# Client Configuration (GPO, Manual, Intune)

Goal: Add the internal winget source (e.g. `Corp`) to all managed Windows clients and keep it updated.

## 1. Manual (One-Off Test)
```powershell
winget source add --name Corp --arg https://packages.internal.company/winget --type msstore
winget source list
winget source update
```
If the source already exists:
```powershell
winget source reset --name Corp
```

> Note: `--type` may be omitted for static sources. Adjust if using a REST implementation.

## 2. Scripted Add / Update (Reusable Function)
```powershell
$SourceName = 'Corp'
$SourceUrl  = 'https://packages.internal.company/winget'

$existing = winget source list | Select-String -Pattern "^$SourceName\b"
if ($existing) {
  Write-Host "Source '$SourceName' already present. Updating..." -ForegroundColor Cyan
  winget source update --name $SourceName
} else {
  Write-Host "Adding winget source '$SourceName'" -ForegroundColor Green
  winget source add --name $SourceName --arg $SourceUrl
}
```

## 3. Group Policy Deployment
Use a **Computer Startup Script** (PowerShell). Store script in a GPO-managed share (readable by Authenticated Users).

Script snippet (`Add-WingetSource.ps1`):
```powershell
Start-Transcript -Path "$env:ProgramData\\WingetCorpSource.log" -Append -ErrorAction SilentlyContinue
$ErrorActionPreference = 'Stop'
$SourceName = 'Corp'
$SourceUrl  = 'https://packages.internal.company/winget'

function Ensure-Source {
  $present = winget source list | Select-String -Pattern "^$SourceName\b"
  if ($present) {
    winget source update --name $SourceName | Out-Null
    Write-Host "Updated existing source $SourceName"
  } else {
    winget source add --name $SourceName --arg $SourceUrl | Out-Null
    Write-Host "Added new source $SourceName"
  }
}
try { Ensure-Source } catch { Write-Error $_ }
Stop-Transcript
```

GPO Steps (summary):
1. Create/Link GPO to target OU
2. Computer Configuration > Policies > Windows Settings > Scripts (Startup) > Add PowerShell script
3. Ensure the **Allow local scripts and remote signed scripts** execution policy via GPO if needed
4. Force gpupdate or reboot test machine

## 4. Intune (Microsoft Endpoint Manager) Deployment
You can deploy the private source via:
- Device Configuration (PowerShell script) – simplest
- Win32 App (packaged script) – if needing detection logic
- Configuration Profile (OMA-URI) – for advanced policies (future enhancement)

### 4.1 PowerShell Script Deployment (Recommended Initial Approach)
Create script `Add-WingetPrivateSource.ps1`:
```powershell
$SourceName = 'Corp'
$SourceUrl  = 'https://packages.internal.company/winget'

# Ensure winget exists
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Host 'winget not found – skipping (will retry next run)'
  exit 0
}

# Idempotent add/update
$present = winget source list | Select-String -Pattern "^$SourceName\b"
if ($present) {
  winget source update --name $SourceName | Out-Null
  Write-Host "Updated existing source $SourceName"
} else {
  winget source add --name $SourceName --arg $SourceUrl | Out-Null
  Write-Host "Added source $SourceName"
}
```
Intune Portal:
1. Devices > Scripts > Add > Windows 10 and later > PowerShell
2. Upload script, run as 64-bit, run as system
3. Assign to device group(s)
4. Monitor `IntuneManagementExtension.log` for success

### 4.2 Win32 App Packaging (Optional)
Use when you want detection + retry logic packaged:
1. Save script and supporting files to a folder
2. Use **IntuneWinAppUtil.exe** to package
3. Detection rule: `winget source list` contains `Corp`
4. Install command: `powershell.exe -ExecutionPolicy Bypass -File .\Add-WingetPrivateSource.ps1`
5. Uninstall command (optional): `winget source remove --name Corp`

### 4.3 Detection & Remediation (Proactive Remediations)
- Detection script: returns non-zero if source missing
- Remediation script: adds/updates source using logic above
Useful for ensuring drift correction on long-lived devices.

## 5. Verification Commands
```powershell
winget source list
winget install 7zip.7zip --source Corp --silent --accept-source-agreements --accept-package-agreements
```

## 6. Common Issues
| Symptom | Cause | Resolution |
|---------|-------|------------|
| Source add fails (404) | IIS path or MIME misconfig | Verify URL + YAML served | 
| TLS/Cert warning | Untrusted internal CA | Deploy root cert via GPO/Intune | 
| winget not found | App Installer not provisioned | Install App Installer package first | 
| Access denied adding source | Running as standard user (system source) | Run in elevated/system context | 

## 7. Scheduling Periodic Refresh
Intune Scheduled Task alternative:
- Use a remediation pair weekly to run `winget source update --name Corp`

## 8. Removal
```powershell
winget source remove --name Corp
```
Deploy removal script if decommissioning service.

## 9. Logging
- Store script logs in `%ProgramData%` (GPO script using `Start-Transcript`)
- Forward via existing log collection (e.g., Defender for Endpoint custom indicators if needed)

---
Future enhancement: OMA-URI profile for pre-configuring source once Microsoft exposes formal CSP (monitor documentation).

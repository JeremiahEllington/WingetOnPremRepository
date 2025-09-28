# Server Setup (IIS) for Private winget Source

> Goal: Host internal winget manifests + binaries over HTTPS with predictable, versioned paths.

## 1. Prerequisites
- Windows Server 2022 (or 2019) with IIS
- Internal CA issued TLS certificate (CN = packages.internal.company)
- Service account (least privilege) for content deployment (optional)
- PowerShell 5.1+ (Windows default) and optionally 7.x for admin scripts

## 2. Install IIS Components (PowerShell)
```powershell
Install-WindowsFeature Web-Server,Web-Static-Content,Web-Http-Redirect,Web-Default-Doc,Web-Http-Errors,Web-Log-Libraries,Web-Request-Monitor,Web-Filtering -IncludeManagementTools
```
Optional (if using compression):
```powershell
Install-WindowsFeature Web-Dyn-Compression,Web-Stat-Compression
```

## 3. Directory Layout (Example)
```
D:\winget-repo\
  manifests\
    7zip\7zip\23.01\7zip.installer.yaml
    Contoso.SampleApp\1.0.0\sampleapp.installer.yaml
  packages\
    7zip\7zip\23.01\7z2301-x64.exe
  index\ (future: generated source index JSON/metadata)
```
You may colocate binaries adjacent to manifests; keeping them separate (`manifests` vs `packages`) simplifies retention policies.

## 4. Create IIS Site
```powershell
Import-Module WebAdministration
New-Item -Path IIS:\Sites -Name "WingetRepo" -PhysicalPath "D:\winget-repo" -Type Site -Bindings @{protocol='https';bindingInformation='*:443:packages.internal.company'}
# Assign certificate (thumbprint example)
New-Item -Path IIS:\SslBindings -Value @{IPAddress='*';Port=443;Hostname='packages.internal.company';Thumbprint='THUMBPRINT';CertStoreLocation='Cert:\LocalMachine\My'}
```
Or bind cert via IIS Manager GUI.

## 5. MIME Types
Ensure these are present (IIS Manager > MIME Types):
| Extension | MIME Type |
|-----------|-----------|
| .yaml     | text/yaml |
| .yml      | text/yaml |
| .json     | application/json |
| .msixbundle | application/vnd.ms-appx | 

Add via PowerShell if missing:
```powershell
Add-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/staticContent" -name . -value @{fileExtension='.yaml';mimeType='text/yaml'} -ErrorAction SilentlyContinue
```
(Repeat for additional extensions.)

## 6. Hardening
- Enforce TLS 1.2+ (disable legacy protocols via registry / GPO)
- Enable HTTP response headers:
  - `Strict-Transport-Security: max-age=31536000; includeSubDomains`
  - `X-Content-Type-Options: nosniff`
  - `Content-Security-Policy: default-src 'none'` (static content only)
- Optional mutual TLS: require client certs (IIS > SSL Settings) for restricted networks
- Request Filtering: deny double file extensions, executable uploads (if any admin upload surface is exposed)

## 7. Content Deployment Pattern
Preferred: publish from Git repo (CI pipeline) to server via:
- Robocopy (clean + mirror) to staging path then atomic swap
- Web Deploy package (msdeploy)
- Artifact copy in Azure DevOps / GitHub Actions self-hosted runner

Avoid editing content manually on server.

## 8. Index / Source Model
A private winget source typically needs an index (REST or static). This repo uses a simple static layout; later you can:
- Generate an `index.json` enumerating all manifests + SHAs
- Provide simple REST endpoints (optional) if adopting upstream schema

Placeholder generation command (future):
```powershell
# Pseudo: Enumerate manifests and emit index.json
Get-ChildItem D:\winget-repo\manifests -Filter *.yaml -Recurse | ForEach-Object { }
```

## 9. Logging & Monitoring
- Enable IIS access logs (centralized to SIEM) – track downloads & anomalies
- Set retention (e.g., 30–90 days) or ship to Log Analytics
- Implement synthetic probe (scheduled script) verifying source accessibility + sample install

## 10. Backup & DR
- Include `manifests` (text = small) in Git => reduces restore scope
- Binary retention: consider artifact store + replication instead of relying only on server disk
- Document RPO/RTO for repository (usually low risk; RPO 24h may be acceptable)

## 11. Performance Considerations
- Enable compression (YAML/JSON benefit modest, still fine)
- Use CDN/Reverse Proxy for remote sites if bandwidth-constrained
- Consider ETag or `Last-Modified` headers for client caching

## 12. Validation Checklist
| Item | Verified |
|------|----------|
| TLS certificate trusted | ☐ |
| YAML served with 200 OK | ☐ |
| MIME correct for .yaml/.json | ☐ |
| winget source add succeeds | ☐ |
| Test install of sample package | ☐ |
| Logs visible in central system | ☐ |

## 13. Next Steps
- Implement automated index builder
- Add code signing for internal EXE/MSI (if possible)
- Integrate hash verification in CI

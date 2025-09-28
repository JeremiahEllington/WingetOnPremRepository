# Troubleshooting

Common issues, diagnostics, and recovery steps for the private winget source.

## 1. Client Cannot Add Source
| Symptom | Likely Cause | Action |
|---------|--------------|--------|
| 404 Not Found | Wrong URL or missing file | Browse URL in browser; verify path & case |
| 403 Forbidden | ACL / auth restriction | Check IIS logs + NTFS ACLs |
| TLS/Cert error | Untrusted internal CA | Deploy root/intermediate cert via GPO/Intune |
| Timeout | Firewall / proxy | Test `Invoke-WebRequest` to URL; check network path |

## 2. Install Fails (Hash Mismatch)
| Cause | Resolution |
|-------|-----------|
| Binary replaced but manifest not updated | Regenerate hash with `Get-FileHash` and update manifest |
| Corrupted download / partial file | Re-upload binary; check IIS logs for size |
| Wrong architecture served | Confirm correct file placed in version folder |

## 3. winget Source Not Visible After Script
- Run `winget source list`
- Force update: `winget source update --name Corp`
- Reset: `winget source reset --name Corp`
- Ensure script executed elevated (system or admin)

## 4. IIS Diagnostics
```powershell
Get-ChildItem 'C:\inetpub\logs\LogFiles' -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 5 FullName
```
Check latest log for request status codes.

Failed requests tracing (if enabled): review `%SystemDrive%\inetpub\logs\FailedReqLogFiles` for rich detail.

## 5. Validate MIME Types
```powershell
# Quick test expecting YAML
Invoke-WebRequest https://packages.internal.company/winget/manifests/7zip/7zip/23.01/7zip.installer.yaml -UseBasicParsing | Select-Object -ExpandProperty Content | Select-String 'PackageIdentifier'
```
If blocked, check request filtering or firewall.

## 6. Connection & TLS
```powershell
Test-NetConnection packages.internal.company -Port 443
```
If SNI/cert mismatch: inspect with `openssl s_client -connect host:443 -servername packages.internal.company` from a capable machine.

## 7. Source Cache Issues
Clear and re-add:
```powershell
winget source remove --name Corp
winget source add --name Corp --arg https://packages.internal.company/winget
```

## 8. Publishing Problems
| Issue | Action |
|-------|-------|
| Manifest not found by clients | Rebuild index / ensure directory accessible |
| Old version still installing | Clients caching; run `winget source update` on endpoints |
| Access denied copying files | Check service account NTFS Modify rights |

## 9. Logging Strategy
- Standardize log location for publish scripts: e.g., `\\fileserver\logs\winget-publish`.
- Central ingestion: forward IIS + script logs to SIEM.

## 10. Performance
| Symptom | Mitigation |
|---------|-----------|
| Slow downloads remote sites | Add caching proxy/CDN or branch DFS replication |
| High disk usage | Implement retention (keep last N versions) + archive older |

## 11. Verification Script Snippet
```powershell
$errors = @()
if (-not (winget source list | Select-String '^Corp')) { $errors += 'Source missing' }
$test = winget show 7zip.7zip --source Corp 2>$null
if (-not $test) { $errors += 'Package metadata not retrievable' }
if ($errors.Count -gt 0) { Write-Host "FAILED: $($errors -join ', ')" -ForegroundColor Red; exit 1 } else { Write-Host 'OK' -ForegroundColor Green }
```

## 12. Escalation Data to Collect
- Request logs (IIS) for failing client IP(s)
- Hash from manifest vs recomputed hash
- Script transcript from deployment
- Network trace (if suspected proxy interference)

## 13. When to Rebuild Index
- After adding/removing multiple manifests
- After structural changes to directory layout
- If clients report stale or missing packages despite updated content

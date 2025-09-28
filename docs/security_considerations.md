# Security Considerations

Comprehensive guidance to reduce risk operating a private winget repository.

## 1. Threat Model (Abbreviated)
| Vector | Risk | Mitigation |
|--------|------|------------|
| Tampered binary | Malicious payload distribution | Code signing, SHA256 hash, restricted write ACLs |
| Unauthorized source addition | Lateral movement / data exfil | Deploy source only via managed channels (GPO/Intune) |
| MITM / downgrade | Hash mismatch or silent compromise | Enforce HTTPS (TLS1.2+), HSTS, pin internal CA trust |
| Stale / vulnerable versions | Unpatched software exposure | Version review cadence, vulnerability scanning |
| Credential leakage in scripts | Privilege escalation | No secrets in manifests; use managed identities / service accounts |

## 2. Transport Security
- HTTPS only; redirect HTTP → HTTPS (301)
- Internal CA or publicly trusted cert; monitor expiration (alert ≥30 days)
- Disable obsolete protocols (SSL, TLS1.0/1.1)
- Enable HSTS: `Strict-Transport-Security: max-age=31536000; includeSubDomains`

## 3. Content Integrity
| Control | Recommendation |
|---------|---------------|
| SHA256 | Always present for every installer; regenerate on repackage |
| Code Signing | Sign MSI/EXE with enterprise code signing cert where possible |
| SBOM | Store SBOM (CycloneDX/SPDX) for internal builds adjacent to artifacts |
| Hash Recalc | CI recomputes and diffs hash vs manifest; hard fail on mismatch |
| Immutable Versions | Never overwrite an existing version path; add new folder |

## 4. Access Control & Publishing
- Split roles: Authors (prepare) vs Publishers (approve + merge)
- Use branch protection (require PR review + status checks)
- Staging vs Production repo or branch; promote via automated pipeline
- Least privilege on IIS content root (no interactive logon, service account RW, others RO)

## 5. Supply Chain Defense
| Layer | Action |
|-------|--------|
| Upstream Binaries | Retrieve from official vendor over TLS; verify vendor signature |
| Malware Scanning | Run AV + reputation scan in CI (e.g., Defender MpCmdRun) |
| Vulnerability DB | Periodic check of published versions vs CVE feed |
| Dependency Tracking | Internal builds publish SBOM; track diffs per release |

## 6. Logging & Monitoring
- IIS access logs → central SIEM (download spikes, unusual 404/401)
- Script logs in `%ProgramData%` or pipeline artifacts
- Failed hash/validation events raise alerts
- Optional: store manifest + binary checksums in an append‑only log (e.g., ledger DB) for tamper evidence

## 7. Key & Certificate Management
| Item | Guidance |
|------|----------|
| TLS Cert | Renew automatically (ACME internal) or track expiry | 
| Code Signing Cert | Hardware-backed (HSM) or EV store; restrict export |
| Hash Data | Derived, not secret; never transmit over insecure channels |

## 8. Hardening Checklist
| Item | Status |
|------|--------|
| TLS1.2+ enforced | ☐ |
| HSTS enabled | ☐ |
| Directory browse disabled | ☐ |
| Write ACL restricted to publisher account(s) | ☐ |
| Branch protections configured | ☐ |
| CI hash validation active | ☐ |
| Malware scan integrated | ☐ |
| Code signing (where feasible) | ☐ |
| Version immutability policy documented | ☐ |
| Access logs forwarded | ☐ |

## 9. Incident Response (Quick)
1. Revoke access / freeze publishing branch
2. Identify affected packages + versions
3. Compare stored hash ledger vs manifests
4. Pull compromised binaries (mark deprecated) & publish advisory
5. Force `winget source reset` on clients (scripted)

## 10. Future Enhancements
- Transparency log (e.g., Sigstore Rekor) for manifests
- Automatic CVE correlation service
- SBOM diff automation reporting new components

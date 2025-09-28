# Private On-Prem Winget Repository

Enterprise guidance for hosting and operating an internal Windows Package Manager (winget) source for software distribution across a domain.

## Why
- Control: Curate only approved software & versions
- Compliance: Retain binaries internally (air‑gap / audit)
- Speed: LAN delivery vs external CDN
- Stability: Freeze versions for testing rings

## High-Level Architecture (Text Diagram)
```
[Admins]
   | (publish manifests + binaries)
   v
[Staging Share / Git Repo] --> CI (hash, schema lint) --> [Web Server/IIS: Private Winget Source]
                                                            |
                                                     HTTPS (mutual TLS optional)
                                                            |
                                                      [Domain Clients]
```

## Repository Layout
```
/manifests/
  ContosoApp/
    1.0.0/contosoapp.installer.yaml
/scripts/
  generate-manifest.ps1
  publish-package.ps1
/docs/
  server_setup_iis.md
  client_configuration_gpo.md
  security_considerations.md
  troubleshooting.md
  automation_ci.md
/templates/
  manifest_template.yaml
```

## Quick Start (Conceptual)
1. Set up IIS (or static HTTPS) site: https://packages.internal.company/winget
2. Enable MIME types: .json, .yaml
3. Place index + manifests under site root following winget source schema
4. Add source on a client:
   ```powershell
   winget source add --name Corp --arg https://packages.internal.company/winget
   winget source list
   ```
5. Publish first package via script (forthcoming)

## Manifest Basics
A package usually has multi-file manifests (version, installer, locale). For brevity this repo shows a single installer YAML pattern first.

## Security Considerations (Preview)
- Serve over HTTPS only (internal CA or public cert)
- Optional mTLS or conditional access (reverse proxy)
- Code sign installers where possible
- Hash validation (SHA256) enforced in manifest
- Least privilege publish pipeline (no direct IIS write from developer desktops)

## Roadmap
- Sample multi-file manifest set
- Hash & schema validation scripts
- Optional NuGet-style layout alternative
- CI example (GitHub Actions / Azure DevOps)

## Status
Initial scaffold. Additional docs coming next.

# Supply chain security policy

This document defines supply chain security standards and procedures for BridgeWatcher, aligned with
ISO 27001:2022 Annex A control A.5.23 (Cloud Service Security) and Annex A control A.8.9 (Configuration Management).

## 1. Third-party dependency rules

To prevent dependency confusion, typosquatting, and malicious package injection, the following policies apply:

### 1.1 Docker base images

- All base images must be sourced from official registries (such as the Docker Hub official Alpine image).
- Images must specify an exact version tag and be pinned by their cryptographic SHA256 digest to ensure builds
  are reproducible and immutable.
- Example: `alpine:3.23@sha256:57a4d1f2e4...`

### 1.2 GitHub Actions workflows

- All third-party GitHub Actions must be pinned to a full 40-character git commit SHA rather than a mutable
  branch or version tag.
- Version tags may be added as end-of-line comments for readability and tool updates (such as Dependabot).
- Example: `uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2`

### 1.3 PowerShell modules

- PowerShell modules installed at runtime or during build (such as Pester or PSScriptAnalyzer) must declare
  minimum or exact version limits.
- Public galleries should be trusted explicitly in build environments only after verification.

## 2. Dependency auditing and vulnerability management

- Automated scanning: The container image and build environment are scanned on every push or release using Trivy.
- Severity thresholds: Vulnerabilities categorized as Critical or High block build promotion and must be remediated
  either by upgrading the package or documenting a security exception with justification.
- SBOM generation: A machine-readable Software Bill of Materials (SBOM) in CycloneDX format must be generated
  for each release image to allow continuous tracking of packages.

## 3. Secret leakage prevention

- CI/CD scanning: Gitleaks analyzes all commits and pull requests for hardcoded secrets, API keys, or certificates.
- Local pre-commit: Operators are encouraged to configure Gitleaks locally as a git pre-commit hook to block
  credential commits before they leave the workstation.

---

Last reviewed: 2026-06-26. Review frequency: annually.

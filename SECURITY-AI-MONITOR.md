# Security scope and limitations

This is a limited source review, not a penetration test, independent audit, or guarantee of safety.

## Reviewed facts

- The AI Monitor UI changes introduce no network destinations, credential reads, or model inference requests. Mac status uses local system statistics.
- Upstream provider/core code and dependency manifests were unchanged from the stated baseline. This does not prove those upstream components are free of vulnerabilities.
- The reviewed Claude CLI path requests `/usage` and `/status`. Its launch arguments disable all hooks and remote control, clear allowed tools, and use strict MCP configuration. The installed CLI and its provenance must still be trusted.
- The reviewed Claude OAuth fetcher targets `https://api.anthropic.com`; Codex OAuth includes OpenAI/ChatGPT endpoints. This is not an exhaustive audit of every optional provider and every runtime network request.
- A Claude OAuth token observed during private verification included `user:inference`; it must not be described as a guaranteed read-only token. No actual token is included here.

## Remaining risks

Credential-bearing software, a malicious dependency, compromised device, modified CLI, or tampered binary can expose sessions or misuse the permissions they carry. Keep providers limited to those you need, review updates, and revoke sessions if compromise is suspected. Source availability helps review but is not a safety certification.

Credential settings are per-user, not bundled defaults that silently authorize access. CLI mode is available when direct Keychain reading is not desired. The public export excludes personal configs, logs, account snapshots, signing keys and signing private keys. The separately published application is development-signed and not notarized.

The MIT license and upstream attribution remain intact. Do not publish credential-bearing bug reports or screenshots.

# Security Policy

## Scope

`apiosk-publish` manages API listings on the Apiosk gateway using signed wallet auth headers.

## Credential Handling

- This skill does not read local signing key material.
- This skill does not store local signing key material.
- Signatures are provided explicitly via `--signature` or `APIOSK_AUTH_SIGNATURE`.

## Data Access

- Reads wallet address from:
  - `--wallet`
  - `~/.apiosk/wallet.txt`
  - `~/.apiosk/wallet.json` (`address` field only, backward compatibility)
- Writes: none

## Network Access

Scripts call only:

- `https://gateway.apiosk.com`

## Command Safety

- No pipe-to-shell install patterns.
- No remote code download/execution.
- No dynamic shell evaluation from remote input.

## Reporting

Report security issues to `security@apiosk.com`.

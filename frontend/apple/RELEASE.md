# 100J Apple Personal Account Release

This release path targets a personal Apple account and local/private installation. Do not commit Apple ID credentials, provisioning profiles, private keys, exported certificates, or app-specific passwords.

## macOS Local Package

```bash
frontend/apple/scripts/package-macos-app.sh
```

The package script builds a release executable with a scratch path under `/tmp`, creates `frontend/apple/dist/100J.app`, ad-hoc signs it for local/private installation, verifies the signature, and writes a timestamped zip next to the app bundle.

For v1.1 P6, this ad-hoc package is the macOS release artifact. Public distribution signing is intentionally outside this personal-account release.

## iPhone Local Install

Open the Xcode project:

```text
frontend/apple/PersonalAffairsApp.xcodeproj
```

Use the `PersonalAffairsApp` scheme, select the app target, enable automatic signing with the personal team, then run directly on the iPhone. The default Bundle ID is `top.linotsai.app.PersonalAffairs`; if Xcode requires a unique ID for the personal team, change it locally in Xcode without committing credential or profile material.

## Backend Release

P6 deploys the backend to HZ through:

```bash
scripts/deploy-hz.sh
scripts/prod-check.sh
```

Production keeps Email OTP disabled with `EMAIL_OTP_ENABLED=false`. Login acceptance uses the advanced/self-host access-code path. Apple Sign-In remains in code and tests, but it is not a personal-account release blocker.

## Monitoring

Use Apple-native and server-native signals first:

- Xcode Organizer crash reports for local device runs.
- Backend `scripts/prod-check.sh` for API health, systemd, Nginx, TLS, backups, recent errors, and production smoke.
- In-app diagnostics export for sanitized client logs.

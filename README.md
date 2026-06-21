# GLabTouch

GLabTouch is an iOS app for GitLab self-hosted instances, focused on mobile merge request approval and pipeline monitoring.

## Features

- Personal Access Token login
- OAuth 2.0 PKCE login with `glabtouch://oauth/callback`
- Configurable GitLab base URL with saved instance switching
- Keychain token storage
- Merge request filters for assigned, created, and review-requested work
- Merge request detail with approval and revoke actions
- File-level and line-level diff viewing
- Read-only Pipeline status with stage and job breakdown
- APNs registration entry and standardized notification payload model
- Configurable local polling fallback with badge updates
- English and Simplified Chinese UI

## Development

```bash
./scripts/run-unit-tests.sh
xcodebuild -project GlabTouch.xcodeproj -scheme GlabTouch -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
./scripts/e2e-smoke.sh
```

## TestFlight

See [docs/TestFlight.md](docs/TestFlight.md).

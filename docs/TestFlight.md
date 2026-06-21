# TestFlight Release Checklist

## App Store Connect

- Bundle ID: `com.zephyrdeng.GlabTouch`
- Platform: iOS 18+
- Version: `1.0.0`
- Build: `1`
- OAuth redirect URI for GitLab applications: `glabtouch://oauth/callback`
- Languages: English, Simplified Chinese
- App icon: `GlabTouch/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
- Privacy manifest: `GlabTouch/PrivacyInfo.xcprivacy`
- Push Notifications entitlement: `GlabTouch/GlabTouch.entitlements`

## Local Verification

```bash
./scripts/run-unit-tests.sh
./scripts/e2e-smoke.sh
xcodebuild -project GlabTouch.xcodeproj -scheme GlabTouch -configuration Release -destination 'generic/platform=iOS' build
```

## Archive and Upload

```bash
DEVELOPMENT_TEAM=<APPLE_TEAM_ID> ./scripts/archive-testflight.sh
```

With an App Store Connect API key:

```bash
DEVELOPMENT_TEAM=<APPLE_TEAM_ID> \
ASC_KEY_PATH=/path/to/AuthKey_XXXX.p8 \
ASC_KEY_ID=<KEY_ID> \
ASC_ISSUER_ID=<ISSUER_ID> \
./scripts/archive-testflight.sh
```

## Live GitLab Smoke

- Sign in with a GitLab Personal Access Token carrying `api` scope.
- Open Merge Requests and verify assigned, created, and review-requested filters.
- Open a merge request, verify approval state, file diff list, line-level additions/deletions, and Pipeline stage/job breakdown.
- Open Pipelines and verify read-only status aggregation for current user merge requests.
- Open Settings and verify saved instance switching, APNs registration state, and local polling badge refresh.
- Sign out, then relaunch and verify the app returns to the login screen.

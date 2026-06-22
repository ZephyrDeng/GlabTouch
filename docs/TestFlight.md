# TestFlight 发布操作指引

本文记录 GLabTouch 的公开 TestFlight 发布流程。真实 Apple 凭证、证书、profile、reviewer 联系方式和本机路径保存在私有发布 runbook 或本地 ignored skill。

安全边界：

- 不要把 `.p8`、`.p12`、私钥、证书密码、JWT、PAT、Apple ID 密码提交进仓库。
- 不要把 App Store Connect Issuer ID、API Key ID、Apple Team ID、证书 ID、profile UUID、签名身份实名、本机用户路径提交进公开仓库。
- 本文只保留公开流程、占位符、build 状态和可复用命令结构。
- 审核联系人、测试账号和公开邀请链接保存在 App Store Connect 或私有发布 runbook。

## 当前 App Store Connect 状态

- App Name: `GLabTouch`
- Bundle ID: `com.zephyrdeng.GlabTouch`
- Version: `1.2.0`
- Current build: `4`
- OAuth redirect URI for GitLab applications: `glabtouch://oauth/callback`
- Public Beta group: configured in App Store Connect
- Public Link: enabled; accepts public testers after Apple sets the build to `BETA_APPROVED`
- Build 4 state on 2026-06-22: `processingState=VALID`, `internalBuildState=IN_BETA_TESTING`, `externalBuildState=WAITING_FOR_BETA_REVIEW`
- Build 3 state on 2026-06-22: `processingState=VALID`, `internalBuildState=IN_BETA_TESTING`, `externalBuildState=WAITING_FOR_BETA_REVIEW`
- Build 2 state on 2026-06-22: `processingState=VALID`, `internalBuildState=IN_BETA_TESTING`, `externalBuildState=IN_BETA_TESTING`
- Build 1 state on 2026-06-22: `processingState=VALID`, `internalBuildState=IN_BETA_TESTING`, `externalBuildState=NOT_APPLICABLE`
- Internal group: configured in App Store Connect

## Version and Tag Workflow

Version rules:

- `MARKETING_VERSION` changes only for a user-visible release line, for example `1.0.0` to `1.1.0`.
- `CURRENT_PROJECT_VERSION` changes before every App Store Connect upload. It must be higher than all existing builds for the same `MARKETING_VERSION`.
- Intermediate feature commits do not need a version bump until they are part of a TestFlight upload.
- The release tag is created after all release-prep commits, upload docs, export compliance, and App Store Connect status notes are in the repository.

Commit and tag order for a TestFlight release:

1. Commit feature, UI, docs, and release automation changes.
2. Bump `CURRENT_PROJECT_VERSION`, and bump `MARKETING_VERSION` when the release line changes.
3. Run local validation and upload to TestFlight.
4. Update `docs/TestFlight.md` with the verified App Store Connect state.
5. Create or move the annotated tag `v<MARKETING_VERSION>` to the final release-ready commit.

For the current release line, `v1.2.0` should point at the final commit that includes build `4`, TestFlight upload, export compliance, and release documentation.

Historical note: build `2` was uploaded on `2026-06-21T07:19:37-07:00` before this workflow was codified. From build `3` onward, every App Store Connect upload build number must appear in a committed version bump.

## 私有签名材料

这些材料属于私有发布上下文，只能保存在本机 ignored skill、私有 runbook、Keychain 或 App Store Connect 中。

私有材料包括：

- App Store Connect API private key (`.p8`)
- App Store Connect API Key ID and Issuer ID
- Apple Team ID
- Apple Distribution certificate details and signing identity
- Certificate private key, CSR, PEM, and P12 files
- Provisioning profile name, ID, UUID, and installed path
- Reviewer contact details, demo account, and tester invitations

Check local signing identities:

```bash
security find-identity -p codesigning -v
```

Expected relevant identity:

```text
Apple Distribution
```

Inspect an installed profile with a local path from the private runbook:

```bash
security cms -D -i "<path-to-app-store-profile.mobileprovision>" | plutil -p -
```

## 仓库内发布配置

- Export options: `Config/TestFlightExportOptions.plist`
- Archive script: `scripts/archive-testflight.sh`
- App Info.plist: `GlabTouch/Info.plist`
- Xcode project build number: `GlabTouch.xcodeproj/project.pbxproj`

Current export settings:

- `method=app-store-connect`
- `destination=upload`
- `signingStyle=manual`
- `teamID=<APPLE_TEAM_ID>`
- `signingCertificate=Apple Distribution`
- `provisioningProfiles[com.zephyrdeng.GlabTouch]=<APP_STORE_PROVISIONING_PROFILE_NAME>`
- `testFlightInternalTestingOnly=false`
- `uploadSymbols=true`

`scripts/archive-testflight.sh` copies the public export options into `build/TestFlightExportOptions.resolved.plist` and injects private signing values from environment variables at runtime.

Export compliance:

- `GlabTouch/Info.plist` contains `ITSAppUsesNonExemptEncryption=false`.
- GLabTouch uses system `URLSession`, Keychain, and OAuth PKCE hashing. Its encryption usage stays within exempt system capabilities.

## 发布前检查

Run local checks:

```bash
./scripts/run-unit-tests.sh
./scripts/e2e-smoke.sh
xcodebuild -project GlabTouch.xcodeproj \
  -scheme GlabTouch \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  build
```

Check the build number before uploading. App Store Connect rejects duplicate build numbers for the same version.

```bash
rg -n "CURRENT_PROJECT_VERSION|MARKETING_VERSION" GlabTouch.xcodeproj/project.pbxproj
```

Update `CURRENT_PROJECT_VERSION` to the next integer before each upload.

## Archive and Upload

Use local environment variables from the private runbook:

```bash
rm -rf build/GlabTouch.xcarchive build/TestFlight

ASC_KEY_PATH="${ASC_KEY_PATH:?Set local App Store Connect .p8 path}" \
ASC_KEY_ID="${ASC_KEY_ID:?Set App Store Connect API key id}" \
ASC_ISSUER_ID="${ASC_ISSUER_ID:?Set App Store Connect issuer id}" \
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:?Set Apple team id}" \
CODE_SIGN_STYLE="Manual" \
CODE_SIGN_IDENTITY="Apple Distribution" \
PROVISIONING_PROFILE_SPECIFIER="${PROVISIONING_PROFILE_SPECIFIER:?Set App Store profile name}" \
./scripts/archive-testflight.sh
```

Expected terminal signals:

```text
** ARCHIVE SUCCEEDED **
Uploaded GlabTouch
** EXPORT SUCCEEDED **
```

Because `destination=upload`, the export may skip a local `build/TestFlight` IPA directory. Confirm upload from App Store Connect or the API.

## App Store Connect 分发流程

1. Open `GLabTouch > TestFlight`.
2. Wait for the uploaded build to finish processing.
3. Confirm export compliance. Future builds should inherit `ITSAppUsesNonExemptEncryption=false`.
4. Internal testing:
   - Use group `GlabTouch Internal Tester`.
   - Add the latest build.
   - Add App Store Connect users as internal testers.
   - Install through the TestFlight app on the tester device.
5. External testing:
   - Use group `Public Beta`.
   - Add the latest build.
   - Keep Public Link enabled.
   - Fill Beta App Description, What to Test, and Beta App Review Detail.
   - Submit Beta Review.
   - Share the public link after the build reaches `BETA_APPROVED`.

Current Beta Review setup:

- Beta App Description explains GLabTouch as an iOS client for GitLab self-hosted instances.
- What to Test asks testers to verify GitLab instance sign-in, assigned/created/review-requested MR filters, pipeline status display, pipeline detail navigation, settings, and approval/revoke flows where permissions allow it.
- Demo account is marked as optional.
- Review notes say testers provide their own GitLab instance URL and Personal Access Token.

## 状态检查

### App Store Connect UI

- `TestFlight > iOS` shows uploaded builds and build states.
- `TestFlight > Public Beta` shows public link state and tester metrics.
- `TestFlight > GlabTouch Internal Tester` shows internal tester distribution.

### App Store Connect API

Use a local App Store Connect API key to query:

- Builds: `GET /v1/apps/{app_id}/builds`
- Build beta detail: `GET /v1/builds/{build_id}/buildBetaDetail`
- Beta groups: `GET /v1/apps/{app_id}/betaGroups`
- Beta app review detail: `GET /v1/apps/{app_id}/betaAppReviewDetail`

Important states:

- `processingState=VALID`: App Store Connect accepted and processed the build.
- `internalBuildState=IN_BETA_TESTING`: internal testers can install it.
- `externalBuildState=WAITING_FOR_BETA_REVIEW`: external testing is waiting for Apple review.
- `externalBuildState=BETA_APPROVED`: public link can accept external testers.

## 常见问题

### `requires a development team`

Set `DEVELOPMENT_TEAM=<APPLE_TEAM_ID>`.

### Xcode asks for development devices or development profiles

Use manual signing with the App Store profile:

```bash
CODE_SIGN_STYLE="Manual" \
CODE_SIGN_IDENTITY="Apple Distribution" \
PROVISIONING_PROFILE_SPECIFIER="<APP_STORE_PROVISIONING_PROFILE_NAME>"
```

### `No Team Found in Archive`

Create a signed archive with the distribution identity and App Store provisioning profile. Unsigned archives are not useful for TestFlight export.

### Missing export compliance

Confirm `GlabTouch/Info.plist` has:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

### Public link is still pending tester acceptance

Check `externalBuildState`. The link starts accepting testers after Apple sets the build to `BETA_APPROVED`.

### Beta Review asks for a demo account

GLabTouch is designed for tester-provided GitLab instances and PATs. If Apple asks for a demo account, create a low-permission GitLab test user and update Beta App Review Detail.

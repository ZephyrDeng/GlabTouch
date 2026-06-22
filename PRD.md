# GLabTouch - Product Requirements Document

## Overview

GLabTouch is an open-source iOS app for GitLab self-hosted instances, focused on mobile merge request approval and pipeline monitoring.

## Problem

GitLab has no official mobile client and no plans to build one (issue #369066). Community alternatives are all abandoned (GitTouch 2022, F4Lab 2021). The only active project (Merger) is a lightweight macOS menu bar app, not a full mobile review tool. Developers using self-hosted GitLab cannot approve MRs or check pipeline status from their phones.

## Target User

Developers and engineering leads using GitLab self-hosted (CE/EE) who need to review and approve merge requests on the go.

## MVP Scope

### Core Features (Day-1)

#### Authentication
- Personal Access Token (PAT) login
- OAuth 2.0 PKCE flow
- Multi-instance support (configurable Base URL)
- Keychain-based secure token storage

#### Merge Request Management
- MR list views: assigned to me / created by me / awaiting my review
- MR detail: title, description, author, source/target branch, approval status, reviewers
- Approve / Revoke approval (one-tap action)

#### Diff Viewer
- L1: File change list with +/- line count per file
- L2: Line-by-line diff rendering (green additions, red deletions)
- No inline comments (v1.1+)

#### Pipeline Status
- View pipeline status associated with MR
- Pipeline detail with stage/job breakdown and job trace viewing
- Pipeline and job actions: retry, cancel, and manual play where GitLab allows them
- Stage/job breakdown with status indicators (success/failed/running/pending)
- Destructive actions require GitLab permissions and return API errors inline

#### Push Notifications
- APNs client-side registration and handling
- Standardized notification payload schema
- Pipeline started and completed notifications
- Reference webhook relay implementation (user self-deploys)
- Fallback: configurable local polling with badge updates

### Explicitly Out of Scope (v1.1+)
- MR comments / inline review comments
- GitLab Todo list
- Issue management
- Repository / code browsing
- Wiki / Snippets
- macOS native app (rely on iOS Continuity for Mac notifications)

## Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Platform | iOS 18+ | Latest SwiftUI APIs, @Observable macro, new TabView |
| Language | Swift | Native performance, SwiftUI multiplatform |
| UI Framework | SwiftUI | Declarative, Apple-native, shared code potential |
| API Strategy | GraphQL (queries) + REST v4 (mutations) | GraphQL reduces request count for list/detail; REST for approve/revoke (more reliable) |
| Dependencies | Zero third-party | URLSession async/await, native Keychain, AttributedString for diff |
| Auth | PAT + OAuth 2.0 PKCE | PAT for universal compatibility; OAuth for better UX |
| Storage | Keychain (tokens) + UserDefaults (preferences) | Standard iOS secure storage |
| License | Apache 2.0 | Attribution required, patent protection, trademark reserved |
| Hosting | GitHub (open source) | Maximum community visibility |

## Architecture

```
GlabTouch/
├── GlabTouch.xcodeproj
├── GlabTouch/
│   ├── App/                    # App entry point, lifecycle
│   ├── Models/                 # Data models (Codable structs)
│   ├── Services/
│   │   ├── Auth/               # PAT + OAuth PKCE authentication
│   │   ├── GitLabAPI/          # GraphQL + REST client
│   │   ├── Keychain/           # Secure storage
│   │   └── Notifications/      # APNs registration + handling
│   ├── ViewModels/             # @Observable view models
│   └── Views/
│       ├── Auth/               # Login, instance config
│       ├── MergeRequests/      # List, detail, diff
│       ├── Pipeline/           # Pipeline status
│       └── Settings/           # Multi-instance, preferences
├── GlabTouchTests/
├── WebhookRelay/               # Reference webhook relay implementation
├── LICENSE                     # Apache 2.0
├── NOTICE
└── README.md
```

## GitLab API Endpoints

### GraphQL Queries
```graphql
# MR list (assigned/created/review-requested)
currentUser {
  assignedMergeRequests(state: opened) { ... }
  authoredMergeRequests(state: opened) { ... }
  reviewRequestedMergeRequests(state: opened) { ... }
}

# MR detail with pipeline + diff stats
mergeRequest(id: ...) {
  title, description, author, sourceBranch, targetBranch
  approved, headPipeline { status, stages { ... } }
  diffStats { additions, deletions, path }
}
```

### REST v4 Mutations
```
POST /projects/:id/merge_requests/:iid/approve
POST /projects/:id/merge_requests/:iid/unapprove
GET  /projects/:id/merge_requests/:iid/approvals
GET  /projects/:id/merge_requests/:iid/changes   # full diff content
GET  /projects/:id/pipelines/:pipeline_id/jobs
GET  /projects/:id/jobs/:job_id/trace
POST /projects/:id/pipelines/:pipeline_id/retry
POST /projects/:id/pipelines/:pipeline_id/cancel
POST /projects/:id/jobs/:job_id/play
POST /projects/:id/jobs/:job_id/retry
POST /projects/:id/jobs/:job_id/cancel
```

## Notification Payload Schema

```json
{
  "type": "mr_assigned | mr_approved | mr_merged | pipeline_started | pipeline_completed | pipeline_failed",
  "instance": "https://gitlab.example.com",
  "project": { "id": 123, "name": "my-project" },
  "merge_request": { "iid": 42, "title": "feat: ..." },
  "pipeline": { "id": 456, "ref": "main", "status": "running" },
  "actor": { "username": "alice", "avatar_url": "..." },
  "timestamp": "2026-06-21T10:00:00Z"
}
```

## v1.2 Scope — Interaction & Resilience

### F1: Network Resilience & Credential Renewal

**Problem**: Self-hosted GitLab users often access instances over VPN/intranet. Network interruptions cause 401 responses, and the app currently crashes the user flow with a generic error.

**Behavior**:

1. Any API response returning HTTP 401 triggers the credential recovery flow
2. **Silent refresh** (first attempt): if a `refresh_token` exists in Keychain, attempt OAuth token refresh automatically — user sees nothing if it succeeds, pending requests retry transparently
3. **Concurrent 401 coalescing**: multiple simultaneous 401 responses trigger only one refresh attempt; other requests queue and retry after the refresh resolves
4. **UI fallback** (refresh fails or no refresh_token): present a sheet over the current screen with two options:
   - "Re-authenticate" — initiates OAuth PKCE flow using the saved instance URL and OAuth client config (user does not re-enter Base URL)
   - "Re-enter Token" — for PAT users, a text field to paste a new token
5. **No refresh_token warning**: on initial OAuth login, if the token response omits `refresh_token`, show a one-time informational alert: "Your GitLab instance does not support token refresh. You may need to re-authenticate when your session expires."
6. **Instance info preservation**: instance URL, OAuth application ID, and redirect URI remain in Keychain/UserDefaults across re-authentication — only the access/refresh tokens are replaced

**Keychain storage changes**:
- Store `refresh_token` alongside `access_token` (new field)
- Store `token_type` (PAT vs OAuth) to determine recovery strategy

**API client changes**:
- `GitLabAPIClient` gains a `TokenRefresher` protocol dependency
- 401 interception via a request-retry middleware pattern
- Thread-safe refresh lock (Swift actor or `AsyncSemaphore`) to coalesce concurrent refreshes

### F2: Pipeline Log ANSI Rendering

**Problem**: GitLab CI job logs contain ANSI escape codes for color and formatting. The app displays raw escape sequences as garbled text (e.g., `[32;1mSkipping Git submodules setup[0;m`).

**Behavior**:

1. Parse ANSI SGR escape sequences (`ESC[...m`) from job trace text
2. **Supported attributes**: standard 8/16 foreground and background colors, bold, reset
3. **Unsupported attributes gracefully degraded**: 256-color (`38;5;N`), true-color (`38;2;R;G;B`), italic, underline, blink — strip the escape code and render as unstyled text
4. Render the parsed output as `AttributedString` displayed in a `Text` view with monospace font
5. **Dark/Light mode**: maintain two ANSI color palettes mapped to the system appearance, using SwiftUI `@Environment(\.colorScheme)` — dark backgrounds use lighter ANSI colors and vice versa
6. **Performance**: no virtualized scrolling for v1.2. Large logs render fully in memory. Acceptable for typical CI logs (<10k lines). Optimization deferred to a future release if users report issues.

**Implementation**:
- New `ANSIParser` utility: input `String`, output `AttributedString`
- Color palette struct with `light` and `dark` variants for each ANSI color index (0–15)
- `PipelineJobTraceView` replaces `Text(viewModel.trace)` with `Text(ANSIParser.parse(viewModel.trace, colorScheme: colorScheme))`

### F3: MR Description Markdown Rendering

**Problem**: MR descriptions containing markdown (headers, bold, code blocks, tables, images, task lists) display as raw text.

**Behavior**:

1. Fetch `descriptionHtml` field from GitLab GraphQL API (add to `mergeRequestFields` query)
2. Render HTML in a `WKWebView` embedded in the MR detail view
3. **Content-height auto-sizing** (Scheme A): WKWebView disables internal scrolling; a JS bridge (`document.body.scrollHeight`) reports content height back to SwiftUI, which sets the WebView frame height accordingly. The outer ScrollView handles all scrolling.
4. **Styling**: inject a CSS stylesheet matching the app's design system — `AppFont` sizes, `Spacing` values, `TextColor` tokens, `SurfaceColor` backgrounds. Adapts to dark/light mode via `prefers-color-scheme` media query.
5. **Links**: intercept `WKNavigationDelegate` link clicks → open in system browser via `UIApplication.shared.open(url)`
6. **Images with authentication**: intercept image requests via `WKURLSchemeHandler` or inject an auth cookie/header — append the user's access token so images uploaded to the private GitLab instance load correctly
7. **Scope**: MR description only. MR comments remain out of scope (v1.1+ per original PRD), but the `MarkdownWebView` component should be reusable for comments when that feature ships.

**GraphQL query change**:
```graphql
# Add to mergeRequestFields
descriptionHtml
```

**New components**:
- `MarkdownWebView: UIViewRepresentable` — wraps WKWebView, accepts HTML string + auth token, injects CSS, reports content height
- CSS asset file `markdown-style.css` bundled in app

### F4: Pipeline Stage Expand Animation Fix

**Problem**: When expanding a pipeline stage to show its jobs, content above the tapped stage shifts position, creating a jarring "expands up and down" visual effect instead of a clean downward expansion.

**Root cause**: The `.animation()` modifier on the stage `VStack` applies to the entire layout change, including position adjustments of sibling views above the expanding content.

**Fix**:
1. Remove the broad `.animation(_, value: isExpanded)` modifier from the stage VStack
2. Wrap the toggle action in `withAnimation(AppAnimation.stageDisclosure)` for explicit scoping
3. Apply `.transition()` only to the expanding job list content, ensuring the stage header row and all content above it remain positionally stable
4. Verify fix with both single-stage and multi-stage pipelines, including parallel jobs

**No additional animation enhancements** — this is a bug fix only.

---

### v1.2 Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Markdown rendering | WKWebView + `descriptionHtml` | GitLab returns pre-rendered HTML; WKWebView handles full HTML/CSS fidelity with zero parsing code |
| ANSI parsing | Custom `ANSIParser` → `AttributedString` | Lightweight, zero dependencies, covers 95% of CI log formatting |
| Token refresh | Actor-based `TokenRefresher` | Swift concurrency-safe, coalesces concurrent 401s without locks |
| WebView scrolling | Content-height auto-sizing (Scheme A) | Seamless single scroll context, avoids nested scroll UX issues |
| WebView image auth | Token injection via URL scheme handler | Ensures private GitLab images load without exposing tokens to web content |

### v1.2 New/Modified Files (Estimated)

```
GlabTouch/
├── Services/
│   ├── Auth/
│   │   └── TokenRefresher.swift              # NEW: OAuth refresh + 401 retry
│   └── GitLabAPI/
│       ├── GitLabAPIClient.swift             # MODIFIED: 401 interception, retry middleware
│       └── GraphQLQueries.swift              # MODIFIED: add descriptionHtml field
├── Utilities/
│   └── ANSIParser.swift                      # NEW: ANSI → AttributedString
├── Views/
│   ├── Auth/
│   │   └── ReauthenticationSheet.swift       # NEW: re-auth UI sheet
│   ├── MergeRequests/
│   │   ├── MergeRequestDetailView.swift      # MODIFIED: embed MarkdownWebView
│   │   └── MarkdownWebView.swift             # NEW: UIViewRepresentable WKWebView
│   └── Pipeline/
│       └── PipelineDetailView.swift          # MODIFIED: fix animation scope
├── Resources/
│   └── markdown-style.css                    # NEW: WebView CSS
└── DesignSystem/
    └── ANSIColorPalette.swift                # NEW: light/dark ANSI color maps
```

## Git Configuration

- Author: ZephyrDeng <zephyrTang@aliyun.com>
- Remote: GitHub (public repository)

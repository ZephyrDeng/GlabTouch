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

## Git Configuration

- Author: ZephyrDeng <zephyrTang@aliyun.com>
- Remote: GitHub (public repository)

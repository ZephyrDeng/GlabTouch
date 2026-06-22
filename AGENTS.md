# GLabTouch

An open-source iOS app for GitLab self-hosted instances, focused on mobile merge request approval and pipeline monitoring.

## Project Facts

- **License**: Apache 2.0
- **Platform**: iOS 18+
- **Language**: Swift, SwiftUI
- **Dependencies**: Zero third-party, all native APIs
- **API Strategy**: GraphQL (queries) + REST v4 (mutations)
- **Auth**: PAT + OAuth 2.0 PKCE
- **GitLab Compatibility**: CE/EE v11.0+ (GraphQL), verified on v17.8.7

## Architecture

- MVVM with `@Observable` macro (iOS 17+)
- `Services/` layer: Auth, GitLabAPI, Keychain, Notifications
- `Views/` layer: Auth, MergeRequests, Pipeline, Settings
- GraphQL for list/detail queries, REST for approve/revoke mutations

## Git

- Author: ZephyrDeng <zephyrTang@aliyun.com>
- Commit: use `ai-commit generate`
- Remote: GitHub (public)

## Key Docs

- [PRD](./PRD.md) — full product requirements and technical decisions

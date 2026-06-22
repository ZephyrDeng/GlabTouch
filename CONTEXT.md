# GLabTouch Context

GLabTouch is a mobile approval and pipeline monitoring product for self-hosted GitLab instances. This glossary keeps product language consistent across requirements, UI, and code.

## Language

**MR-related Pipeline**:
A pipeline shown because it belongs to a merge request in the user's review workspace. This is the approval-centered pipeline view.
_Avoid_: Head pipeline tab, review pipeline

**My Triggered Pipeline**:
A pipeline shown because the signed-in GitLab user triggered it. This is the owner-centered pipeline view.
_Avoid_: My pipeline, personal pipeline

**Review Workspace**:
The set of merge requests currently relevant to the signed-in user as reviewer, assignee, or author.
_Avoid_: MR dashboard, merge request inbox

**Review Workspace Project Scope**:
The set of GitLab projects discovered from the user's review workspace. This is the first project scope for my triggered pipeline discovery.
_Avoid_: All projects, project universe

**Pipeline Notification**:
A user-visible alert for a pipeline lifecycle transition that deserves attention while the app is away from the foreground.
_Avoid_: CI alert, build ping

**Notifiable Pipeline Transition**:
A pipeline transition into started, failed, or completed successfully. Intermediate queue and running updates stay visible in the pipeline list and badge.
_Avoid_: Every status update, all CI transitions

**Pipeline Notification Ownership**:
The source label shown on a pipeline notification when a pipeline appears in more than one view. My triggered pipeline ownership takes precedence over MR-related pipeline ownership.
_Avoid_: Notification source, alert category

**Pipeline Notification Target**:
The pipeline detail screen opened from a pipeline notification tap. The target is identified by project and pipeline ID, with optional merge request context.
_Avoid_: Alert destination, notification route

**Pipeline Snapshot**:
The pipeline state carried in a notification so the app can render a detail screen immediately before refreshing from GitLab.
_Avoid_: Cached pipeline, stale pipeline

**Polling Freshness**:
The user's expectation for how recently local polling checked GitLab pipeline state. Foreground checks follow the configured interval or manual refresh, and background checks follow iOS scheduling.
_Avoid_: Real-time guarantee, instant push

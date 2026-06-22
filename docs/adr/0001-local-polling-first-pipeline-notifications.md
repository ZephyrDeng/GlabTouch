# Local polling first for pipeline notifications

GLabTouch v1 uses local polling for pipeline notifications and keeps Webhook Relay as the later real-time delivery path. This lets the iOS app ship the two pipeline views, status change detection, badge updates, and user-owned pipeline notifications with the existing GitLab credentials while the relay path remains available for self-hosted teams that want GitLab webhook to APNs delivery.

## Considered Options

- Local polling from the iOS app using the signed-in user's GitLab token
- Webhook Relay receiving GitLab webhooks and sending APNs notifications

## Consequences

- Pipeline updates are best-effort on iOS background refresh timing.
- The default polling interval is 15 minutes, configurable from 1 to 60 minutes.
- Foreground polling follows the configured interval and manual refresh.
- Settings expose last refresh time and last polling error.
- The first refresh establishes the pipeline baseline and sends no notifications.
- Notification titles distinguish started, failed, and passed pipeline transitions.
- Duplicate notifications are merged by `projectID:pipelineID`, with my triggered pipeline ownership taking precedence.
- Pipeline notification taps open `PipelineDetailView`, so routing data includes instance URL, project ID, pipeline ID, source ownership, pipeline snapshot, and optional merge request context.
- Pipeline detail renders the notification snapshot immediately, then refreshes latest status and jobs using project ID and pipeline ID.
- Webhook Relay still owns future real-time delivery, device token mapping, webhook secret verification, and APNs fanout.

# Webhook Relay Reference

GLabTouch expects GitLab webhook relays to normalize events into the app payload schema before sending APNs.

```json
{
  "type": "mr_assigned | mr_approved | mr_merged | pipeline_failed",
  "instance": "https://gitlab.example.com",
  "project": { "id": 123, "name": "my-project" },
  "merge_request": { "iid": 42, "title": "feat: mobile approval" },
  "actor": { "username": "alice", "avatar_url": "https://gitlab.example.com/uploads/avatar.png" },
  "timestamp": "2026-06-21T10:00:00Z"
}
```

Minimum relay responsibilities:

- Verify GitLab webhook secret.
- Map GitLab merge request and pipeline events into the schema above.
- Resolve target device tokens for the user.
- Send APNs alert payloads with the normalized event under `data`.
- Keep token storage and user mapping outside the iOS app repository.

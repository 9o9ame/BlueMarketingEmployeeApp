# BlueMarketing Task Notifications — Mobile/Backend Integration Contract

Status: **backend not yet implemented or verified**. Inspected Laravel `routes/api.php` on `upgrade/laravel-framework` at 2026-11-03: no `/api/v1/mobile/tasks`, `notifications`, or device-token routes exist. No Laravel backend changes in this Flutter batch.

## Existing Flutter implementation

- Dashboard has a notification bell and drawer shortcut.
- `TaskNotificationsScreen` is a branded empty-state screen, **not** a working notification inbox yet. It must not invent notification counts, events or task assignments.
- Recent login accounts and biometric option are implemented independently; notification channel credentials must never be stored as login passwords.

## Delivery choice

**Firebase Cloud Messaging (FCM) for Android background/closed-app push**, with optional **Laravel Reverb** for live in-app updates over authenticated private WebSockets when the app is foregrounded. Pusher Channels can replace Reverb for WebSockets but is not, alone, a reliable Android system-push delivery channel. Push and WebSocket events share the same server notification/event ID to deduplicate.

Firebase project setup, registered Android application ID, `google-services.json`, `flutterfire configure`, `firebase_core` and `firebase_messaging`, and server-side Firebase credentials are required before real push can work. Do not commit server-side Firebase credentials. Android 13+ needs notification permission. Token rotation, app reinstall and logout need lifecycle handling.

## Task types & recurrence

- **One-time task**: admin creates and assigns to one/many authorized users; enqueue one assignment notification per distinct assignee.
- **Repeated task**: admin configures cadence (daily, weekly, monthly), start/end dates, timezone and assignees. Laravel scheduled command generates concrete `task_occurrences` with a unique `(task_id, scheduled_for)` identity (adjust for project/tenant). Each occurrence must be idempotent and create **exactly one** new-task notification per assignee.
- Store schedule, timezone and occurrence dates on the server. Use scheduler + queue workers, transactionally record occurrence and notifications, then dispatch FCM. Use locks/idempotency so retries/crons cannot create duplicate tasks or duplicate pushes.
- If assignment changes, notify only newly assigned users; revocation should remove access without exposing task contents. Never broadcast task data to public channels.
- Due-soon, reassigned, completed and overdue events can be added once defined in web module; do not generate these by default.

## Proposed routes — NOT currently present

All must use `auth:sanctum`, per-user authorization and project-access checks:

| Method | Proposed route | Purpose |
|---|---|---|
| GET | `/api/v1/mobile/notifications` | Paginated private user inbox |
| GET | `/api/v1/mobile/notifications/unread-count` | Count unread messages |
| PATCH | `/api/v1/mobile/notifications/{id}/read` | Mark OWN notification read |
| POST | `/api/v1/mobile/devices` | Register/rotate FCM token for logged-in user |
| DELETE | `/api/v1/mobile/devices/{id}` | Revoke current device registration |
| GET | `/api/v1/mobile/tasks` | Assigned tasks and occurrence status |
| GET | `/api/v1/mobile/tasks/{id}` | Authorized task detail |

Example event contract (not a live API response):

```json
{
  "id": "notification-uuid",
  "type": "task.assigned",
  "task_id": 123,
  "task_occurrence_id": 456,
  "project_id": 12,
  "title": "New task assigned",
  "body": "A task has been assigned to you",
  "created_at": "2026-11-03T10:00:00Z",
  "read_at": null
}
```

The FCM payload should use IDs and minimal text only. On opening the notification, authenticate user, unlock biometrics as appropriate, then fetch the task from Laravel; do not trust task access based on push payload data.

## Delivery architecture

1. Laravel Task Management writes task/assignment/occurrence in DB.
2. Queue task notification job only after the DB transaction commits.
3. Job writes a DB notification for each eligible assignee, keyed uniquely by (user_id, event type, task_occurrence_id), with retry-safe idempotency.
4. Job broadcasts to `private-user.{userId}` with Reverb when online and sends FCM push to registered device tokens.
5. Flutter foreground listens to permitted private channel and/or FCM; bell count/inbox refetches the user's secure backend notifications.
6. Flutter background/terminated relies on FCM OS delivery. The OS may limit delivery in force-stop and other constrained states.
7. Push tap authenticates/rechecks permission and opens exact task detail.

## Blockers before enabling real notifications

- Task Management tables, assignments and scheduler/cron behavior need confirmation in the web backend.
- Existing `routes/api.php` does **not** expose mobile notification/task/device routes.
- Firebase project and Android app registration have not been provided or configured.
- Authenticated Reverb channel authorization and Laravel queues/scheduler need deployment review.
- Do not describe the bell screen as a working push system until tests verify foreground/background/terminated delivery on the actual Redmi device.

## Manual QA gates

- Assign a one-time task to user A/B, confirm one inbox record and push each.
- Create a daily/weekly/monthly recurring task and run scheduler twice; ensure no duplicates.
- Change assigned users and verify revoked users cannot see tasks.
- Verify token rotation, logout, multi-account login, project boundaries and unread count.
- Test foreground, background and terminated Android app; confirm tapping opens the correct task after auth.

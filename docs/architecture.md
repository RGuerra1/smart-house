# Architecture Notes

## Core Principles

- `Apple Home / Matter` is the local device control layer.
- `Firebase` stores account state, schedules, event history, notification preferences, and automation metadata.
- `Presence` is the primary automation trigger for lights.
- `Cameras` are used for alerting and audit history, not first-line light control.

## Domain Model

### Device Categories

- `light`
- `motion_sensor`
- `camera`

### Automation Categories

- `schedule`
- `presence_trigger`
- `camera_alert`

### Event Categories

- `motion_detected`
- `presence_detected`
- `light_changed`
- `camera_alert`
- `notification_sent`

## Backend Flows

### Presence Lighting

1. Sensor or bridge posts a presence event.
2. The backend stores the event in Firestore.
3. Matching presence automations are evaluated with cooldowns and active schedule windows.
4. Light device desired state is updated.
5. An event entry is written for the resulting light action.

### Scheduled Lighting

1. A scheduled Cloud Function runs every minute.
2. Active homes are evaluated using the home timezone.
3. Due automations apply desired state changes to lights.
4. Duplicate executions are prevented via idempotency keys in the event log.

### Camera Alerts

1. Camera or bridge posts a camera alert.
2. The backend writes the event and tags the source camera.
3. Notification delivery is triggered for enabled alert preferences.
4. The app displays the alert in history and notification center views.

## iOS Architecture

- `AppState`: session and home state container.
- `AuthServicing`: authentication contract, currently mock-backed.
- `HomeRepository`: source for homes, rooms, devices, automations, and events.
- `NotificationServicing`: APNs/FCM registration contract.
- Views are grouped by feature and intentionally start with mock services so UI and domain flows can be tested before backend wiring.

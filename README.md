# Smart House

Smart House is an iOS-first smart home MVP for Chilean households using:

- `SwiftUI` for the iPhone app
- `Firebase` for auth, data, notifications, and backend logic
- `Apple Home / Matter` as the local device layer
- `Aqara`-style presence sensors as the main lighting trigger
- cameras for alerts and event history, not primary light control

The current repository is a working scaffold:

- the iOS app builds and runs with mock data
- the Firebase backend structure is in place
- Firestore rules and indexes are defined
- Cloud Functions entrypoints are scaffolded

## What Exists Today

### iOS app

- Project: [SmartHouse.xcodeproj](/Users/rguerra/Documents/GitHub/smart-house/ios/SmartHouse.xcodeproj)
- Source: [ios/SmartHouse](/Users/rguerra/Documents/GitHub/smart-house/ios/SmartHouse)
- Tests: [ios/SmartHouseTests](/Users/rguerra/Documents/GitHub/smart-house/ios/SmartHouseTests)

Current app screens:

- sign in
- dashboard
- room detail
- automations
- event history
- settings

Important note:
The app is still using mock services. It does **not** talk to Firebase yet, and it does **not** control real Matter devices yet. This repo gives you the product structure and backend contracts so you can wire those integrations next.

### Firebase backend

- Config: [firebase/firebase.json](/Users/rguerra/Documents/GitHub/smart-house/firebase/firebase.json)
- Rules: [firebase/firestore.rules](/Users/rguerra/Documents/GitHub/smart-house/firebase/firestore.rules)
- Indexes: [firebase/firestore.indexes.json](/Users/rguerra/Documents/GitHub/smart-house/firebase/firestore.indexes.json)
- Functions: [firebase/functions/src/index.ts](/Users/rguerra/Documents/GitHub/smart-house/firebase/functions/src/index.ts)

Functions scaffolded:

- `ingestCameraAlert`
- `ingestPresenceEvent`
- `runScheduledAutomations`
- `dispatchEventNotifications`

## Repository Layout

- `ios/`: native SwiftUI app
- `firebase/`: Firebase config, Firestore rules/indexes, backend functions
- `docs/`: architecture and product notes
- `deploy.md`: step-by-step setup and deployment guide

## Local Development

### 1. Open the iOS app

1. Open [SmartHouse.xcodeproj](/Users/rguerra/Documents/GitHub/smart-house/ios/SmartHouse.xcodeproj) in Xcode.
2. Select the `SmartHouse` scheme.
3. Run it in an iPhone simulator.

The app should work immediately with mock data.

### 2. Run the verified build commands

These already passed in this repo:

```bash
xcodebuild -project ios/SmartHouse.xcodeproj -scheme SmartHouse -destination 'platform=iOS Simulator,name=iPhone 17' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project ios/SmartHouse.xcodeproj -scheme SmartHouse -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
```

### 3. Install missing backend tooling

This machine currently has `node`, but it does not yet have:

- a Node package manager such as `npm`
- the Firebase CLI
- TypeScript compiler packages for the backend

You will need those before deploying Firebase.

## What You Need To Do Next

Follow [deploy.md](/Users/rguerra/Documents/GitHub/smart-house/deploy.md) in order.

At a high level, you need to:

1. Create and configure a Firebase project.
2. Enable Sign in with Apple, Firestore, Cloud Messaging, and Cloud Functions.
3. Configure a secure ingest token for sensor/camera events.
4. Create Apple app identifiers and push credentials.
5. Add `GoogleService-Info.plist` to the iOS app.
6. Install backend dependencies and deploy Firestore rules, indexes, and functions.
7. Replace the mock app services with Firebase-backed implementations.
8. Add the Apple Home / Matter integration layer for real devices.

## Current Architecture

See [docs/architecture.md](/Users/rguerra/Documents/GitHub/smart-house/docs/architecture.md).

Core product decisions:

- `presence` drives lighting
- `camera alerts` drive notifications and event history
- `schedule automations` use the home timezone
- `one home / one admin` is the current MVP scope

## Important Gaps Before Production

The repo is not production-ready yet. Before a real launch, you still need:

- Firebase SDK integration in the iOS app
- Sign in with Apple implementation in the app
- APNs and FCM token registration in the app
- real Firestore reads and writes in place of mock services
- real Matter / Apple Home integration
- real sensor and camera event ingestion from your device bridge
- backend tests for the TypeScript functions
- CI/CD and secret management

## Recommended First Milestone

If you want the fastest path forward, the next implementation target should be:

1. wire Firebase into the iOS app
2. replace mock auth with Sign in with Apple + Firebase Auth
3. replace mock home data with Firestore
4. deploy Firestore rules/indexes/functions
5. send a manual test `presence` event into the deployed backend

That gets you to a real cloud-backed MVP before hardware control is added.

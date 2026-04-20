# Smart House Deployment Guide

This document explains exactly what you need to do to turn this scaffold into a deployed Firebase-backed iOS app.

## Goal

By the end of this guide, you should have:

- a Firebase project configured for Smart House
- Firestore, Auth, Messaging, and Functions enabled
- Firestore rules and indexes deployed
- Cloud Functions deployed
- a secure ingest token configured for sensors and cameras
- an iOS app registered with Apple and Firebase
- a `GoogleService-Info.plist` ready for the app

Important note:
The current iOS app still uses mock services. Deployment of Firebase infrastructure is possible now, but the app will still need code changes before it uses the live backend.

## 1. Accounts And Access You Need

Before starting, make sure you have:

- an Apple Developer account
- a Google account with access to Firebase and Google Cloud
- permission to create App IDs, push keys, and Firebase projects

## 2. Install Local Tooling

You need all of the following on your machine.

### Xcode

Already available in this environment.

### Node.js with package manager

You need `node` and `npm`.

Recommended install options:

```bash
brew install node
```

After that, confirm:

```bash
node --version
npm --version
```

### Firebase CLI

Install the Firebase CLI:

```bash
npm install -g firebase-tools
```

Then log in:

```bash
firebase login
```

### Backend dependencies

Install the function dependencies:

```bash
cd /Users/rguerra/Documents/GitHub/smart-house/firebase/functions
npm install
```

Validate the TypeScript backend:

```bash
npm run lint
npm run build
```

## 3. Create The Firebase Project

In the Firebase console:

1. Create a new project for Smart House.
2. Enable billing on the project.
3. Link it to a Google Cloud project.

Recommended Firebase products to enable:

- `Authentication`
- `Cloud Firestore`
- `Cloud Functions`
- `Cloud Messaging`

Recommended region choices:

- Firestore: pick a region close to Chile if available for your needs
- Functions: this repo currently uses `southamerica-west1`

Important:
If you change the functions region later, update [firebase/functions/src/index.ts](/Users/rguerra/Documents/GitHub/smart-house/firebase/functions/src/index.ts) to keep everything aligned.

## 4. Register The iOS App In Firebase

In Firebase console:

1. Add a new iOS app.
2. Use the bundle identifier:

```text
com.rguerra.SmartHouse
```

3. Download the generated `GoogleService-Info.plist`.
4. Add it to the iOS project under [ios/SmartHouse](/Users/rguerra/Documents/GitHub/smart-house/ios/SmartHouse).

Current state:
The Xcode project does not yet include a Firebase SDK package or the plist file. You will need to add both when you wire the live app.

## 5. Configure Apple Sign In And Push Notifications

### Create the App ID

In the Apple Developer portal:

1. Create or reuse an App ID for:

```text
com.rguerra.SmartHouse
```

2. Enable these capabilities:

- `Sign In with Apple`
- `Push Notifications`

### Create APNs credentials

You need one of:

- an APNs Auth Key, recommended
- or APNs certificates

For Firebase Cloud Messaging, the recommended path is an APNs Auth Key.

Upload that key in Firebase console under Cloud Messaging for the iOS app.

### Xcode signing

In Xcode, configure:

- your team
- bundle identifier
- signing for debug/release
- Push Notifications capability
- Background Modes if later needed for remote notifications

## 6. Enable Firebase Services

### Authentication

In Firebase Authentication:

1. Enable `Sign in with Apple`.
2. Add the required Apple service configuration from the Apple Developer portal.

### Firestore

1. Create Firestore in native mode.
2. Start with production rules.

Then deploy the repo rules and indexes:

```bash
cd /Users/rguerra/Documents/GitHub/smart-house/firebase
firebase use --add
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

### Cloud Messaging

1. Upload the APNs key in Firebase.
2. Confirm the iOS app registration is attached to Messaging.

### Cloud Functions

From the repo:

Set a shared ingest token before deploy. This token is now required by:

- `ingestPresenceEvent`
- `ingestCameraAlert`

The current function code reads this runtime environment variable:

```text
SMART_HOUSE_INGEST_TOKEN
```

Example shell export for local/emulated use:

```bash
export SMART_HOUSE_INGEST_TOKEN="replace-with-a-long-random-secret"
```

Important:
Make sure your deployment method injects `SMART_HOUSE_INGEST_TOKEN` into the Cloud Functions runtime. If you prefer Secret Manager or a different secret-delivery mechanism, keep the code and deployment setup aligned.

Then deploy:

```bash
cd /Users/rguerra/Documents/GitHub/smart-house/firebase
firebase deploy --only functions
```

If needed, you can deploy everything together:

```bash
firebase deploy
```

## 7. Recommended Firestore Data To Seed First

The backend expects a one-home, one-admin MVP model.

Create these top-level documents first:

- `users/{uid}`
- `homes/{homeId}`

Then create these subcollections under the home:

- `rooms`
- `devices`
- `automations`
- `events`

Minimum useful seed data:

### `homes/{homeId}`

Suggested fields:

```json
{
  "adminUid": "YOUR_FIREBASE_UID",
  "name": "Santiago Home",
  "timezone": "America/Santiago",
  "createdAt": "server timestamp"
}
```

### `users/{uid}`

Suggested fields:

```json
{
  "displayName": "Home Admin",
  "email": "you@example.com",
  "homeId": "home-santiago",
  "notificationsEnabled": true
}
```

### `homes/{homeId}/rooms/{roomId}`

Suggested documents:

- `living-room`
- `entry`
- `bedroom`

### `homes/{homeId}/devices/{deviceId}`

Suggested starter documents:

- one `light`
- one `motion_sensor`
- one `camera`

### `homes/{homeId}/automations/{automationId}`

Suggested starter documents:

- one `schedule`
- one `presence_trigger`
- one `camera_alert`

## 8. Test The Deployed Backend

Once functions are deployed, test the HTTP endpoints with a manual request.

### Presence event

Use the deployed `ingestPresenceEvent` function URL and send a request like:

```json
{
  "homeId": "home-santiago",
  "sourceId": "sensor-entry-presence",
  "detectedAt": "2026-04-20T22:00:00Z",
  "zone": "entry"
}
```

### Camera alert

Use the deployed `ingestCameraAlert` function URL and send:

```json
{
  "homeId": "home-santiago",
  "sourceId": "camera-living",
  "eventType": "motion",
  "detectedAt": "2026-04-20T22:05:00Z",
  "zone": "living-room"
}
```

After each request, verify:

- an event document was written
- device state changed for presence automations
- notification fanout logic ran if tokens exist

Include the ingest token in either:

- `Authorization: Bearer <token>`
- or `x-smart-house-token: <token>`

## 9. What Still Requires Code Work

Deployment alone is not enough yet. The following app work is still pending:

- add Firebase iOS SDK with Swift Package Manager
- initialize Firebase in the app
- replace `MockAuthService` with Firebase Auth + Sign in with Apple
- replace `MockHomeRepository` with Firestore-backed reads and writes
- register APNs and FCM tokens in the app
- add app logic to store user push tokens in Firestore
- add the Apple Home / Matter device control layer

Relevant source files:

- [AppEnvironment.swift](/Users/rguerra/Documents/GitHub/smart-house/ios/SmartHouse/AppEnvironment.swift)
- [Services.swift](/Users/rguerra/Documents/GitHub/smart-house/ios/SmartHouse/Services.swift)
- [MockServices.swift](/Users/rguerra/Documents/GitHub/smart-house/ios/SmartHouse/MockServices.swift)

## 10. Recommended Deployment Order

Use this order to avoid backtracking:

1. install `node`, `npm`, and `firebase-tools`
2. create the Firebase project
3. register the iOS app in Firebase
4. create the Apple App ID and APNs key
5. enable Sign in with Apple and Messaging in Firebase
6. install function dependencies
7. deploy Firestore rules and indexes
8. deploy Cloud Functions
9. seed your first home/user/device documents
10. wire the iOS app to Firebase
11. test push notifications
12. connect real Matter / Apple Home devices

## 11. Suggested First Real Integration Milestone

If you want the cleanest next deliverable, implement this milestone first:

- Firebase Auth + Sign in with Apple
- Firestore-backed dashboard
- Firestore-backed automations list
- deployed rules, indexes, and functions
- manual presence event testing from the backend

That gives you a real end-to-end cloud-backed MVP before hardware control is added.

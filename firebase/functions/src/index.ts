import {initializeApp} from "firebase-admin/app";
import {DocumentReference, getFirestore, Timestamp} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {HttpsError, onRequest} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";

initializeApp();

const db = getFirestore();

type DeviceCategory = "light" | "motion_sensor" | "camera";
type AutomationCategory = "schedule" | "presence_trigger" | "camera_alert";
type EventCategory =
  | "motion_detected"
  | "presence_detected"
  | "light_changed"
  | "camera_alert"
  | "notification_sent";

type LightState = "on" | "off";

interface CameraAlertPayload {
  homeId: string;
  sourceId: string;
  eventType: "motion";
  detectedAt: string;
  confidence?: number;
  zone?: string;
}

interface PresenceEventPayload {
  homeId: string;
  sourceId: string;
  detectedAt: string;
  zone?: string;
  confidence?: number;
}

interface HomeRecord {
  adminUid: string;
  name: string;
  timezone: string;
  createdAt: Timestamp;
}

interface DeviceRecord {
  id: string;
  name: string;
  category: DeviceCategory;
  roomID: string;
  adapter: "matter" | "virtual";
  desiredState?: LightState;
  actualState?: LightState;
  lastChangedBy?: "manual" | "schedule" | "camera" | "presence";
  updatedAt: Timestamp;
}

interface ScheduleRule {
  weekdays: number[];
  startMinute: number;
  endMinute: number;
  desiredState: LightState;
  pauseUntil?: Timestamp;
}

interface PresenceTriggerRule {
  sourceDeviceID: string;
  cooldownSeconds: number;
  desiredState: LightState;
  activeMinutes?: {
    startMinute: number;
    endMinute: number;
  };
}

interface AutomationRecord {
  id: string;
  category: AutomationCategory;
  enabled: boolean;
  targetDeviceIDs: string[];
  schedule?: ScheduleRule;
  presenceTrigger?: PresenceTriggerRule;
  lastTriggeredAt?: Timestamp;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

interface EventRecord {
  category: EventCategory;
  title: string;
  homeId: string;
  roomID?: string;
  sourceDeviceID?: string;
  actor: "system" | "admin" | "camera" | "presence_sensor";
  metadata?: Record<string, unknown>;
  occurredAt: Timestamp;
}

export const ingestCameraAlert = onRequest({region: "southamerica-west1"}, async (request, response) => {
  if (request.method !== "POST") {
    response.status(405).json({error: "Method not allowed"});
    return;
  }

  assertIngestAuthorized(request);

  const payload = request.body as CameraAlertPayload;
  validateRequiredString(payload.homeId, "homeId");
  validateRequiredString(payload.sourceId, "sourceId");
  validateRequiredString(payload.detectedAt, "detectedAt");

  const homeRef = await getHomeRef(payload.homeId);
  await assertSourceDevice(homeRef, payload.sourceId, "camera");

  const event = createEventRecord({
    category: "camera_alert",
    title: "Camera motion detected",
    homeId: payload.homeId,
    sourceDeviceID: payload.sourceId,
    actor: "camera",
    occurredAt: Timestamp.fromDate(new Date(payload.detectedAt)),
    metadata: {
      confidence: payload.confidence ?? null,
      zone: payload.zone ?? null,
      eventType: payload.eventType
    }
  });

  await homeRef.collection("events").add(event);
  response.status(202).json({status: "accepted"});
});

export const ingestPresenceEvent = onRequest({region: "southamerica-west1"}, async (request, response) => {
  if (request.method !== "POST") {
    response.status(405).json({error: "Method not allowed"});
    return;
  }

  assertIngestAuthorized(request);

  const payload = request.body as PresenceEventPayload;
  validateRequiredString(payload.homeId, "homeId");
  validateRequiredString(payload.sourceId, "sourceId");
  validateRequiredString(payload.detectedAt, "detectedAt");

  const homeRef = await getHomeRef(payload.homeId);
  await assertSourceDevice(homeRef, payload.sourceId, "motion_sensor");

  const eventRef = await homeRef.collection("events").add(createEventRecord({
    category: "presence_detected",
    title: "Presence detected",
    homeId: payload.homeId,
    sourceDeviceID: payload.sourceId,
    actor: "presence_sensor",
    occurredAt: Timestamp.fromDate(new Date(payload.detectedAt)),
    metadata: {
      confidence: payload.confidence ?? null,
      zone: payload.zone ?? null
    }
  }));

  await applyPresenceAutomations(payload.homeId, payload.sourceId, eventRef.id);
  response.status(202).json({status: "accepted"});
});

export const runScheduledAutomations = onSchedule(
  {schedule: "every 1 minutes", region: "southamerica-west1", timeZone: "America/Santiago"},
  async () => {
    const homesSnapshot = await db.collection("homes").get();

    for (const homeDoc of homesSnapshot.docs) {
      const home = homeDoc.data() as HomeRecord;
      const automationsSnapshot = await homeDoc.ref
        .collection("automations")
        .where("category", "==", "schedule")
        .where("enabled", "==", true)
        .get();

      for (const automationDoc of automationsSnapshot.docs) {
        const automation = automationDoc.data() as AutomationRecord;
        const schedule = automation.schedule;
        if (!schedule) {
          continue;
        }

        const now = new Date();
        const weekday = getWeekdayInTimezone(now, home.timezone);
        const minute = getMinuteOfDayInTimezone(now, home.timezone);
        const paused = schedule.pauseUntil && schedule.pauseUntil.toDate() > now;
        const active = schedule.weekdays.includes(weekday) &&
          minute >= schedule.startMinute &&
          minute <= schedule.endMinute &&
          !paused;

        if (!active) {
          continue;
        }

        await updateTargetLights(homeDoc.id, automation.targetDeviceIDs, schedule.desiredState, "schedule");
        await homeDoc.ref.collection("events").add(createEventRecord({
          category: "light_changed",
          title: "Scheduled lighting applied",
          homeId: homeDoc.id,
          actor: "system",
          occurredAt: Timestamp.now(),
          metadata: {
            automationId: automationDoc.id,
            desiredState: schedule.desiredState
          }
        }));
      }
    }
  }
);

export const dispatchEventNotifications = onDocumentCreated(
  {
    document: "homes/{homeId}/events/{eventId}",
    region: "southamerica-west1"
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const record = snapshot.data() as EventRecord;
    if (!["camera_alert", "presence_detected", "light_changed"].includes(record.category)) {
      return;
    }

    const homeId = event.params.homeId;
    const homeRef = await getHomeRef(homeId);
    const home = (await homeRef.get()).data() as HomeRecord;
    const adminSnapshot = await db.doc(`users/${home.adminUid}`).get();
    const notificationsEnabled = adminSnapshot.get("notificationsEnabled") as boolean | undefined;
    const pushToken = adminSnapshot.get("pushToken") as string | undefined;
    const tokens = notificationsEnabled && pushToken ? [pushToken] : [];

    if (tokens.length === 0) {
      return;
    }

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: record.title,
        body: buildNotificationBody(record)
      },
      data: {
        homeId,
        category: record.category
      }
    });

    await snapshot.ref.parent.add(createEventRecord({
      category: "notification_sent",
      title: "Notification delivered",
      homeId,
      actor: "system",
      occurredAt: Timestamp.now(),
      metadata: {
        sourceEventId: snapshot.id,
        sourceCategory: record.category,
        tokenCount: tokens.length
      }
    }));
  }
);

async function applyPresenceAutomations(homeId: string, sourceId: string, eventId: string): Promise<void> {
  const homeRef = await getHomeRef(homeId);
  const home = (await homeRef.get()).data() as HomeRecord;
  const automationsSnapshot = await homeRef.collection("automations")
    .where("category", "==", "presence_trigger")
    .where("enabled", "==", true)
    .get();

  for (const automationDoc of automationsSnapshot.docs) {
    const automation = automationDoc.data() as AutomationRecord;
    const rule = automation.presenceTrigger;
    if (!rule) {
      continue;
    }

    if (rule.sourceDeviceID !== sourceId) {
      continue;
    }

    const now = new Date();
    if (automation.lastTriggeredAt && isWithinCooldown(automation.lastTriggeredAt.toDate(), now, rule.cooldownSeconds)) {
      continue;
    }

    if (rule.activeMinutes) {
      const minute = getMinuteOfDayInTimezone(now, home.timezone);
      if (!isMinuteInWindow(minute, rule.activeMinutes.startMinute, rule.activeMinutes.endMinute)) {
        continue;
      }
    }

    await updateTargetLights(homeId, automation.targetDeviceIDs, rule.desiredState, "presence");
    await automationDoc.ref.set({
      lastTriggeredAt: Timestamp.now(),
      updatedAt: Timestamp.now()
    }, {merge: true});
    await homeRef.collection("events").add(createEventRecord({
      category: "light_changed",
      title: "Presence automation applied",
      homeId,
      sourceDeviceID: sourceId,
      actor: "presence_sensor",
      occurredAt: Timestamp.now(),
      metadata: {
        automationId: automationDoc.id,
        sourceEventId: eventId,
        desiredState: rule.desiredState,
        cooldownSeconds: rule.cooldownSeconds
      }
    }));
  }
}

async function updateTargetLights(
  homeId: string,
  deviceIDs: string[],
  desiredState: LightState,
  changedBy: "schedule" | "camera" | "presence"
): Promise<void> {
  const homeRef = db.doc(`homes/${homeId}`);
  const batch = db.batch();

  for (const deviceID of deviceIDs) {
    const deviceRef = homeRef.collection("devices").doc(deviceID);
    batch.set(deviceRef, {
      desiredState,
      actualState: desiredState,
      lastChangedBy: changedBy,
      updatedAt: Timestamp.now()
    }, {merge: true});
  }

  await batch.commit();
}

function createEventRecord(record: EventRecord): EventRecord {
  return record;
}

async function getHomeRef(homeId: string): Promise<DocumentReference> {
  const homeRef = db.doc(`homes/${homeId}`);
  const homeSnapshot = await homeRef.get();
  if (!homeSnapshot.exists) {
    throw new HttpsError("not-found", "Home not found");
  }
  return homeRef;
}

async function assertSourceDevice(
  homeRef: DocumentReference,
  sourceId: string,
  expectedCategory: DeviceCategory
): Promise<void> {
  const deviceSnapshot = await homeRef.collection("devices").doc(sourceId).get();
  if (!deviceSnapshot.exists) {
    throw new HttpsError("not-found", "Source device not found");
  }

  const device = deviceSnapshot.data() as DeviceRecord;
  if (device.category !== expectedCategory) {
    throw new HttpsError("permission-denied", "Source device category is not allowed for this endpoint");
  }
}

function buildNotificationBody(record: EventRecord): string {
  switch (record.category) {
  case "camera_alert":
    return "Camera activity was detected and recorded in your event history.";
  case "presence_detected":
    return "Presence was detected in your home.";
  case "light_changed":
    return "A light automation changed one or more devices.";
  default:
    return "A new smart house event was created.";
  }
}

function validateRequiredString(value: unknown, fieldName: string): void {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required`);
  }
}

function assertIngestAuthorized(request: {get(name: string): string | undefined}): void {
  const configuredToken = process.env.SMART_HOUSE_INGEST_TOKEN;
  if (!configuredToken) {
    throw new HttpsError("failed-precondition", "SMART_HOUSE_INGEST_TOKEN is not configured");
  }

  const authorization = request.get("authorization");
  const bearerToken = authorization?.startsWith("Bearer ") ? authorization.slice(7).trim() : undefined;
  const directToken = request.get("x-smart-house-token")?.trim();
  const providedToken = bearerToken || directToken;

  if (!providedToken || providedToken !== configuredToken) {
    throw new HttpsError("unauthenticated", "Invalid ingest token");
  }
}

function getWeekdayInTimezone(date: Date, timeZone: string): number {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone,
    weekday: "short"
  });
  const weekday = formatter.format(date);
  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  return days.indexOf(weekday);
}

function getMinuteOfDayInTimezone(date: Date, timeZone: string): number {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false
  });
  const parts = formatter.formatToParts(date);
  const hour = Number(parts.find((part) => part.type === "hour")?.value ?? 0);
  const minute = Number(parts.find((part) => part.type === "minute")?.value ?? 0);
  return (hour * 60) + minute;
}

function isMinuteInWindow(minute: number, startMinute: number, endMinute: number): boolean {
  if (startMinute <= endMinute) {
    return minute >= startMinute && minute <= endMinute;
  }

  return minute >= startMinute || minute <= endMinute;
}

function isWithinCooldown(lastTriggeredAt: Date, now: Date, cooldownSeconds: number): boolean {
  return (now.getTime() - lastTriggeredAt.getTime()) < (cooldownSeconds * 1000);
}

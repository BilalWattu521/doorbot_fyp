const express = require("express");
const admin = require("firebase-admin");

const app = express();
const PORT = process.env.PORT || 3000;

// Secret API key from environment variable (set in Render dashboard)
const API_KEY = process.env.DOORBOT_API_KEY || "";

// Poll interval for checking doorbell events (in ms)
const POLL_INTERVAL = process.env.POLL_INTERVAL || 3000;

// ─── Firebase Admin SDK Init ───────────────────────────────────────────────────

let firebaseReady = false;

try {
  const serviceAccountEnv = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (serviceAccountEnv) {
    const serviceAccount = JSON.parse(serviceAccountEnv);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL: `https://${serviceAccount.project_id}-default-rtdb.firebaseio.com`,
    });
    firebaseReady = true;
    console.log("✅ Firebase Admin SDK initialized (service account JSON)");
  } else if (
    process.env.FIREBASE_PROJECT_ID &&
    process.env.FIREBASE_CLIENT_EMAIL &&
    process.env.FIREBASE_PRIVATE_KEY
  ) {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
      }),
      databaseURL: `https://${process.env.FIREBASE_PROJECT_ID}-default-rtdb.firebaseio.com`,
    });
    firebaseReady = true;
    console.log("✅ Firebase Admin SDK initialized (individual env vars)");
  } else {
    console.warn(
      "⚠️  No Firebase credentials found – push notifications disabled"
    );
  }
} catch (err) {
  console.error("❌ Firebase Admin SDK init failed:", err.message);
}

// ─── Push Notification via RTDB Polling ────────────────────────────────────────

// Track the last event timestamp per user so we only fire on NEW events
const lastEventTimestamps = {}; // { uid: timestamp }

/**
 * Send an FCM push notification for a doorbell press.
 */
async function sendDoorbellNotification(uid, eventTimestamp) {
  try {
    const tokenSnapshot = await admin
      .database()
      .ref(`users/${uid}/fcm_token`)
      .once("value");
    const fcmToken = tokenSnapshot.val();

    if (!fcmToken) {
      console.log(`⏩ No FCM token for user ${uid} — skipping notification`);
      return;
    }

    const payload = {
      token: fcmToken,
      notification: {
        title: "Doorbell Ringing!",
        body: "Someone is at the door.",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "doorbot_notifications",
          priority: "max",
          defaultSound: true,
          defaultVibrateTimings: true,
          visibility: "public",
        },
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: "doorbell",
        event_time: String(eventTimestamp),
      },
    };

    const response = await admin.messaging().send(payload);
    console.log(`✅ FCM sent to user ${uid}:`, response);
  } catch (error) {
    console.error(`❌ FCM send error for user ${uid}:`, error.message);
  }
}

/**
 * Check a single user's doorbell event for changes.
 */
async function checkUserDoorbellEvent(uid) {
  try {
    const snapshot = await admin
      .database()
      .ref(`users/${uid}/doorbell/event`)
      .once("value");
    const eventTimestamp = snapshot.val();

    if (!eventTimestamp) return;

    const previous = lastEventTimestamps[uid];

    // First time seeing this user — initialize, don't send notification
    if (previous === undefined) {
      lastEventTimestamps[uid] = eventTimestamp;
      console.log(`📌 Initialized timestamp for user ${uid}: ${eventTimestamp}`);
      return;
    }

    // Only fire on NEW timestamps (different AND greater)
    if (eventTimestamp !== previous && eventTimestamp > previous) {
      lastEventTimestamps[uid] = eventTimestamp;
      console.log(`🔔 New doorbell event for user ${uid}: ${eventTimestamp}`);
      sendDoorbellNotification(uid, eventTimestamp);
    }
  } catch (error) {
    console.error(`❌ Error checking doorbell for user ${uid}:`, error.message);
  }
}

/**
 * Discover all users and check their doorbell events.
 * Runs on a fixed interval (polling).
 */
async function pollDoorbellEvents() {
  if (!firebaseReady) return;

  try {
    // Get all user UIDs
    const usersSnapshot = await admin.database().ref("users").once("value");
    const usersData = usersSnapshot.val();

    if (!usersData) return;

    const uids = Object.keys(usersData);

    // Check each user's doorbell event
    await Promise.all(uids.map((uid) => checkUserDoorbellEvent(uid)));
  } catch (error) {
    console.error("❌ Poll error:", error.message);
  }
}

/**
 * Start the polling loop.
 */
function startPolling() {
  if (!firebaseReady) {
    console.log("⚠️  Firebase not ready — skipping polling");
    return;
  }

  console.log(
    `🚀 Doorbell polling started — checking every ${POLL_INTERVAL}ms`
  );

  // Do an initial poll immediately
  pollDoorbellEvents();

  // Then poll at the configured interval
  setInterval(pollDoorbellEvents, POLL_INTERVAL);
}

// ─── Relay Server Routes (existing — unchanged) ───────────────────────────────

const frames = {};

function auth(req, res, next) {
  const key = req.headers["x-api-key"];
  if (!API_KEY || key !== API_KEY) {
    return res.status(401).send("Unauthorized");
  }
  next();
}

app.post(
  "/upload",
  auth,
  express.raw({ type: "image/jpeg", limit: "1mb" }),
  (req, res) => {
    const uid = req.headers["x-user-uid"];
    if (!uid) return res.status(400).send("Missing UID");
    if (!req.body || req.body.length === 0)
      return res.status(400).send("No image data");

    frames[uid] = req.body;
    res.status(200).send("OK");
  }
);

app.get("/latest", auth, (req, res) => {
  const uid = req.headers["x-user-uid"];
  if (!uid) return res.status(400).send("Missing UID");

  const frame = frames[uid];
  if (!frame) return res.status(204).send();

  res.writeHead(200, {
    "Content-Type": "image/jpeg",
    "Content-Length": frame.length,
    "Cache-Control": "no-cache, no-store, must-revalidate",
  });
  res.end(frame);
});

app.get("/", (req, res) => {
  const userCount = Object.keys(frames).length;
  const trackedUsers = Object.keys(lastEventTimestamps).length;
  res.send(
    `DoorBot Relay Server | Users: ${userCount} | Tracked: ${trackedUsers} | Firebase: ${firebaseReady ? "yes" : "no"} | Secured: ${API_KEY ? "yes" : "no"}`
  );
});

// ─── Start ──────────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`Relay server running on port ${PORT}`);
  startPolling();
});

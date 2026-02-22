const express = require("express");
const admin = require("firebase-admin");

const app = express();
const PORT = process.env.PORT || 3000;

// Secret API key from environment variable (set in Render dashboard)
const API_KEY = process.env.DOORBOT_API_KEY || "";

// ─── Firebase Admin SDK Init ───────────────────────────────────────────────────
// Expects FIREBASE_SERVICE_ACCOUNT env var with the full JSON string of the
// service-account key downloaded from Firebase Console.
// Alternatively you can set FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL,
// and FIREBASE_PRIVATE_KEY individually.

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
  } else if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_CLIENT_EMAIL && process.env.FIREBASE_PRIVATE_KEY) {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        // Render stores newlines as literal \n — convert them back
        privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
      }),
      databaseURL: `https://${process.env.FIREBASE_PROJECT_ID}-default-rtdb.firebaseio.com`,
    });
    firebaseReady = true;
    console.log("✅ Firebase Admin SDK initialized (individual env vars)");
  } else {
    console.warn("⚠️  No Firebase credentials found – push notifications disabled");
  }
} catch (err) {
  console.error("❌ Firebase Admin SDK init failed:", err.message);
}

// ─── Push Notification via RTDB Listener ───────────────────────────────────────

// Track the last event timestamp per user so we only fire on NEW events
const lastEventTimestamps = {}; // { uid: timestamp }

// Track per-user RTDB subscriptions so we can add/remove dynamically
const userSubscriptions = {}; // { uid: unsubscribeFn }

/**
 * Send an FCM push notification for a doorbell press.
 */
async function sendDoorbellNotification(uid, eventTimestamp) {
  try {
    // Read the user's FCM token from RTDB
    const tokenSnapshot = await admin.database().ref(`users/${uid}/fcm_token`).once("value");
    const fcmToken = tokenSnapshot.val();

    if (!fcmToken) {
      // User is logged out or has no token — skip notification silently
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
 * Start listening to doorbell events for a specific user.
 */
function subscribeToUser(uid) {
  if (userSubscriptions[uid]) return; // already listening

  console.log(`👂 Listening to doorbell events for user: ${uid}`);

  const eventRef = admin.database().ref(`users/${uid}/doorbell/event`);

  const callback = eventRef.on("value", (snapshot) => {
    const eventTimestamp = snapshot.val();
    if (!eventTimestamp) return;

    const previous = lastEventTimestamps[uid];
    // Initialize on first read — don't send notification for stale data
    if (previous === undefined) {
      lastEventTimestamps[uid] = eventTimestamp;
      console.log(`📌 Initialized timestamp for user ${uid}: ${eventTimestamp}`);
      return;
    }

    // Only fire on NEW timestamps
    if (eventTimestamp !== previous && eventTimestamp > previous) {
      lastEventTimestamps[uid] = eventTimestamp;
      console.log(`🔔 New doorbell event for user ${uid}: ${eventTimestamp}`);
      sendDoorbellNotification(uid, eventTimestamp);
    }
  });

  // Store the unsubscribe info
  userSubscriptions[uid] = () => eventRef.off("value", callback);
}

/**
 * Stop listening to a user (e.g. if their node is removed).
 */
function unsubscribeFromUser(uid) {
  if (userSubscriptions[uid]) {
    userSubscriptions[uid]();
    delete userSubscriptions[uid];
    delete lastEventTimestamps[uid];
    console.log(`🔇 Stopped listening to user: ${uid}`);
  }
}

/**
 * Watch the /users node to auto-discover users and subscribe/unsubscribe.
 */
function startUserDiscovery() {
  if (!firebaseReady) {
    console.log("⚠️  Firebase not ready — skipping RTDB listeners");
    return;
  }

  const usersRef = admin.database().ref("users");

  // When a new user appears
  usersRef.on("child_added", (snapshot) => {
    subscribeToUser(snapshot.key);
  });

  // When a user is removed
  usersRef.on("child_removed", (snapshot) => {
    unsubscribeFromUser(snapshot.key);
  });

  console.log("🚀 User discovery started — watching /users node");
}

// ─── Relay Server Routes (existing — unchanged) ───────────────────────────────

// Store latest frame PER USER (keyed by UID)
const frames = {}; // { "uid123": Buffer, "uid456": Buffer, ... }

// Middleware: validate API key
function auth(req, res, next) {
  const key = req.headers["x-api-key"];
  if (!API_KEY || key !== API_KEY) {
    return res.status(401).send("Unauthorized");
  }
  next();
}

// ---- ESP32 sends frames here ----
app.post("/upload", auth, express.raw({ type: "image/jpeg", limit: "1mb" }), (req, res) => {
  const uid = req.headers["x-user-uid"];
  if (!uid) return res.status(400).send("Missing UID");
  if (!req.body || req.body.length === 0) return res.status(400).send("No image data");

  // Store frame for this specific user
  frames[uid] = req.body;
  res.status(200).send("OK");
});

// ---- Flutter app fetches latest frame ----
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

// ---- Health check (no auth needed) ----
app.get("/", (req, res) => {
  const userCount = Object.keys(frames).length;
  const listenersCount = Object.keys(userSubscriptions).length;
  res.send(
    `DoorBot Relay Server | Users: ${userCount} | Listeners: ${listenersCount} | Firebase: ${firebaseReady ? "yes" : "no"} | Secured: ${API_KEY ? "yes" : "no"}`
  );
});

// ─── Start ──────────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`Relay server running on port ${PORT}`);
  // Start RTDB listeners after server is up
  startUserDiscovery();
});

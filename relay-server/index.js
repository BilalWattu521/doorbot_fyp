const express = require("express");
const admin = require("firebase-admin");
const https = require("https");

const app = express();
const PORT = process.env.PORT || 3000;

// Secret API key from environment variable (set in Render dashboard)
const API_KEY = process.env.DOORBOT_API_KEY || "";

// ─── Firebase Admin SDK Init ───────────────────────────────────────────────────

let firebaseReady = false;
let databaseURL = "";

try {
  const serviceAccountEnv = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (serviceAccountEnv) {
    const serviceAccount = JSON.parse(serviceAccountEnv);
    databaseURL = `https://${serviceAccount.project_id}-default-rtdb.firebaseio.com`;
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL,
    });
    firebaseReady = true;
    console.log("✅ Firebase Admin SDK initialized");
  } else if (
    process.env.FIREBASE_PROJECT_ID &&
    process.env.FIREBASE_CLIENT_EMAIL &&
    process.env.FIREBASE_PRIVATE_KEY
  ) {
    databaseURL = `https://${process.env.FIREBASE_PROJECT_ID}-default-rtdb.firebaseio.com`;
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
      }),
      databaseURL,
    });
    firebaseReady = true;
    console.log("✅ Firebase Admin SDK initialized");
  } else {
    console.warn("⚠️  No Firebase credentials – notifications disabled");
  }
} catch (err) {
  console.error("❌ Firebase init failed:", err.message);
}

// ─── Crash Protection ──────────────────────────────────────────────────────────

process.on("uncaughtException", (err) => {
  console.error("💥 Uncaught Exception:", err.message);
});
process.on("unhandledRejection", (reason) => {
  console.error("💥 Unhandled Rejection:", reason);
});

// ─── Push Notification via RTDB Polling ────────────────────────────────────────

const lastEventTimestamps = {}; // { uid: timestamp }
const knownUsers = new Set();
let lastUserDiscovery = 0;
let pollCount = 0;

/**
 * Discover user UIDs using Firebase REST API with shallow=true.
 * This returns ONLY the top-level keys, NOT the full user data.
 * Much lighter than admin.database().ref("users").once("value")!
 */
async function discoverUsers() {
  try {
    // Get access token from Admin SDK
    const accessToken = await admin.app().options.credential.getAccessToken();
    const token = accessToken.access_token;

    // Use REST API with shallow=true — returns only keys, not data
    const url = `${databaseURL}/users.json?shallow=true&access_token=${token}`;

    const data = await new Promise((resolve, reject) => {
      const req = https.get(url, { timeout: 10000 }, (res) => {
        let body = "";
        res.on("data", (chunk) => (body += chunk));
        res.on("end", () => {
          try {
            resolve(JSON.parse(body));
          } catch (e) {
            reject(new Error("Failed to parse user list"));
          }
        });
      });
      req.on("error", reject);
      req.on("timeout", () => {
        req.destroy();
        reject(new Error("User discovery timeout"));
      });
    });

    if (data && typeof data === "object") {
      const uids = Object.keys(data);
      for (const uid of uids) {
        if (!knownUsers.has(uid)) {
          knownUsers.add(uid);
          console.log(`👤 Discovered user: ${uid}`);
        }
      }
    }
  } catch (err) {
    console.error("❌ User discovery error:", err.message);
  }
}

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
      console.log(`⏩ No FCM token for ${uid} — skipped`);
      return;
    }

    console.log(`📱 FCM token for ${uid}: ${fcmToken.substring(0, 20)}...`);

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
    console.log(`✅ FCM sent to ${uid}:`, response);
  } catch (error) {
    console.error(`❌ FCM error for ${uid}:`, error.message);
  }
}

/**
 * Check ONE user's doorbell event — reads only the tiny event value.
 */
async function checkUserDoorbellEvent(uid) {
  try {
    // TARGETED read — only reads /users/{uid}/doorbell/event (a single number)
    const snapshot = await admin
      .database()
      .ref(`users/${uid}/doorbell/event`)
      .once("value");
    const eventTimestamp = snapshot.val();

    if (!eventTimestamp) return;

    const previous = lastEventTimestamps[uid];

    if (previous === undefined) {
      lastEventTimestamps[uid] = eventTimestamp;
      console.log(`📌 Init timestamp ${uid}: ${eventTimestamp}`);
      return;
    }

    if (eventTimestamp !== previous) {
      lastEventTimestamps[uid] = eventTimestamp;
      console.log(`🔔 Doorbell! User ${uid}: ${eventTimestamp}`);
      // Fire-and-forget so notification send doesn't block polling/frame serving
      sendDoorbellNotification(uid, eventTimestamp).catch((err) =>
        console.error(`❌ Notification fire error ${uid}:`, err.message)
      );
    }
  } catch (error) {
    console.error(`❌ Poll error ${uid}:`, error.message);
  }
}

/**
 * Main poll cycle — lightweight targeted reads only.
 */
let isPolling = false;

async function pollDoorbellEvents() {
  if (!firebaseReady || isPolling) return;
  isPolling = true;

  try {
    const now = Date.now();

    // Discover users every 5 minutes (or on first run)
    if (knownUsers.size === 0 || now - lastUserDiscovery > 300000) {
      await discoverUsers();
      lastUserDiscovery = now;
    }

    // Poll all users concurrently (don't block sequentially)
    await Promise.all(
      [...knownUsers].map((uid) => checkUserDoorbellEvent(uid))
    );

    // Heartbeat log every 100 polls (~5 minutes at 3s interval)
    pollCount++;
    if (pollCount % 100 === 0) {
      console.log(
        `💓 Heartbeat: ${pollCount} polls | ${knownUsers.size} users tracked`
      );
    }
  } catch (error) {
    console.error("❌ Poll cycle error:", error.message);
  } finally {
    isPolling = false;
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

  console.log(`🚀 Doorbell polling started (every 3s)`);
  pollDoorbellEvents();
  setInterval(pollDoorbellEvents, 3000);
}

// ─── Relay Server Routes (unchanged) ──────────────────────────────────────────

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
  if (!frame) {
    console.log(`📷 No frame yet for ${uid}`);
    return res.status(204).send();
  }

  res.writeHead(200, {
    "Content-Type": "image/jpeg",
    "Content-Length": frame.length,
    "Cache-Control": "no-cache, no-store, must-revalidate",
  });
  res.end(frame);
});

app.get("/", (req, res) => {
  const userCount = Object.keys(frames).length;
  res.send(
    `DoorBot Relay | Frames: ${userCount} | Users: ${knownUsers.size} | Polls: ${pollCount} | Firebase: ${firebaseReady ? "yes" : "no"}`
  );
});

// ─── Start ──────────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`Relay server running on port ${PORT}`);
  startPolling();
});

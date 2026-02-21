const express = require("express");
const app = express();
const PORT = process.env.PORT || 3000;

// Secret API key from environment variable (set in Render dashboard)
const API_KEY = process.env.DOORBOT_API_KEY || "";

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
  res.send(`DoorBot Relay Server | Users: ${userCount} | Secured: ${API_KEY ? "yes" : "no"}`);
});

app.listen(PORT, () => {
  console.log(`Relay server running on port ${PORT}`);
});

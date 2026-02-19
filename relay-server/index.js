const express = require("express");
const app = express();
const PORT = process.env.PORT || 3000;

// Store latest JPEG frame in memory
let latestFrame = null;
// All connected MJPEG stream clients
const clients = [];

// ---- ESP32 sends frames here ----
app.post("/upload", express.raw({ type: "image/jpeg", limit: "1mb" }), (req, res) => {
  if (!req.body || req.body.length === 0) {
    return res.status(400).send("No image data");
  }

  latestFrame = req.body;

  // Push frame to all connected MJPEG clients
  clients.forEach((client) => {
    client.write(`--frame\r\nContent-Type: image/jpeg\r\nContent-Length: ${latestFrame.length}\r\n\r\n`);
    client.write(latestFrame);
    client.write("\r\n");
  });

  res.status(200).send("OK");
});

// ---- Flutter app connects here for MJPEG stream ----
app.get("/stream", (req, res) => {
  res.writeHead(200, {
    "Content-Type": "multipart/x-mixed-replace; boundary=frame",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
  });

  // Send current frame immediately if available
  if (latestFrame) {
    res.write(`--frame\r\nContent-Type: image/jpeg\r\nContent-Length: ${latestFrame.length}\r\n\r\n`);
    res.write(latestFrame);
    res.write("\r\n");
  }

  // Add this client to the list
  clients.push(res);

  // Remove client on disconnect
  req.on("close", () => {
    const index = clients.indexOf(res);
    if (index !== -1) clients.splice(index, 1);
    console.log(`Client disconnected. Active: ${clients.length}`);
  });

  console.log(`Client connected. Active: ${clients.length}`);
});

// ---- Get latest frame as JPEG (for Flutter polling) ----
app.get("/latest", (req, res) => {
  if (!latestFrame) {
    return res.status(204).send();
  }
  res.writeHead(200, {
    "Content-Type": "image/jpeg",
    "Content-Length": latestFrame.length,
    "Cache-Control": "no-cache, no-store, must-revalidate",
  });
  res.end(latestFrame);
});

// ---- Health check ----
app.get("/", (req, res) => {
  res.send(`DoorBot Relay Server | Active clients: ${clients.length} | Frame: ${latestFrame ? "yes" : "no"}`);
});

app.listen(PORT, () => {
  console.log(`Relay server running on port ${PORT}`);
});

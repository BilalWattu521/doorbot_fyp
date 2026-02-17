const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Triggers when the doorbell is pressed.
 * Path: users/{uid}/doorbell/pressed
 */
/**
 * Triggers when the doorbell event (timestamp) is updated.
 * Path: users/{uid}/doorbell/event
 */
exports.onDoorbellEvent = functions.database
    .ref("/users/{uid}/doorbell/event")
    .onWrite(async (change, context) => {
      const eventTimestamp = change.after.val();
      const uid = context.params.uid;

      console.log(`Doorbell event for user ${uid}, timestamp: ${eventTimestamp}`);

      // If key was deleted or is null/empty, do nothing
      if (!eventTimestamp) {
        return null;
      }

      // Check if this is a new event (avoid re-triggering on same timestamp if logic was different)
      // Since we listen to onWrite, any update triggers this.
      // The timestamp changing ensures it's a new press.

      // Get the FCM token from the database
      const tokenSnapshot = await admin
          .database()
          .ref(`/users/${uid}/fcm_token`)
          .once("value");

      const fcmToken = tokenSnapshot.val();

      if (!fcmToken) {
        console.log("No FCM token found for user:", uid);
        return null;
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

      try {
        const response = await admin.messaging().send(payload);
        console.log("Successfully sent message:", response);
      } catch (error) {
        console.log("Error sending message:", error);
      }

      return null;
    });

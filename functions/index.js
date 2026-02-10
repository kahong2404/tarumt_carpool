/* eslint-disable */

const admin = require("firebase-admin");
admin.initializeApp();

const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
setGlobalOptions({ maxInstances: 10 });

/**
 * 1) Driver verification -> notify user
 */
exports.onDriverVerificationStatusChange = onDocumentUpdated(
  { document: "driver_verifications/{staffId}", region: "asia-southeast1" },
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    const staffId = String(event.params.staffId);

    const beforeStatus =
      before.verification && before.verification.status
        ? String(before.verification.status)
        : "";

    const afterStatus =
      after.verification && after.verification.status
        ? String(after.verification.status)
        : "";

    // Only when status changes
    if (!beforeStatus || beforeStatus === afterStatus) return;

    // Only approved / rejected
    if (afterStatus !== "approved" && afterStatus !== "rejected") return;

    const uid = after.uid ? String(after.uid) : "";
    if (!uid) return;

    const title = "Driver Verification";
    let message = "";

    if (afterStatus === "approved") {
      message = "Your driver verification has been approved";
    } else {
      message = "Your driver verification was rejected";
      const reason =
        after.verification && after.verification.rejectReason
          ? String(after.verification.rejectReason)
          : "";
      if (reason.trim() !== "") message += "\nReason: " + reason;
    }

    // 1) Save notification in Firestore
    await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection("notifications")
      .add({
        title,
        message,
        type: "driver_verification",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        data: { staffId, status: afterStatus },
      });

    // 2) Send FCM push if token exists
    const userSnap = await admin.firestore().collection("users").doc(uid).get();
    const token =
      userSnap.exists && userSnap.data() && userSnap.data().fcmToken
        ? String(userSnap.data().fcmToken)
        : "";

    if (!token) return;

    await admin.messaging().send({
      token,
      notification: { title, body: message },
      data: { type: "driver_verification", staffId, status: afterStatus },
    });
  }
);

/**
 * 2) Rider request status -> notify rider
 * statuses: incoming / picked_up / completed / canceled
 */
exports.onRiderRequestStatusChange = onDocumentUpdated(
  { document: "riderRequests/{requestId}", region: "asia-southeast1" },
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    const requestId = String(event.params.requestId);

    const fromStatus = (before.status ?? "").toString();
    const toStatus = (after.status ?? "").toString();

    // Only when status changes
    if (!fromStatus || fromStatus === toStatus) return;

    const riderId = (after.riderId ?? "").toString();
    if (!riderId) return;

    let title = "";
    let message = "";

    if (toStatus === "incoming") {
      title = "Driver accepted ✅";
      message = "Your driver accepted your request and is coming to pick you up.";
    } else if (toStatus === "picked_up") {
      title = "Trip started 🚗";
      message = "You have been picked up. Have a safe trip!";
    } else if (toStatus === "completed") {
      title = "Trip completed ✅";
      message = "Your trip is completed. Thanks for riding!";
    } else if (toStatus === "canceled") {
      title = "Ride canceled ❌";
      const reason = (after.cancelReason ?? "").toString().trim();
      message = reason ? `Your ride was canceled.\nReason: ${reason}` : "Your ride was canceled.";
    } else {
      // ignore other statuses
      return;
    }

    // Save in-app notification
    await admin
      .firestore()
      .collection("users")
      .doc(riderId)
      .collection("notifications")
      .add({
        title,
        message,
        type: "ride_status",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        data: {
          requestId,
          activeRideId: (after.activeRideId ?? "").toString(),
          matchedDriverId: (after.matchedDriverId ?? "").toString(),
          fromStatus,
          toStatus,
        },
      });

    // Send FCM push (if token exists)
    const userSnap = await admin.firestore().collection("users").doc(riderId).get();
    const token =
      userSnap.exists && userSnap.data() && userSnap.data().fcmToken
        ? String(userSnap.data().fcmToken)
        : "";

    if (!token) return;

    await admin.messaging().send({
      token,
      notification: { title, body: message },
      data: {
        type: "ride_status",
        requestId,
        activeRideId: (after.activeRideId ?? "").toString(),
        matchedDriverId: (after.matchedDriverId ?? "").toString(),
        fromStatus,
        toStatus,
      },
    });
  }
);

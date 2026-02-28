/* eslint-disable */

const admin = require("firebase-admin");
admin.initializeApp();

const { setGlobalOptions } = require("firebase-functions/v2");
setGlobalOptions({ maxInstances: 10 });

const {
  onDocumentUpdated,
  onDocumentCreated,
} = require("firebase-functions/v2/firestore");

// --------------------
// helpers
// --------------------
function str(v) {
  return v === undefined || v === null ? "" : String(v);
}

function num(v, def) {
  const n = Number(v);
  return Number.isFinite(n) ? n : def;
}

function get(obj, path) {
  if (!obj) return undefined;
  const parts = path.split(".");
  let cur = obj;
  for (const p of parts) {
    if (!cur || typeof cur !== "object" || !(p in cur)) return undefined;
    cur = cur[p];
  }
  return cur;
}

// haversine distance (km)
function distanceKm(aLat, aLng, bLat, bLng) {
  const R = 6371;
  const dLat = ((bLat - aLat) * Math.PI) / 180;
  const dLng = ((bLng - aLng) * Math.PI) / 180;
  const s1 =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((aLat * Math.PI) / 180) *
      Math.cos((bLat * Math.PI) / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(s1), Math.sqrt(1 - s1));
  return R * c;
}

async function writeNotifAndPush(uid, title, message, type, data) {
  // in-app notification
  await admin
    .firestore()
    .collection("users")
    .doc(uid)
    .collection("notifications")
    .add({
      title,
      message,
      type,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
      data: data || {},
    });

  // push notification
  const userSnap = await admin.firestore().collection("users").doc(uid).get();
  const userData = userSnap.exists ? userSnap.data() : null;
  const token = userData && userData.fcmToken ? str(userData.fcmToken) : "";
  if (!token) return;

  await admin.messaging().send({
    token,
    notification: { title, body: message },
    data: Object.assign({ type }, data || {}),
  });
}

// --------------------
// 1) Driver verification -> notify user
// --------------------
exports.onDriverVerificationStatusChange = onDocumentUpdated(
  { document: "driver_verifications/{staffId}", region: "asia-southeast1" },
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    const staffId = str(event.params.staffId);

    const beforeStatus = str(get(before, "verification.status"));
    const afterStatus = str(get(after, "verification.status"));

    if (!beforeStatus || beforeStatus === afterStatus) return;
    if (afterStatus !== "approved" && afterStatus !== "rejected") return;

    const uid = str(after.uid);
    if (!uid) return;

    const title = "Driver Verification";
    let message = "";

    if (afterStatus === "approved") {
      message = "Your driver verification has been approved.";
    } else {
      message = "Your driver verification has been rejected.";
      const reason = str(get(after, "verification.rejectReason")).trim();
      if (reason) message += " Reason: " + reason;
    }

    await writeNotifAndPush(uid, title, message, "driver_verification", {
      staffId,
      status: afterStatus,
    });
  }
);

// --------------------
// 2) riderRequests status changes -> notify rider
// --------------------
exports.onRiderRequestStatusChange = onDocumentUpdated(
  { document: "riderRequests/{requestId}", region: "asia-southeast1" },
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    const requestId = str(event.params.requestId);

    const fromStatus = str(before.status);
    const toStatus = str(after.status);

    if (!fromStatus || fromStatus === toStatus) return;

    const riderId = str(after.riderId);
    if (!riderId) return;

    let title = "";
    let message = "";

    if (toStatus === "incoming") {
      title = "Ride Request Update";
      message =
        "A driver has accepted your ride request and is on the way to the pickup location.";
    } else if (toStatus === "completed") {
      title = "Ride Completed";
      message = "Your ride has been completed. Thank you for using the service.";
    } else if (toStatus === "cancelled") {
      title = "Ride Cancelled";
      const reason = str(after.cancelReason).trim();
      message = reason
        ? "Your ride has been cancelled. Reason: " + reason
        : "Your ride has been cancelled.";
    } else {
      return;
    }

    await writeNotifAndPush(riderId, title, message, "ride_request_status", {
      requestId,
      activeRideId: str(after.activeRideId),
      matchedDriverId: str(after.matchedDriverId),
      fromStatus,
      toStatus,
    });
  }
);

// --------------------
// 3) rides rideStatus changes -> notify rider
// --------------------
exports.onRideStatusChange = onDocumentUpdated(
  { document: "rides/{rideId}", region: "asia-southeast1" },
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    const rideId = str(event.params.rideId);

    const fromStatus = str(before.rideStatus);
    const toStatus = str(after.rideStatus);

    if (!toStatus || fromStatus === toStatus) return;

    const riderId = str(after.riderId || after.riderID);
    if (!riderId) return;

    let title = "";
    let message = "";

    if (toStatus === "arrived_pickup") {
      title = "Ride Status Update";
      message = "Your driver has arrived at the pickup location.";
    } else if (toStatus === "ongoing") {
      title = "Ride Status Update";
      message = "Your trip has started.";
    } else if (toStatus === "arrived_destination") {
      title = "Ride Status Update";
      message = "You have arrived at your destination.";
    } else if (toStatus === "completed") {
      title = "Ride Completed";
      message = "Your ride has been completed. Thank you for using the service.";
    } else {
      return;
    }

    await writeNotifAndPush(riderId, title, message, "ride_status", {
      rideId,
      requestId: str(after.requestId),
      driverID: str(after.driverID),
      fromStatus,
      toStatus,
    });
  }
);

// ======================================================
// 4) Notify nearby drivers when a new request is created
// ======================================================
exports.onRiderRequestCreatedNotifyDrivers = onDocumentCreated(
  { document: "riderRequests/{requestId}", region: "asia-southeast1" },
  async (event) => {
    if (!event.data) return;

    const requestId = str(event.params.requestId);
    const req = event.data.data() || {};

    if (str(req.status) !== "waiting") return;

    const pickupGeo = req.pickupGeo;
    if (!pickupGeo || typeof pickupGeo.latitude !== "number") return;

    const radiusKm = num(req.searchRadiusKm, 2.0);
    const pickupAddr = str(req.pickupAddress);
    const destAddr = str(req.destinationAddress);

    const title = "New Ride Request";
    const body =
      pickupAddr && destAddr
        ? `Pickup Location: ${pickupAddr}\nDestination: ${destAddr}`
        : "A new ride request is available nearby.";

    // read online+available drivers from driverStatus
    const presenceSnap = await admin
      .firestore()
      .collection("driverStatus")
      .where("isOnline", "==", true)
      .where("isAvailable", "==", true)
      .get();

    if (presenceSnap.empty) return;

    const tokens = [];

    for (const doc of presenceSnap.docs) {
      const driverId = doc.id;
      const p = doc.data() || {};

      const geo = p.currentGeo;
      if (!geo || typeof geo.latitude !== "number") continue;

      const km = distanceKm(
        pickupGeo.latitude,
        pickupGeo.longitude,
        geo.latitude,
        geo.longitude
      );

      if (km > radiusKm) continue;

      // token from users/{driverId}
      const userSnap = await admin.firestore().collection("users").doc(driverId).get();
      const u = userSnap.exists ? (userSnap.data() || {}) : {};
      const token = u.fcmToken ? str(u.fcmToken) : "";
      if (!token) continue;

      tokens.push(token);

      // in-app driver notification
      await admin
        .firestore()
        .collection("users")
        .doc(driverId)
        .collection("notifications")
        .add({
          title,
          message: body,
          type: "new_request",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          data: { requestId },
        });
    }

    if (!tokens.length) return;

    const chunkSize = 450;
    for (let i = 0; i < tokens.length; i += chunkSize) {
      const batch = tokens.slice(i, i + chunkSize);
      await admin.messaging().sendEachForMulticast({
        tokens: batch,
        notification: { title, body },
        data: { type: "new_request", requestId },
      });
    }
  }
);

// Stripe wallet exports (keep yours)
const stripeWallet = require("./stripe_wallet");
exports.createTopUpIntent = stripeWallet.createTopUpIntent;
exports.confirmTopUp = stripeWallet.confirmTopUp;
///* eslint-disable */
//
//const admin = require("firebase-admin");
//admin.initializeApp();
//
//const { setGlobalOptions } = require("firebase-functions/v2");
//setGlobalOptions({ maxInstances: 10 });
//
//const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");
//
//// --------------------
//// helpers
//// --------------------
//function str(v) {
//  return v === undefined || v === null ? "" : String(v);
//}
//
//function num(v, def) {
//  const n = Number(v);
//  return Number.isFinite(n) ? n : def;
//}
//
//function get(obj, path) {
//  if (!obj) return undefined;
//  const parts = path.split(".");
//  let cur = obj;
//  for (const p of parts) {
//    if (!cur || typeof cur !== "object" || !(p in cur)) return undefined;
//    cur = cur[p];
//  }
//  return cur;
//}
//
//// haversine distance (km)
//function distanceKm(aLat, aLng, bLat, bLng) {
//  const R = 6371;
//  const dLat = ((bLat - aLat) * Math.PI) / 180;
//  const dLng = ((bLng - aLng) * Math.PI) / 180;
//  const s1 =
//    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
//    Math.cos((aLat * Math.PI) / 180) *
//      Math.cos((bLat * Math.PI) / 180) *
//      Math.sin(dLng / 2) *
//      Math.sin(dLng / 2);
//  const c = 2 * Math.atan2(Math.sqrt(s1), Math.sqrt(1 - s1));
//  return R * c;
//}
//
//async function writeNotifAndPush(uid, title, message, type, data) {
//  // in-app notification
//  await admin
//    .firestore()
//    .collection("users")
//    .doc(uid)
//    .collection("notifications")
//    .add({
//      title,
//      message,
//      type,
//      createdAt: admin.firestore.FieldValue.serverTimestamp(),
//      isRead: false,
//      data: data || {},
//    });
//
//  // push notification
//  const userSnap = await admin.firestore().collection("users").doc(uid).get();
//  const userData = userSnap.exists ? userSnap.data() : null;
//  const token = userData && userData.fcmToken ? str(userData.fcmToken) : "";
//  if (!token) return;
//
//  await admin.messaging().send({
//    token,
//    notification: { title, body: message },
//    data: Object.assign({ type }, data || {}),
//  });
//}
//
//// --------------------
//// 1) Driver verification -> notify user
//// --------------------
//exports.onDriverVerificationStatusChange = onDocumentUpdated(
//  { document: "driver_verifications/{staffId}", region: "asia-southeast1" },
//  async (event) => {
//    if (!event.data) return;
//
//    const before = event.data.before.data() || {};
//    const after = event.data.after.data() || {};
//    const staffId = str(event.params.staffId);
//
//    const beforeStatus = str(get(before, "verification.status"));
//    const afterStatus = str(get(after, "verification.status"));
//
//    if (!beforeStatus || beforeStatus === afterStatus) return;
//    if (afterStatus !== "approved" && afterStatus !== "rejected") return;
//
//    const uid = str(after.uid);
//    if (!uid) return;
//
//    const title = "Driver Verification";
//    let message = "";
//
//    if (afterStatus === "approved") {
//      message = "Your driver verification has been approved";
//    } else {
//      message = "Your driver verification was rejected";
//      const reason = str(get(after, "verification.rejectReason")).trim();
//      if (reason) message += "\nReason: " + reason;
//    }
//
//    await writeNotifAndPush(uid, title, message, "driver_verification", {
//      staffId,
//      status: afterStatus,
//    });
//  }
//);
//
//// --------------------
//// 2) riderRequests status changes -> notify rider
//// --------------------
//exports.onRiderRequestStatusChange = onDocumentUpdated(
//  { document: "riderRequests/{requestId}", region: "asia-southeast1" },
//  async (event) => {
//    if (!event.data) return;
//
//    const before = event.data.before.data() || {};
//    const after = event.data.after.data() || {};
//    const requestId = str(event.params.requestId);
//
//    const fromStatus = str(before.status);
//    const toStatus = str(after.status);
//
//    if (!fromStatus || fromStatus === toStatus) return;
//
//    const riderId = str(after.riderId);
//    if (!riderId) return;
//
//    let title = "";
//    let message = "";
//
//    if (toStatus === "incoming") {
//      title = "Driver accepted ✅";
//      message = "Your driver accepted your request and is coming to pick you up.";
//    } else if (toStatus === "completed") {
//      title = "Trip completed ✅";
//      message = "Your trip has been completed. Thanks for riding!";
//    } else if (toStatus === "cancelled") {
//      title = "Ride cancelled ❌";
//      const reason = str(after.cancelReason).trim();
//      message = reason
//        ? "Your ride was cancelled.\nReason: " + reason
//        : "Your ride was cancelled.";
//    } else {
//      return;
//    }
//
//    await writeNotifAndPush(riderId, title, message, "ride_request_status", {
//      requestId,
//      activeRideId: str(after.activeRideId),
//      matchedDriverId: str(after.matchedDriverId),
//      fromStatus,
//      toStatus,
//    });
//  }
//);
//
//// --------------------
//// 3) rides rideStatus changes -> notify rider
//// --------------------
//exports.onRideStatusChange = onDocumentUpdated(
//  { document: "rides/{rideId}", region: "asia-southeast1" },
//  async (event) => {
//    if (!event.data) return;
//
//    const before = event.data.before.data() || {};
//    const after = event.data.after.data() || {};
//    const rideId = str(event.params.rideId);
//
//    const fromStatus = str(before.rideStatus);
//    const toStatus = str(after.rideStatus);
//
//    if (!toStatus || fromStatus === toStatus) return;
//
//    const riderId = str(after.riderId || after.riderID);
//    if (!riderId) return;
//
//    let title = "";
//    let message = "";
//
//    if (toStatus === "arrived_pickup") {
//      title = "Driver arrived 🚗";
//      message = "Your driver has arrived at the pickup location.";
//    } else if (toStatus === "ongoing") {
//      title = "Trip started 🚗";
//      message = "Your trip has started. Have a safe journey!";
//    } else if (toStatus === "arrived_destination") {
//      title = "Arrived 🎯";
//      message = "You have arrived at your destination.";
//    } else if (toStatus === "completed") {
//      title = "Trip completed ✅";
//      message = "Your trip is completed. Thanks for riding!";
//    } else {
//      return;
//    }
//
//    await writeNotifAndPush(riderId, title, message, "ride_status", {
//      rideId,
//      requestId: str(after.requestId),
//      driverID: str(after.driverID),
//      fromStatus,
//      toStatus,
//    });
//  }
//);
//
//// ======================================================
//// 4) NEW: Notify nearby drivers when a new request is created
//// ======================================================
//exports.onRiderRequestCreatedNotifyDrivers = onDocumentCreated(
//  { document: "riderRequests/{requestId}", region: "asia-southeast1" },
//  async (event) => {
//    if (!event.data) return;
//
//    const requestId = str(event.params.requestId);
//    const req = event.data.data() || {};
//
//    if (str(req.status) !== "waiting") return;
//
//    const pickupGeo = req.pickupGeo;
//    if (!pickupGeo || typeof pickupGeo.latitude !== "number") return;
//
//    const radiusKm = num(req.searchRadiusKm, 2.0);
//    const pickupAddr = str(req.pickupAddress);
//    const destAddr = str(req.destinationAddress);
//
//    const title = "New ride request 🚕";
//    const body =
//      pickupAddr && destAddr
//        ? `Pickup: ${pickupAddr}\nDropoff: ${destAddr}`
//        : "A new ride request is available near you.";
//
//    // ✅ Correct: read from driverStatus (your DriverPresenceService writes here)
//    const presenceSnap = await admin
//      .firestore()
//      .collection("driverStatus")
//      .where("isOnline", "==", true)
//      .where("isAvailable", "==", true)
//      .get();
//
//    if (presenceSnap.empty) return;
//
//    const tokens = [];
//
//    for (const doc of presenceSnap.docs) {
//      const driverId = doc.id;
//      const p = doc.data() || {};
//
//      // ✅ Correct field name
//      const geo = p.currentGeo;
//      if (!geo || typeof geo.latitude !== "number") continue;
//
//      const km = distanceKm(
//        pickupGeo.latitude,
//        pickupGeo.longitude,
//        geo.latitude,
//        geo.longitude
//      );
//
//      if (km > radiusKm) continue;
//
//      // token from users/{driverId}
//      const userSnap = await admin.firestore().collection("users").doc(driverId).get();
//      const u = userSnap.exists ? (userSnap.data() || {}) : {};
//      const token = u.fcmToken ? str(u.fcmToken) : "";
//      if (!token) continue;
//
//      tokens.push(token);
//
//      // optional: in-app driver notification
//      await admin
//        .firestore()
//        .collection("users")
//        .doc(driverId)
//        .collection("notifications")
//        .add({
//          title,
//          message: body,
//          type: "new_request",
//          createdAt: admin.firestore.FieldValue.serverTimestamp(),
//          isRead: false,
//          data: { requestId },
//        });
//    }
//
//    if (!tokens.length) return;
//
//    // chunk-safe send
//    const chunkSize = 450;
//    for (let i = 0; i < tokens.length; i += chunkSize) {
//      const batch = tokens.slice(i, i + chunkSize);
//      await admin.messaging().sendEachForMulticast({
//        tokens: batch,
//        notification: { title, body },
//        data: { type: "new_request", requestId },
//      });
//    }
//  }
//);
//
//// ✅ Stripe wallet exports (keep yours)
//const stripeWallet = require("./stripe_wallet");
//exports.createTopUpIntent = stripeWallet.createTopUpIntent;
//exports.confirmTopUp = stripeWallet.confirmTopUp;
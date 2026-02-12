/* eslint-disable */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
admin.initializeApp();

const { setGlobalOptions } = require("firebase-functions/v2");
setGlobalOptions({ maxInstances: 10 });

const { onDocumentUpdated, onDocumentCreated } = require("firebase-functions/v2/firestore");

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
      message = "Your driver verification has been approved";
    } else {
      message = "Your driver verification was rejected";
      const reason = str(get(after, "verification.rejectReason")).trim();
      if (reason) message += "\nReason: " + reason;
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
      title = "Driver accepted ✅";
      message = "Your driver accepted your request and is coming to pick you up.";
    } else if (toStatus === "completed") {
      title = "Trip completed ✅";
      message = "Your trip has been completed. Thanks for riding!";
    } else if (toStatus === "cancelled") {
      title = "Ride cancelled ❌";
      const reason = str(after.cancelReason).trim();
      message = reason
        ? "Your ride was cancelled.\nReason: " + reason
        : "Your ride was cancelled.";
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
      title = "Driver arrived 🚗";
      message = "Your driver has arrived at the pickup location.";
    } else if (toStatus === "ongoing") {
      title = "Trip started 🚗";
      message = "Your trip has started. Have a safe journey!";
    } else if (toStatus === "arrived_destination") {
      title = "Arrived 🎯";
      message = "You have arrived at your destination.";
    } else if (toStatus === "completed") {
      title = "Trip completed ✅";
      message = "Your trip is completed. Thanks for riding!";
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
// 4) NEW: Notify nearby drivers when a new request is created
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

    const title = "New ride request 🚕";
    const body =
      pickupAddr && destAddr
        ? `Pickup: ${pickupAddr}\nDropoff: ${destAddr}`
        : "A new ride request is available near you.";

    // ✅ Correct: read from driverStatus (your DriverPresenceService writes here)
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

      // ✅ Correct field name
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

      // optional: in-app driver notification
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

    // chunk-safe send
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

// ======================================================
// 5) ESCROW PAYMENT (Callable Functions)
// ======================================================

function centsFromRm(rm) {
  return Math.round(Number(rm) * 100);
}

function rmFromCents(cents) {
  return Number(cents) / 100.0;
}

// Use SAME pricing as your DriverTripMapScreen (server-safe)
function calcFareRm(km) {
  const baseFare = 2.0;
  const ratePerKm = 2.0;
  const minFare = 3.0;
  const maxFare = 50.0;

  const raw = baseFare + ratePerKm * km;
  const withMin = raw < minFare ? minFare : raw;
  const capped = withMin > maxFare ? maxFare : withMin;
  return Number(capped.toFixed(2));
}

function requireSignedIn(req) {
  if (!req.auth) throw new HttpsError("unauthenticated", "Login required");
  return req.auth.uid;
}

async function getUserWalletCents(tx, uid) {
  const ref = admin.firestore().collection("users").doc(uid);
  const snap = await tx.get(ref);
  if (!snap.exists) throw new HttpsError("not-found", "User not found");
  const data = snap.data() || {};
  const bal = Number(data.walletBalance || 0);
  if (!Number.isFinite(bal)) return 0;
  return Math.floor(bal);
}

function makeTxDoc(txRef, payload) {
  return {
    ...payload,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

// ----------------------------
// A) acceptRideRequest(requestId)
// - lock riderRequests waiting -> incoming
// - create ride
// - hold rider money (deduct walletBalance)
// - write wallet tx: ride_hold
// ----------------------------
exports.acceptRideRequest = onCall(
  { region: "asia-southeast1" },
  async (req) => {
    const driverId = requireSignedIn(req);
    const requestId = String(req.data?.requestId || "").trim();
    if (!requestId) throw new HttpsError("invalid-argument", "Missing requestId");

    const db = admin.firestore();
    const requests = db.collection("riderRequests");
    const rides = db.collection("rides");
    const users = db.collection("users");
    const txRoot = db.collection("walletTransactions");

    const rideId = await db.runTransaction(async (tx) => {
      // 1) driver must have no active ride
      const activeRideSnap = await tx.get(
        rides
          .where("driverID", "==", driverId)
          .where("rideStatus", "in", ["incoming", "arrived_pickup", "ongoing", "arrived_destination"])
          .limit(1)
      );
      if (!activeRideSnap.empty) {
        throw new HttpsError("failed-precondition", "You already have an active ride.");
      }

      // 2) lock request
      const reqRef = requests.doc(requestId);
      const reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) throw new HttpsError("not-found", "Request not found");

      const r = reqSnap.data() || {};
      const status = str(r.status);
      if (status !== "waiting") {
        throw new HttpsError("failed-precondition", "Request is not available.");
      }

      if (r.matchedDriverId) {
        throw new HttpsError("failed-precondition", "Request already taken.");
      }

      const riderId = str(r.riderId);
      if (!riderId) throw new HttpsError("failed-precondition", "Request missing riderId.");

      const pickupGeo = r.pickupGeo;
      const destinationGeo = r.destinationGeo;
      if (!pickupGeo || !destinationGeo) {
        throw new HttpsError("failed-precondition", "Request missing locations.");
      }

      // 3) compute hold amount from straight-line distance (server-safe)
      const km = distanceKm(
        pickupGeo.latitude,
        pickupGeo.longitude,
        destinationGeo.latitude,
        destinationGeo.longitude
      );

      const fareRm = calcFareRm(km);
      const holdCents = centsFromRm(fareRm);
      if (holdCents <= 0) throw new HttpsError("internal", "Invalid fare.");

      // 4) ensure rider has enough
      const riderRef = users.doc(riderId);
      const riderBal = await getUserWalletCents(tx, riderId);
      if (riderBal < holdCents) {
        throw new HttpsError("failed-precondition", "Rider has insufficient wallet balance.");
      }

      // 5) create ride
      const rideRef = rides.doc();
      const now = admin.firestore.FieldValue.serverTimestamp();

      tx.set(rideRef, {
        requestId,
        driverID: driverId,
        riderID: riderId,
        rideStatus: "incoming",

        pickupAddress: str(r.pickupAddress),
        destinationAddress: str(r.destinationAddress),
        pickupGeo,
        destinationGeo,

        acceptedAt: now,
        createdAt: now,
        updatedAt: now,

        // payment / escrow
        paymentStatus: "held", // held -> paid/refunded
        holdAmountCents: holdCents,
        finalFare: rmFromCents(holdCents),
      });

      // 6) update request -> incoming
      tx.update(reqRef, {
        status: "incoming",
        matchedDriverId: driverId,
        activeRideId: rideRef.id,
        acceptedAt: now,
        updatedAt: now,
      });

      // 7) deduct rider balance
      tx.update(riderRef, {
        walletBalance: riderBal - holdCents,
        updatedAt: now,
      });

      // 8) wallet tx record (rider)
      const riderTxRef = txRoot.doc();
      tx.set(
        riderTxRef,
        makeTxDoc(riderTxRef, {
          uid: riderId,
          type: "ride_hold",
          method: "escrow",
          title: "Ride (Hold)",
          amountCents: -holdCents,
          status: "success",
          ref: { requestId, rideId: rideRef.id, driverId },
        })
      );

      return rideRef.id;
    });

    return { ok: true, rideId };
  }
);

// ----------------------------
// B) cancelRide(rideId, by)
// - if paymentStatus==held => refund rider
// - mark ride cancelled
// - mark request cancelled
// ----------------------------
exports.cancelRide = onCall(
  { region: "asia-southeast1" },
  async (req) => {
    const uid = requireSignedIn(req);
    const rideId = String(req.data?.rideId || "").trim();
    const by = String(req.data?.by || "").trim(); // "driver" | "rider"
    const reason = String(req.data?.reason || "").trim();

    if (!rideId) throw new HttpsError("invalid-argument", "Missing rideId");
    if (by !== "driver" && by !== "rider") throw new HttpsError("invalid-argument", "Invalid by");

    const db = admin.firestore();
    const rides = db.collection("rides");
    const requests = db.collection("riderRequests");
    const users = db.collection("users");
    const txRoot = db.collection("walletTransactions");

    await db.runTransaction(async (tx) => {
      const rideRef = rides.doc(rideId);
      const rideSnap = await tx.get(rideRef);
      if (!rideSnap.exists) throw new HttpsError("not-found", "Ride not found");

      const ride = rideSnap.data() || {};

      const driverID = str(ride.driverID);
      const riderID = str(ride.riderID);
      if (!driverID || !riderID) throw new HttpsError("failed-precondition", "Ride missing users");

      // only driver or rider can cancel
      if (uid !== driverID && uid !== riderID) {
        throw new HttpsError("permission-denied", "Not allowed");
      }

      const rideStatus = str(ride.rideStatus);
      if (rideStatus === "completed") {
        throw new HttpsError("failed-precondition", "Cannot cancel completed ride");
      }
      if (rideStatus === "cancelled") return;

      const requestId = str(ride.requestId || ride.requestID);
      const paymentStatus = str(ride.paymentStatus);
      const holdCents = Number(ride.holdAmountCents || 0);

      const now = admin.firestore.FieldValue.serverTimestamp();

      // refund if held
      if (paymentStatus === "held" && holdCents > 0) {
        const riderRef = users.doc(riderID);
        const bal = await getUserWalletCents(tx, riderID);

        tx.update(riderRef, {
          walletBalance: bal + holdCents,
          updatedAt: now,
        });

        const refundTxRef = txRoot.doc();
        tx.set(
          refundTxRef,
          makeTxDoc(refundTxRef, {
            uid: riderID,
            type: "ride_refund",
            method: "escrow",
            title: "Ride (Refund)",
            amountCents: holdCents,
            status: "success",
            ref: { rideId, requestId, cancelledBy: by },
          })
        );
      }

      // update ride
      tx.update(rideRef, {
        rideStatus: "cancelled",
        paymentStatus: paymentStatus === "held" ? "refunded" : paymentStatus,
        cancelledBy: by,
        cancelReason: reason || null,
        cancelledAt: now,
        updatedAt: now,
      });

      // update request if exists
      if (requestId) {
        const reqRef = requests.doc(requestId);
        const reqSnap = await tx.get(reqRef);
        if (reqSnap.exists) {
          tx.update(reqRef, {
            status: "cancelled",
            cancelReason: reason || null,
            updatedAt: now,
          });
        }
      }
    });

    return { ok: true };
  }
);

// ----------------------------
// C) completeRide(rideId)
// - only driver can complete
// - if paymentStatus==held => credit driver
// - mark ride completed
// - mark request completed
// ----------------------------
exports.completeRide = onCall(
  { region: "asia-southeast1" },
  async (req) => {
    const driverId = requireSignedIn(req);
    const rideId = String(req.data?.rideId || "").trim();
    if (!rideId) throw new HttpsError("invalid-argument", "Missing rideId");

    const db = admin.firestore();
    const rides = db.collection("rides");
    const requests = db.collection("riderRequests");
    const users = db.collection("users");
    const txRoot = db.collection("walletTransactions");

    await db.runTransaction(async (tx) => {
      const rideRef = rides.doc(rideId);
      const rideSnap = await tx.get(rideRef);
      if (!rideSnap.exists) throw new HttpsError("not-found", "Ride not found");

      const ride = rideSnap.data() || {};

      if (str(ride.driverID) !== driverId) {
        throw new HttpsError("permission-denied", "Only driver can complete");
      }

      const rideStatus = str(ride.rideStatus);
      if (rideStatus === "cancelled") {
        throw new HttpsError("failed-precondition", "Ride already cancelled");
      }
      if (rideStatus === "completed") return;

      // (optional strict) allow complete only if arrived_destination
      // if (rideStatus !== "arrived_destination") throw new HttpsError("failed-precondition", "Not arrived yet");

      const paymentStatus = str(ride.paymentStatus);
      const holdCents = Number(ride.holdAmountCents || 0);
      if (holdCents <= 0) throw new HttpsError("failed-precondition", "No held payment");

      const riderID = str(ride.riderID);
      const driverID = str(ride.driverID);
      const requestId = str(ride.requestId || ride.requestID);

      const now = admin.firestore.FieldValue.serverTimestamp();

      // pay driver once
      if (paymentStatus === "held") {
        const driverRef = users.doc(driverID);
        const driverBal = await getUserWalletCents(tx, driverID);

        tx.update(driverRef, {
          walletBalance: driverBal + holdCents,
          updatedAt: now,
        });

        const earnTxRef = txRoot.doc();
        tx.set(
          earnTxRef,
          makeTxDoc(earnTxRef, {
            uid: driverID,
            type: "ride_earning",
            method: "escrow",
            title: "Ride (Earning)",
            amountCents: holdCents,
            status: "success",
            ref: { rideId, requestId, riderId: riderID },
          })
        );
      }

      // update ride completed
      tx.update(rideRef, {
        rideStatus: "completed",
        paymentStatus: "paid",
        completedAt: now,
        updatedAt: now,
      });

      // update request completed
      if (requestId) {
        const reqRef = requests.doc(requestId);
        const reqSnap = await tx.get(reqRef);
        if (reqSnap.exists) {
          tx.update(reqRef, {
            status: "completed",
            updatedAt: now,
          });
        }
      }
    });

    return { ok: true };
  }
);


// ✅ Stripe wallet exports (keep yours)
const stripeWallet = require("./stripe_wallet");
exports.createTopUpIntent = stripeWallet.createTopUpIntent;
exports.confirmTopUp = stripeWallet.confirmTopUp;
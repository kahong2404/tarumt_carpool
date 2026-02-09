/* eslint-disable */
const admin = require("firebase-admin");
admin.initializeApp();

const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
setGlobalOptions({ maxInstances: 10 });

exports.onDriverVerificationStatusChange = onDocumentUpdated(
  { document: "driver_verifications/{userId}", region: "asia-southeast1" },
  async (event) => {
    if (!event.data) return;

    const before = event.data.before.data();
    const after = event.data.after.data();
    const userId = String(event.params.userId);

    const beforeStatus =
      before && before.verification && before.verification.status
        ? before.verification.status
        : null;

    const afterStatus =
      after && after.verification && after.verification.status
        ? after.verification.status
        : null;

    if (!beforeStatus || beforeStatus === afterStatus) return;
    if (afterStatus !== "approved" && afterStatus !== "rejected") return;

    const uid = after && after.uid ? String(after.uid) : "";
    if (!uid) return;

    const title = "Driver Verification";
    let message = "";

    if (afterStatus === "approved") {
      message = "Your driver verification has been approved";
    } else {
      message = "Your driver verification was rejected";
      const reason =
        after &&
        after.verification &&
        after.verification.rejectReason
          ? String(after.verification.rejectReason)
          : "";
      if (reason.trim() !== "") {
        message += "\nReason: " + reason;
      }
    }

    await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection("notifications")
      .add({
        title: title,
        message: message,
        type: "driver_verification",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        data: { userId: userId, status: afterStatus },
      });

    const userSnap = await admin.firestore().collection("users").doc(uid).get();
    const token =
      userSnap.exists && userSnap.data() && userSnap.data().fcmToken
        ? String(userSnap.data().fcmToken)
        : "";

    if (!token) return;

    await admin.messaging().send({
      token: token,
      notification: { title: title, body: message },
      data: { type: "driver_verification", userId: userId, status: afterStatus },
    });
  }
);

// ✅ Stripe wallet exports (ONLY these)
const stripeWallet = require("./stripe_wallet");
exports.createTopUpIntent = stripeWallet.createTopUpIntent;
exports.confirmTopUp = stripeWallet.confirmTopUp;

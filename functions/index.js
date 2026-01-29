/* eslint-disable */

const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

// Optional cost control
setGlobalOptions({maxInstances: 10});

exports.onDriverVerificationStatusChange = onDocumentUpdated(
  {document: "driver_verifications/{staffId}", region: "asia-southeast1"},
  async (event) => {

    if (!event.data) return;

    const before = event.data.before.data();
    const after = event.data.after.data();
    const staffId = String(event.params.staffId);

    const beforeStatus =
      before && before.verification
        ? before.verification.status
        : null;

    const afterStatus =
      after && after.verification
        ? after.verification.status
        : null;

    // Only when status changes
    if (!beforeStatus || beforeStatus === afterStatus) return;

    // Only approved / rejected
    if (afterStatus !== "approved" && afterStatus !== "rejected") return;

    const uid = after && after.uid ? String(after.uid) : "";
    if (!uid) return;

    const title = "Driver Verification";

    let message = "";
    if (afterStatus === "approved") {
      message = "Your driver verification has been approved";
    } else {
      message = "Your driver verification was rejected";
      if (
        after.verification &&
        after.verification.rejectReason &&
        String(after.verification.rejectReason).trim() !== ""
      ) {
        message += "\nReason: " + after.verification.rejectReason;
      }
    }

    // 1) Save notification in Firestore
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
        data: {
          staffId: staffId,
          status: afterStatus,
        },
      });

    // 2) Send FCM push if token exists
    const userSnap = await admin.firestore().collection("users").doc(uid).get();
    const token =
      userSnap.exists && userSnap.data().fcmToken
        ? String(userSnap.data().fcmToken)
        : "";

    if (!token) return;

    await admin.messaging().send({
      token: token,
      notification: {
        title: title,
        body: message,
      },
      data: {
        type: "driver_verification",
        staffId: staffId,
        status: afterStatus,
      },
    });
  }
);

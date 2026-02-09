/* eslint-disable */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const Stripe = require("stripe");
const admin = require("firebase-admin");

const STRIPE_SECRET = defineSecret("STRIPE_SECRET");

const MIN_TOPUP_CENTS = 2000; // RM20
const USERS = "users";
const TX = "walletTransactions";

exports.createTopUpIntent = onCall(
  { region: "asia-southeast1", secrets: [STRIPE_SECRET] },
  async (req) => {
    if (!req.auth) throw new HttpsError("unauthenticated", "Login required");

    const data = req.data || {};
    const amountCents = Number(data.amountCents || 0);

    if (!Number.isInteger(amountCents) || amountCents < MIN_TOPUP_CENTS) {
      throw new HttpsError("invalid-argument", "Minimum top up is RM20");
    }

    const key = STRIPE_SECRET.value();

    // Safe debug (won't leak full key)
    console.log("STRIPE startsWith sk_test:", key.indexOf("sk_test_") === 0);
    console.log("STRIPE length:", key.length);
    console.log("STRIPE first12:", key.slice(0, 12));
    console.log("STRIPE last4:", key.slice(-4));

    const stripe = new Stripe(key);

    const pi = await stripe.paymentIntents.create({
      amount: amountCents,
      currency: "myr",
      automatic_payment_methods: { enabled: true },
      metadata: {
        uid: req.auth.uid,
        purpose: "wallet_topup",
      },
    });

    return {
      clientSecret: pi.client_secret,
      paymentIntentId: pi.id,
    };
  }
);

exports.confirmTopUp = onCall(
  { region: "asia-southeast1", secrets: [STRIPE_SECRET] },
  async (req) => {
    if (!req.auth) throw new HttpsError("unauthenticated", "Login required");

    const data = req.data || {};
    const paymentIntentId = String(data.paymentIntentId || "");
    if (!paymentIntentId) throw new HttpsError("invalid-argument", "Missing paymentIntentId");

    const uid = req.auth.uid;

    const stripe = new Stripe(STRIPE_SECRET.value());
    const pi = await stripe.paymentIntents.retrieve(paymentIntentId);

    if (!pi.metadata || pi.metadata.uid !== uid || pi.metadata.purpose !== "wallet_topup") {
      throw new HttpsError("permission-denied", "Not your payment");
    }

    if (pi.status !== "succeeded") {
      throw new HttpsError("failed-precondition", "Payment not completed: " + pi.status);
    }

    const existing = await admin
      .firestore()
      .collection(TX)
      .where("uid", "==", uid)
      .where("ref.paymentIntentId", "==", paymentIntentId)
      .limit(1)
      .get();

    if (!existing.empty) return { ok: true, alreadyCredited: true };

    const userRef = admin.firestore().collection(USERS).doc(uid);

    await admin.firestore().runTransaction(async (t) => {
      const snap = await t.get(userRef);
      if (!snap.exists) throw new HttpsError("not-found", "User not found");

      const userData = snap.data() || {};
      const raw = userData.walletBalance || 0;

      const balanceCents =
        typeof raw === "number" && Number.isInteger(raw)
          ? raw
          : Math.round(Number(raw) * 100);

      t.update(userRef, {
        walletBalance: balanceCents + pi.amount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      t.set(admin.firestore().collection(TX).doc(), {
        uid: uid,
        type: "topup",
        amountCents: pi.amount,
        status: "success",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        ref: {
          paymentIntentId: paymentIntentId,
          methods: pi.payment_method_types || [],
        },
      });
    });

    return { ok: true, alreadyCredited: false };
  }
);

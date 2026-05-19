const express = require("express");
const pool = require("../config/db");
const logger = require("../middleware/logger");
const razorpayService = require("../services/razorpayService");

const router = express.Router();

const getEntityId = (payload) => {
  const eventPayload = payload.payload || {};
  const entity =
    eventPayload.payment?.entity ||
    eventPayload.order?.entity ||
    eventPayload.refund?.entity ||
    eventPayload.transfer?.entity;

  return entity?.id || null;
};

const findOrderByRazorpay = async (connection, entity = {}) => {
  const notesOrderId = entity.notes?.orderId || entity.notes?.order_id;

  if (notesOrderId) {
    const [orders] = await connection.query(
      `SELECT * FROM orders WHERE id = ? LIMIT 1`,
      [notesOrderId],
    );

    if (orders.length) {
      return orders[0];
    }
  }

  const razorpayOrderId = entity.order_id || entity.id;
  const razorpayPaymentId = entity.payment_id || entity.id;

  const [orders] = await connection.query(
    `
    SELECT *
    FROM orders
    WHERE razorpay_order_id = ?
       OR razorpay_payment_id = ?
       OR payment_id = ?
    LIMIT 1
    `,
    [razorpayOrderId, razorpayPaymentId, razorpayPaymentId],
  );

  return orders[0] || null;
};

const markWebhookPaymentCaptured = async (connection, payment) => {
  if (!payment) {
    return;
  }

  const order = await findOrderByRazorpay(connection, payment);

  if (!order) {
    return;
  }

  const expectedAmount =
    Number(order.razorpay_expected_amount || 0) ||
    razorpayService.calculatePayableAmount({ ...order, shareholders: [] });

  if (
    String(order.razorpay_order_id) !== String(payment.order_id) ||
    Number(payment.amount) !== Number(expectedAmount)
  ) {
    logger.warn("Ignoring mismatched Razorpay payment webhook", {
      orderId: order.id,
      paymentId: payment.id,
      paymentOrderId: payment.order_id,
      expectedOrderId: order.razorpay_order_id,
      amount: payment.amount,
      expectedAmount,
    });
    return;
  }

  await connection.query(
    `
    UPDATE orders
    SET payment_id = ?,
        razorpay_payment_id = ?,
        razorpay_payment_status = ?,
        payment_verified_at = COALESCE(payment_verified_at, NOW()),
        payment_status = 0
    WHERE id = ?
    `,
    [payment.id, payment.id, payment.status || "captured", order.id],
  );

  await connection.query(
    `
    UPDATE shareholder_details
    SET payment_status = 0,
        status = CASE WHEN status = 0 THEN 1 ELSE status END
    WHERE order_id = ?
    `,
    [order.id],
  );
};

const markWebhookPaymentFailed = async (connection, payment) => {
  if (!payment) {
    return;
  }

  const order = await findOrderByRazorpay(connection, payment);

  if (!order || Number(order.payment_status) === 0) {
    return;
  }

  await connection.query(
    `
    UPDATE orders
    SET razorpay_payment_status = ?,
        payment_status = TRUE
    WHERE id = ?
    `,
    [payment.status || "failed", order.id],
  );
};

const updateRefundStatus = async (connection, refund, eventType) => {
  if (!refund) {
    return;
  }

  const order = await findOrderByRazorpay(connection, refund);

  if (!order) {
    return;
  }

  const nextRefundStatus =
    eventType === "refund.failed"
      ? "failed"
      : eventType === "refund.processed"
        ? "processed"
        : "initiated";
  const cancellationStatus =
    nextRefundStatus === "processed"
      ? "refunded"
      : nextRefundStatus === "failed"
        ? "refund_failed"
        : "refund_pending";

  await connection.query(
    `
    UPDATE orders
    SET razorpay_refund_id = COALESCE(razorpay_refund_id, ?),
        razorpay_refund_status = ?,
        refund_amount = COALESCE(refund_amount, ?),
        refund_processed_at = CASE WHEN ? = 'processed' THEN NOW() ELSE refund_processed_at END,
        cancellation_status = CASE
          WHEN status = 2 THEN ?
          ELSE cancellation_status
        END,
        payment_status = CASE WHEN ? = 'processed' THEN 1 ELSE payment_status END
    WHERE id = ?
    `,
    [
      refund.id,
      nextRefundStatus,
      refund.amount || null,
      nextRefundStatus,
      cancellationStatus,
      nextRefundStatus,
      order.id,
    ],
  );
};

const updateTransferStatus = async (connection, transfer, eventType) => {
  if (!transfer) {
    return;
  }

  const order = await findOrderByRazorpay(connection, transfer);

  if (!order) {
    return;
  }

  const status =
    transfer.status ||
    (eventType === "transfer.processed"
      ? "processed"
      : eventType === "transfer.failed"
        ? "failed"
        : "reversed");

  await connection.query(
    `
    UPDATE orders
    SET razorpay_transfer_id = COALESCE(razorpay_transfer_id, ?),
        razorpay_transfer_status = ?,
        vendor_linked_account_id = COALESCE(vendor_linked_account_id, ?)
    WHERE id = ?
    `,
    [transfer.id, status, transfer.recipient || transfer.account, order.id],
  );

  await connection.query(
    `
    INSERT INTO razorpay_transfers
      (order_id, razorpay_order_id, razorpay_payment_id, transfer_id,
       linked_account_id, amount, currency, status)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
      razorpay_payment_id = VALUES(razorpay_payment_id),
      amount = VALUES(amount),
      currency = VALUES(currency),
      status = VALUES(status),
      updated_at = CURRENT_TIMESTAMP
    `,
    [
      order.id,
      order.razorpay_order_id,
      order.razorpay_payment_id,
      transfer.id,
      transfer.recipient || transfer.account || order.vendor_linked_account_id,
      transfer.amount || 0,
      transfer.currency || order.razorpay_currency || "INR",
      status,
    ],
  );
};

const processEvent = async (connection, payload) => {
  const eventType = payload.event;
  const eventPayload = payload.payload || {};

  switch (eventType) {
    case "payment.captured":
      await markWebhookPaymentCaptured(connection, eventPayload.payment?.entity);
      break;
    case "order.paid":
      if (eventPayload.payment?.entity) {
        await markWebhookPaymentCaptured(connection, eventPayload.payment.entity);
      } else if (eventPayload.order?.entity) {
        const order = await findOrderByRazorpay(connection, eventPayload.order.entity);
        if (order) {
          await connection.query(
            `UPDATE orders SET razorpay_order_status = ?, payment_status = 0 WHERE id = ?`,
            [eventPayload.order.entity.status || "paid", order.id],
          );
        }
      }
      break;
    case "payment.failed":
      await markWebhookPaymentFailed(connection, eventPayload.payment?.entity);
      break;
    case "refund.created":
    case "refund.processed":
    case "refund.failed":
      await updateRefundStatus(connection, eventPayload.refund?.entity, eventType);
      break;
    case "transfer.processed":
    case "transfer.failed":
    case "transfer.reversed":
      await updateTransferStatus(connection, eventPayload.transfer?.entity, eventType);
      break;
    default:
      logger.info("Ignored Razorpay webhook event", { eventType });
      break;
  }
};

router.post("/", async (req, res) => {
  const rawBody = req.body;
  const signature = req.headers["x-razorpay-signature"];

  try {
    if (!Buffer.isBuffer(rawBody)) {
      return res.status(400).json({ message: "Raw webhook body is required" });
    }

    if (!razorpayService.verifyWebhookSignature(rawBody, signature)) {
      return res.status(400).json({ message: "Invalid webhook signature" });
    }

    const payload = JSON.parse(rawBody.toString("utf8"));
    const eventId = payload.id;
    const eventType = payload.event;

    if (!eventId || !eventType) {
      return res.status(400).json({ message: "Invalid webhook payload" });
    }

    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      try {
        await connection.query(
          `
          INSERT INTO razorpay_webhook_events
            (razorpay_event_id, event_type, entity_id, payload_json)
          VALUES (?, ?, ?, ?)
          `,
          [
            eventId,
            eventType,
            getEntityId(payload),
            JSON.stringify(payload),
          ],
        );
      } catch (insertError) {
        if (insertError.code === "ER_DUP_ENTRY") {
          await connection.rollback();
          connection.release();
          return res.json({ success: true, duplicate: true });
        }

        throw insertError;
      }

      await processEvent(connection, payload);

      await connection.query(
        `
        UPDATE razorpay_webhook_events
        SET processed_at = NOW()
        WHERE razorpay_event_id = ?
        `,
        [eventId],
      );

      await connection.commit();
      connection.release();

      return res.json({ success: true });
    } catch (error) {
      await connection.rollback();
      connection.release();
      throw error;
    }
  } catch (error) {
    logger.error("Razorpay webhook processing failed", {
      error: razorpayService.getRazorpayErrorMessage(error),
      stack: error.stack,
    });

    return res.status(error.statusCode || 500).json({
      message: "Unable to process Razorpay webhook",
    });
  }
});

module.exports = router;

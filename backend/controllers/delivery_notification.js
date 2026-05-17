// Express types (only needed if this file defines routes/controllers)
const express = require("express");

// PostgreSQL connection pool
const db = require("../config/db");

// Optional but recommended: async error safety
const asyncHandler = require("express-async-handler");

/**
 * Create notification
 */
async function createNotification({
  userId,
  title,
  body,
  orderId,
  type = "delivery_status",
  priority = "high",
}) {
  await db.query(
    `
    INSERT INTO notifications
    (
      id,
      user_id,
      title,
      body,
      type,
      priority,
      order_id
    )
    VALUES (
      gen_random_uuid(),
      $1,
      $2,
      $3,
      $4,
      $5,
      $6
    )
    `,
    [userId, title, body, type, priority, orderId]
  );
}

/**
 * Notify delivery person
 */
async function notifyDeliveryPerson(
  orderId,
  deliveryPersonId
) {
  await createNotification({
    userId: deliveryPersonId,
    title: "📦 New Delivery Assigned",
    body: `You have been assigned Order #${orderId.slice(
      0,
      8
    )}`,
    orderId,
  });

  await db.query(
    `
    UPDATE orders
    SET delivery_notified = true
    WHERE id = $1
    `,
    [orderId]
  );
}

/**
 * Update delivery status
 */
const updateDeliveryStatus = asyncHandler(
  async (req, res) => {
    const { orderId, status, deliveryCode } =
      req.body;

    await db.query(
      `
      UPDATE orders
      SET
        delivery_status = $1,
        delivery_code = $2
      WHERE id = $3
      `,
      [status, deliveryCode || null, orderId]
    );

    const orderResult = await db.query(
      `
      SELECT user_id
      FROM orders
      WHERE id = $1
      `,
      [orderId]
    );

    if (orderResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: "Order not found",
      });
    }

    const order = orderResult.rows[0];

    let title;
    let body;

    if (status === "sent") {
      title = "Delivery Started";
      body = `Your order is on the way. Code: ${deliveryCode}`;
    } else {
      title = "Order Delivered";
      body =
        "Your order has been delivered successfully";
    }

    await createNotification({
      userId: order.user_id,
      title,
      body,
      orderId,
    });

    res.json({
      success: true,
    });
  }
);

module.exports = {
  createNotification,
  notifyDeliveryPerson,
  updateDeliveryStatus,
};
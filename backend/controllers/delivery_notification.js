// Express types (only needed if this file defines routes/controllers)
const express = require('express');

// MySQL connection (your pooled db instance)
const db = require('../config/db'); 

// Optional but recommended: async error safety
const asyncHandler = require('express-async-handler');

async function createNotification({
  userId,
  title,
  body,
  orderId,
  type = 'delivery_status',
  priority = 'high'
}) {
  await db.execute(`
    INSERT INTO notifications
    (id, user_id, title, body, type, priority, order_id)
    VALUES (UUID(), ?, ?, ?, ?, ?, ?)
  `, [userId, title, body, type, priority, orderId]);
}

async function notifyDeliveryPerson(orderId, deliveryPersonId) {
  await createNotification({
    userId: deliveryPersonId,
    title: '📦 New Delivery Assigned',
    body: `You have been assigned Order #${orderId.slice(0,8)}`,
    orderId
  });

  await db.execute(
    `UPDATE orders SET delivery_notified = 1 WHERE id = ?`,
    [orderId]
  );
}


async function updateDeliveryStatus(req, res) {
  const { orderId, status, deliveryCode } = req.body;

  await db.execute(
    `UPDATE orders SET delivery_status = ?, delivery_code = ? WHERE id = ?`,
    [status, deliveryCode || null, orderId]
  );

  const [[order]] = await db.execute(
    `SELECT user_id FROM orders WHERE id = ?`,
    [orderId]
  );

  let title, body;
  if (status === 'sent') {
    title = 'Delivery Started';
    body = `Your order is on the way. Code: ${deliveryCode}`;
  } else {
    title = 'Order Delivered';
    body = 'Your order has been delivered successfully';
  }

  await createNotification({
    userId: order.user_id,
    title,
    body,
    orderId
  });

  res.json({ success: true });
}

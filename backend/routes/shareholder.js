const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");
const { sendPushNotification } = require("../utils/notification_service");

/**
 * @swagger
 * /api/shareholders/{id}/payment:
 *   post:
 *     summary: Update shareholder payment status
 *     description: Admin updates the payment status of a shareholder.
 *     tags: [Shareholders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Shareholder ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - payment_status
 *             properties:
 *               payment_status:
 *                 type: string
 *                 enum: [pending, paid, unpaid]
 *                 example: paid
 *     responses:
 *       200:
 *         description: Payment updated successfully
 *       400:
 *         description: Invalid payment status
 *       404:
 *         description: Shareholder not found
 *       500:
 *         description: Something went wrong
 */

router.post("/:id/payment", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const paymentStatus = Number(req.body.payment_status);
  const adminId = req.user.id;

  if (![0, 1, 2].includes(paymentStatus)) {
    return res.status(400).json({ message: "Invalid payment status" });
  }

  try {
    const [rows] = await pool.execute(
      `
      SELECT s.id, s.order_id
      FROM shareholder_details s
      JOIN orders o ON o.id = s.order_id
      WHERE s.id = ? AND o.admin_id = ?
      `,
      [id, adminId],
    );

    if (!rows.length) {
      return res.status(404).json({ message: "Shareholder not found" });
    }

    const orderId = rows[0].order_id;

    const [orderRows] = await pool.execute(
      `SELECT user_id FROM orders WHERE id = ?`,
      [orderId],
    );

    if (!orderRows.length) {
      return res.status(404).json({ message: "Order not found" });
    }

    const userId = orderRows[0].user_id;

    await pool.execute(
      `UPDATE shareholder_details
         SET payment_status = ?
       WHERE id = ?`,
      [paymentStatus, id],
    );

    try {
      const [devices] = await pool.execute(
        `SELECT subscription_id 
         FROM user_devices 
         WHERE user_id = ?`,
        [userId],
      );

      const subscriptionIds = devices.map((d) => d.subscription_id);

      let paymentStatusLabel = "Pending";
      if (paymentStatus === 0) paymentStatusLabel = "Paid";
      if (paymentStatus === 1) paymentStatusLabel = "Unpaid";

      if (subscriptionIds.length > 0) {
        await sendPushNotification(
          subscriptionIds,
          "Payment Status Updated",
          `Your shareholder payment status is now '${paymentStatusLabel}'.`,
          {
            type: "SHAREHOLDER_PAYMENT_UPDATED",
            orderId,
            shareholderId: id,
            payment_status: paymentStatus,
          },
        );
      }
    } catch (pushErr) {
      logger.error("Shareholder payment push failed", {
        shareholderId: id,
        error: pushErr.message,
      });
    }

    res.json({ message: "Payment updated successfully" });
  } catch (err) {
    logger.error("Route error", {
      message: err.message,
      stack: err.stack,
      adminId,
    });

    res.status(500).json({ message: "Something went wrong" });
  }
});

router.patch("/:id/status", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  const adminId = req.user.id;

  const shareholderId = Number(id);
  const nextStatus = Number(status);

  if (![1, 2, 3, 4, 5, 6].includes(nextStatus)) {
    return res.status(400).json({ message: "Invalid status value" });
  }

  try {
    const [rows] = await pool.execute(
      `
      SELECT 
        s.id,
        s.order_id,
        s.status,
        s.payment_status,
        s.animal_id,
        s.share_number
      FROM shareholder_details s
      JOIN orders o ON o.id = s.order_id
      WHERE s.id = ? AND o.admin_id = ?
      `,
      [shareholderId, adminId],
    );

    if (!rows.length) {
      return res.status(404).json({ message: "Shareholder not found" });
    }

    const shareholder = rows[0];

    const currentStatus = Number(shareholder.status);
    const paymentStatus = Number(shareholder.payment_status);
    const hasAnimal = !!shareholder.animal_id;
    const hasShareNumber = shareholder.share_number !== null;
    const orderId = shareholder.order_id;

    if (currentStatus === 6) {
      return res.status(400).json({
        message: "Cancelled shareholder status cannot be updated",
      });
    }

    // Step conditions
    switch (nextStatus) {
      case 1: // Qurbani Started
        // Current payment mapping:
        // 0 = paid, 1 = unpaid, 2 = pending
        if (paymentStatus !== 0) {
          return res.status(400).json({
            message: "Payment must be marked as Paid before starting qurbani",
          });
        }

        if (!hasAnimal || !hasShareNumber) {
          return res.status(400).json({
            message: "Animal and share number must be assigned first",
          });
        }

        if (currentStatus !== 0) {
          return res.status(400).json({
            message: "Qurbani can only be started from Not started status",
          });
        }
        break;

      case 2: // Processing
        if (currentStatus !== 1) {
          return res.status(400).json({
            message: "Processing can only be set after Qurbani Started",
          });
        }
        break;

      case 3: // Meat Packaged
        if (![1, 2].includes(currentStatus)) {
          return res.status(400).json({
            message:
              "Meat can only be packaged after Qurbani Started or Processing",
          });
        }
        break;

      case 4: // Sent for delivery
        if (currentStatus !== 3) {
          return res.status(400).json({
            message: "Order can only be sent for delivery after Meat Packaged",
          });
        }
        break;

      case 5: // Delivered
        if (currentStatus !== 4) {
          return res.status(400).json({
            message: "Order can only be delivered after Sent for delivery",
          });
        }
        break;

      case 6: // Cancelled
        if (currentStatus === 5) {
          return res.status(400).json({
            message: "Delivered order cannot be cancelled",
          });
        }
        break;
    }

    // Update shareholder status
    await pool.execute(
      `
      UPDATE shareholder_details
      SET status = ?
      WHERE id = ?
      `,
      [nextStatus, shareholderId],
    );

    // Recalculate parent order status
    const [shareholderRows] = await pool.execute(
      `
      SELECT status
      FROM shareholder_details
      WHERE order_id = ?
      `,
      [orderId],
    );

    const statuses = shareholderRows.map((row) => Number(row.status));

    let nextOrderStatus = 0; // active by default

    if (statuses.length > 0 && statuses.every((s) => s === 5)) {
      nextOrderStatus = 1; // completed
    } else if (statuses.length > 0 && statuses.every((s) => s === 6)) {
      nextOrderStatus = 2; // cancelled
    } else {
      nextOrderStatus = 0; // active
    }

    await pool.execute(
      `
      UPDATE orders
      SET status = ?
      WHERE id = ?
      `,
      [nextOrderStatus, orderId],
    );

    logger.info("Shareholder status updated", {
      shareholderId,
      orderId,
      previousStatus: currentStatus,
      nextStatus,
      nextOrderStatus,
    });

    return res.json({
      message: "Status updated successfully",
      shareholder_status: nextStatus,
      order_status: nextOrderStatus,
    });
  } catch (err) {
    logger.error("Route error", {
      message: err.message,
      stack: err.stack,
      adminId,
      shareholderId,
      requestedStatus: nextStatus,
    });

    return res.status(500).json({ message: "Something went wrong" });
  }
});



/**
 * @swagger
 * /api/shareholders/{id}/assign-animal:
 *   post:
 *     summary: Assign animal to shareholder
 *     description: Assigns an animal to a paid shareholder and generates share number.
 *     tags: [Shareholders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - animal_id
 *             properties:
 *               animal_id:
 *                 type: integer
 *                 example: 5
 *     responses:
 *       200:
 *         description: Animal assigned successfully
 *       400:
 *         description: Payment incomplete or no shares available
 *       404:
 *         description: Shareholder or Animal not found
 *       500:
 *         description: Something went wrong
 */

router.post("/:id/assign-animal", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { animal_id, share_number } = req.body;
  const adminId = req.user.id;

  const shareholderId = Number(id);
  const animalId = Number(animal_id);
  const shareNumber = Number(share_number);

  if (!animalId || !shareNumber) {
    return res.status(400).json({
      message: "animal_id and share_number are required",
    });
  }

  try {
    // Check shareholder
    const [shareholders] = await pool.execute(
      `
      SELECT s.*
      FROM shareholder_details s
      JOIN orders o ON o.id = s.order_id
      WHERE s.id = ? AND o.admin_id = ?
      `,
      [shareholderId, adminId],
    );

    if (!shareholders.length) {
      return res.status(404).json({ message: "Shareholder not found" });
    }

    const shareholder = shareholders[0];

    // payment_status: 0=paid, 1=unpaid, 2=pending
    if (Number(shareholder.payment_status) !== 0) {
      return res.status(400).json({
        message: "Payment must be completed before assigning animal",
      });
    }

    // Check animal
    const [animals] = await pool.execute(
      "SELECT * FROM animals WHERE id = ? AND admin_id = ?",
      [animalId, adminId],
    );

    if (!animals.length) {
      return res.status(404).json({ message: "Animal not found" });
    }

    const animal = animals[0];
    const totalShares = Number(animal.shares || 0);

    // Count already assigned shares for this animal
    const [countResult] = await pool.execute(
      `
      SELECT COUNT(*) AS count
      FROM shareholder_details
      WHERE animal_id = ?
      `,
      [animalId],
    );

    const assignedCount = Number(countResult[0].count || 0);
    const remainingShares = totalShares - assignedCount;

    if (remainingShares <= 0) {
      return res.status(400).json({ message: "No shares available" });
    }

    // Optional: validate requested share number is in range
    if (shareNumber < 1 || shareNumber > totalShares) {
      return res.status(400).json({
        message: `Share number must be between 1 and ${totalShares}`,
      });
    }

    // Check if this share number is already taken for the animal
    const [existingShare] = await pool.execute(
      `
      SELECT id
      FROM shareholder_details
      WHERE animal_id = ? AND share_number = ? AND id != ?
      LIMIT 1
      `,
      [animalId, shareNumber, shareholderId],
    );

    if (existingShare.length) {
      return res.status(400).json({
        message: "This share number is already assigned",
      });
    }

    // Update shareholder
    await pool.execute(
      `
      UPDATE shareholder_details
      SET animal_id = ?, share_number = ?
      WHERE id = ?
      `,
      [animalId, shareNumber, shareholderId],
    );

    // Push notification
    try {
      const orderId = shareholder.order_id;

      const [orderRows] = await pool.execute(
        `SELECT user_id FROM orders WHERE id = ?`,
        [orderId],
      );

      if (orderRows.length) {
        const userId = orderRows[0].user_id;

        const [devices] = await pool.execute(
          `SELECT subscription_id FROM user_devices WHERE user_id = ?`,
          [userId],
        );

        const subscriptionIds = devices.map((d) => d.subscription_id);

        if (subscriptionIds.length > 0) {
          await sendPushNotification(
            subscriptionIds,
            "Animal Assigned",
            "Your Qurbani animal has been successfully assigned.",
            {
              type: "SHAREHOLDER_ANIMAL_ASSIGNED",
              orderId,
              shareholderId,
              animal_id: animalId,
              share_number: shareNumber,
            },
          );
        }
      }
    } catch (pushErr) {
      logger.error("Assign animal push failed", {
        shareholderId,
        error: pushErr.message,
      });
    }

    res.json({ message: "Animal assigned successfully" });
  } catch (err) {
    logger.error("Route error", {
      message: err.message,
      stack: err.stack,
      adminId,
      shareholderId,
      animalId,
    });

    res.status(500).json({ message: "Something went wrong" });
  }
});

/**
 * @swagger
 * /api/shareholders/{id}/schedule:
 *   post:
 *     summary: Schedule Qurbani date and time
 *     description: Sets the Qurbani date/time for a shareholder after animal assignment.
 *     tags: [Shareholders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - qurbani_datetime
 *             properties:
 *               qurbani_datetime:
 *                 type: string
 *                 format: date-time
 *                 example: 2026-06-17T10:30:00Z
 *     responses:
 *       200:
 *         description: Qurbani scheduled successfully
 *       400:
 *         description: Animal not assigned
 *       404:
 *         description: Shareholder not found
 *       500:
 *         description: Something went wrong
 */
router.post("/:id/schedule", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { qurbani_datetime } = req.body;

  try {
    const [rows] = await pool.execute(
      "SELECT animal_id, order_id FROM shareholder_details WHERE id = ?",
      [id],
    );

    if (!rows.length) {
      return res.status(404).json({ message: "Shareholder not found" });
    }

    if (!rows[0].animal_id) {
      return res
        .status(400)
        .json({ message: "Assign animal first before scheduling" });
    }

    await pool.execute(
      `UPDATE shareholder_details
         SET qurbani_datetime = ?, processing_status = 'completed'
         WHERE id = ?`,
      [qurbani_datetime, id],
    );

    // 🔔 =========================
    // 🔔 ADD NOTIFICATION HERE
    // 🔔 =========================
    try {
      const orderId = rows[0].order_id;

      const [orderRows] = await pool.execute(
        `SELECT user_id FROM orders WHERE id = ?`,
        [orderId],
      );

      if (orderRows.length) {
        const userId = orderRows[0].user_id;

        const [devices] = await pool.execute(
          `SELECT subscription_id FROM user_devices WHERE user_id = ?`,
          [userId],
        );

        const subscriptionIds = devices.map((d) => d.subscription_id);

        if (subscriptionIds.length > 0) {
          await sendPushNotification(
            subscriptionIds,
            "🕋 Qurbani Scheduled",
            "Your Qurbani has been successfully completed.",
            {
              type: "SHAREHOLDER_QURBANI_COMPLETED",
              orderId,
              shareholderId: id,
              qurbani_datetime,
            },
          );
        }
      }
    } catch (pushErr) {
      logger.error("Schedule push failed", {
        shareholderId: id,
        error: pushErr.message,
      });
    }

    res.json({ message: "Qurbani scheduled successfully" });
  } catch (err) {
    logger.error("Route error", {
      message: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Something went wrong" });
  }
});

/**
 * @swagger
 * /api/shareholders/{shareholderId}/delivery-status:
 *   post:
 *     summary: Update delivery status
 *     description: Updates delivery status for a shareholder.
 *     tags: [Shareholders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: shareholderId
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - delivery_status
 *             properties:
 *               delivery_status:
 *                 type: string
 *                 enum: [pending, sent, delivered]
 *                 example: delivered
 *     responses:
 *       200:
 *         description: Delivery status updated successfully
 *       400:
 *         description: Invalid delivery status
 *       500:
 *         description: Something went wrong
 */
router.post(
  "/:shareholderId/delivery-status",
  authMiddleware,
  async (req, res) => {
    const { shareholderId } = req.params;
    const { delivery_status } = req.body;

    const allowedStatuses = ["pending", "sent", "delivered"];

    if (!allowedStatuses.includes(delivery_status)) {
      return res.status(400).json({ message: "Invalid delivery status" });
    }

    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      // Update shareholder delivery + processing
      await connection.execute(
        `
        UPDATE shareholder_details
        SET delivery_status = ?,
            processing_status = 'completed'
        WHERE id = ?
        `,
        [delivery_status, shareholderId],
      );

      // Get order_id of this shareholder
      const [shareholderRows] = await connection.execute(
        `SELECT order_id FROM shareholder_details WHERE id = ?`,
        [shareholderId],
      );

      if (!shareholderRows.length) {
        throw new Error("Shareholder not found");
      }

      const orderId = shareholderRows[0].order_id;

      // Check if ALL shareholders delivered
      const [allShareholders] = await connection.execute(
        `
        SELECT delivery_status
        FROM shareholder_details
        WHERE order_id = ?
        `,
        [orderId],
      );

      const allDelivered = allShareholders.every(
        (s) => s.delivery_status === "delivered",
      );

      // Check order payment status + get user_id
      const [orderRows] = await connection.execute(
        `SELECT payment_status, user_id FROM orders WHERE id = ?`,
        [orderId],
      );

      const isPaid = orderRows.length && orderRows[0].payment_status === "paid";

      const userId = orderRows[0]?.user_id;

      let orderCompleted = false;

      // If fully delivered + paid → mark order completed
      if (allDelivered && isPaid) {
        await connection.execute(
          `
          UPDATE orders
          SET status = 'completed'
          WHERE id = ?
          `,
          [orderId],
        );

        orderCompleted = true;

        logger.info("Order auto-completed", { orderId });
      }

      await connection.commit();

      // 🔔 =============================
      // 🔔 SEND PUSH AFTER COMMIT
      // 🔔 =============================
      try {
        if (userId) {
          const [devices] = await pool.execute(
            `SELECT subscription_id FROM user_devices WHERE user_id = ?`,
            [userId],
          );

          const subscriptionIds = devices.map((d) => d.subscription_id);

          if (subscriptionIds.length > 0) {
            // 🚚 Sent for delivery
            if (delivery_status === "sent") {
              await sendPushNotification(
                subscriptionIds,
                "On The Way",
                "Your Qurbani meat has been sent for delivery.",
                {
                  type: "DELIVERY_SENT",
                  orderId,
                  shareholderId,
                },
              );
            }

            // 📦 Delivered
            if (delivery_status === "delivered") {
              await sendPushNotification(
                subscriptionIds,
                "Delivered Successfully",
                "Your Qurbani meat has been delivered.",
                {
                  type: "DELIVERY_COMPLETED",
                  orderId,
                  shareholderId,
                },
              );
            }

            // 🎉 Order completed
            if (orderCompleted) {
              await sendPushNotification(
                subscriptionIds,
                "🎉 Order Completed",
                "Your entire Qurbani order has been completed successfully.",
                {
                  type: "ORDER_COMPLETED",
                  orderId,
                },
              );
            }
          }
        }
      } catch (pushErr) {
        logger.error("Delivery notification failed", {
          shareholderId,
          error: pushErr.message,
        });
      }

      res.json({
        message: "Delivery status updated successfully",
      });
    } catch (err) {
      await connection.rollback();

      logger.error("Delivery status update failed", {
        message: err.message,
        stack: err.stack,
      });

      res.status(500).json({ message: "Something went wrong" });
    } finally {
      connection.release();
    }
  },
);

module.exports = router;

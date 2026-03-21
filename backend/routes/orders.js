/**
 * Orders Routes Module
 *
 * This module handles all order-related API operations in the Qurbani application.
 * It manages the complete order lifecycle including creation, status updates,
 * cancellations, special requests, and payment processing.
 *
 * Routes are organized by functionality:
 * - User Routes: Order details, cancellation, special requests, payment updates
 * - Admin Routes: Order status management and updates (delegated to controllers)
 *
 * Key Features:
 * - Secure order access with user authentication and ownership validation
 * - Admin-only order management with role-based access control
 * - Time-based cancellation policies (24-hour window)
 * - Payment gateway integration for online payments
 * - Comprehensive audit logging for all order operations
 * - Special request system for custom order modifications
 */

const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const { v4: uuidv4 } = require("uuid");
const logger = require("../middleware/logger");

// Mount user order routes from controller
router.use("/", require("../controllers/user_order"));
// Mount admin order routes from controller
// router.use("/admin", require("../controllers/admin_order"));

/**
 * @swagger
 * /api/orders/{orderId}:
 *   get:
 *     summary: Get order details for logged-in user
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: orderId
 *         required: true
 *         schema:
 *           type: string
 *         description: Order ID
 *     responses:
 *       200:
 *         description: Order details fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 order:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                     delivery_status:
 *                       type: string
 *                     payment_status:
 *                       type: string
 *                     processing_status:
 *                       type: string
 *                     created_at:
 *                       type: string
 *                       format: date-time
 *                     admin_name:
 *                       type: string
 *                     admin_phone:
 *                       type: string
 *                     admin_address:
 *                       type: string
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Order not found
 *       500:
 *         description: Something went wrong. Please try again later.
 */

// GET /api/orders/:orderId - Fetch detailed order information for authenticated user
// This endpoint provides comprehensive order details including animal information,
// admin contact details, and current status for order tracking purposes
router.get("/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  console.log("Fetching order details for orderId:", orderId, "userId:", userId);

  try {
    // Fetch Order Basic Info
    const [orders] = await pool.execute(
      `SELECT 
          o.id,
          o.user_id,
          o.admin_id,
          o.delivery_status,
          o.payment_status,
          o.processing_status,
          o.delivery_code,
          o.created_at,
          o.cancelled_at,
          a.name AS admin_name,
          a.phone AS admin_phone,
          a.address AS admin_address
       FROM orders o
       JOIN users a ON o.admin_id = a.id
       WHERE o.id = ? AND o.user_id = ?`,
      [orderId, userId]
    );

    if (!orders.length) {
      return res.status(404).json({ message: "Order not found" });
    }

    const order = orders[0];

    // Fetch Shareholders
    const [shareholders] = await pool.execute(
      `SELECT 
          s.id,
          s.shareholder_name,
          s.guardian_name,
          s.address,
          s.share_number,
          s.payment_status,
          s.processing_status,
          s.delivery_status,
          s.qurbani_datetime,
          an.id AS animal_id,
          an.animal_type,
          an.breed,
          an.price,
          an.age,
          an.barcode,
          an.photo_urls
       FROM shareholder_details s
       LEFT JOIN animals an ON s.animal_id = an.id
       WHERE s.order_id = ?`,
      [orderId]
    );

    console.log("Shareholders fetched:", shareholders);

    // Group Animals (Unique Animals List)
    const animalsMap = {};

    shareholders.forEach((s) => {
      if (s.animal_id) {
        if (!animalsMap[s.animal_id]) {
          animalsMap[s.animal_id] = {
            id: s.animal_id,
            animal_type: s.animal_type,
            breed: s.breed,
            price: s.price,
            age: s.age,
            barcode: s.barcode,
            photo_urls: s.photo_urls,
            qurbani_datetime: s.qurbani_datetime,
          };
        }
      }
    });

    const animals = Object.values(animalsMap);

    // Final Response Structure
    res.json({
      order: {
        ...order,
        animals,
        shareholders,
      },
    });

  } catch (err) {
    console.error("Error retrieving order details:", err);
    res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
});


/**
 * @swagger
 * /api/orders/{orderId}:
 *   put:
 *     summary: Update order status (Admin only)
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: orderId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               processing_status:
 *                 type: string
 *                 enum: [pending, processing, completed, cancelled]
 *               delivery_status:
 *                 type: string
 *                 enum: [pending, sent, delivered, cancelled]
 *               delivery_person_id:
 *                 type: string
 *                 nullable: true
 *     responses:
 *       200:
 *         description: Order updated successfully
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Order not found
 *       500:
 *         description: Something went wrong. Please try again later.
 */

router.put("/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const adminId = req.user.id;

  const { processing_status, delivery_status, delivery_person_id } = req.body;

  try {
    const [admins] = await pool.execute(`SELECT role FROM users WHERE id = ?`, [
      adminId,
    ]);

    if (!admins.length || admins[0].role !== "admin") {
      logger.warn("Unauthorized order update attempt", { adminId, orderId });
      return res.status(403).json({ message: "Access denied" });
    }

    const [orders] = await pool.execute(
      `SELECT id FROM orders WHERE id = ? AND admin_id = ?`,
      [orderId, adminId],
    );

    if (!orders.length) {
      logger.warn("Admin tried to update non-owned order", {
        adminId,
        orderId,
      });
      return res.status(404).json({ message: "Order not found" });
    }

    await pool.execute(
      `UPDATE orders
       SET processing_status = ?, delivery_status = ?, delivery_person_id = ?
       WHERE id = ?`,
      [processing_status, delivery_status, delivery_person_id || null, orderId],
    );

    logger.info("Order updated by admin", {
      adminId,
      orderId,
      processing_status,
      delivery_status,
    });

    res.json({ message: "Order updated successfully" });
  } catch (err) {
    logger.error("Error updating order", {
      adminId,
      orderId,
      error: err.message,
    });
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

/**
 * @swagger
 * /api/orders/{orderId}/cancel:
 *   put:
 *     summary: Cancel an order (User only)
 *     description: User can cancel order within 24 hours if not delivered.
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: orderId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Order cancelled successfully
 *       400:
 *         description: Cannot cancel this order
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Order not found
 *       500:
 *         description: Something went wrong. Please try again later.
 */

// PUT /api/orders/:orderId/cancel - User order cancellation with time-based restrictions
// Allows users to cancel their orders within a 24-hour window if not yet delivered
// Implements business rules for cancellation eligibility and updates all order statuses
router.put("/:orderId/cancel", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    const [orders] = await pool.execute(
      `SELECT id, user_id, status, created_at FROM orders WHERE id = ? AND user_id = ?`,
      [orderId, userId]
    );

    if (!orders.length) {
      logger.warn(
        "Order cancellation attempt on non-existent or non-owned order",
        {
          userId,
          orderId,
          reason: "Order not found or doesn't belong to user",
        }
      );
      return res.status(404).json({ message: "Order not found" });
    }

    const order = orders[0];

    const isCancelled = Number(order.status) === 2; // orders.status: 2=cancelled

    const timeSinceOrder = Date.now() - new Date(order.created_at).getTime();
    const within24Hours = timeSinceOrder < 24 * 60 * 60 * 1000;

    const canCancel = within24Hours && !isCancelled;

    if (!canCancel) {
      logger.warn(
        "Invalid order cancellation attempt - business rules violation",
        {
          userId,
          orderId,
          orderStatus: order.status,
          timeSinceOrder: Math.floor(timeSinceOrder / (1000 * 60 * 60)),
          within24Hours,
          isCancelled,
          reason: !within24Hours
            ? "Outside 24-hour window"
            : "Order already cancelled",
        }
      );
      return res.status(400).json({ message: "Cannot cancel this order" });
    }

    await pool.execute(
      `
      UPDATE orders
      SET status = 2
      WHERE id = ? AND user_id = ?
      `,
      [orderId, userId]
    );

    // Optional: also cancel all shareholders under this order
    await pool.execute(
      `
      UPDATE shareholder_details
      SET status = 6
      WHERE order_id = ?
      `,
      [orderId]
    );

    // Push notification
    try {
      const [devices] = await pool.execute(
        `SELECT subscription_id FROM user_devices WHERE user_id = ?`,
        [userId]
      );

      const subscriptionIds = devices
        .map((d) => d.subscription_id)
        .filter(Boolean);

      if (subscriptionIds.length > 0) {
        const title = `Qurbani Order #${orderId}`;
        const message = `Your order #${orderId} has been cancelled successfully.`;

        await sendPushNotification(subscriptionIds, title, message, {
          type: "ORDER_CANCELLED",
          orderId: Number(orderId),
          status: 2,
        });
      }
    } catch (pushErr) {
      logger.error("Order cancellation push failed", {
        userId,
        orderId,
        error: pushErr.message,
      });
    }

    logger.info("Order successfully cancelled by user", {
      userId,
      orderId,
      orderAge: Math.floor(timeSinceOrder / (1000 * 60)),
      cancellationType: "user_initiated",
      previousStatus: order.status,
    });

    res.json({ message: "Order cancelled successfully" });
  } catch (err) {
    logger.error("Error processing order cancellation", {
      userId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

/**
 * @swagger
 * /api/orders/{orderId}/special-request:
 *   post:
 *     summary: Submit a special request for an order
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: orderId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - title
 *               - description
 *             properties:
 *               title:
 *                 type: string
 *               description:
 *                 type: string
 *     responses:
 *       201:
 *         description: Special request submitted successfully
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Order not found
 *       500:
 *         description: Something went wrong. Please try again later.
 */

// POST /api/orders/:orderId/special-request - Submit special request
router.post("/:orderId/special-request", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;
  const { title, description } = req.body;

  // Basic validation
  if (!title || !description) {
    logger.warn("Special request validation failed", {
      userId,
      orderId,
    });
    return res
      .status(400)
      .json({ message: "Title and description are required" });
  }

  try {
    // Check if order exists and belongs to user
    const [orders] = await pool.execute(
      `SELECT id FROM orders WHERE id = ? AND user_id = ?`,
      [orderId, userId],
    );

    if (orders.length === 0) {
      logger.warn("Special request for non-owned or missing order", {
        userId,
        orderId,
      });
      return res.status(404).json({ message: "Order not found" });
    }

    const requestId = uuidv4();

    await pool.execute(
      `INSERT INTO special_requests 
       (id, order_id, user_id, title, description, status)
       VALUES (?, ?, ?, ?, ?, 'pending')`,
      [requestId, orderId, userId, title, description],
    );

    logger.info("Special request submitted", {
      requestId,
      orderId,
      userId,
    });

    res.status(201).json({ message: "Special request submitted" });
  } catch (err) {
    logger.error("Error submitting special request", {
      userId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

/**
 * @swagger
 * /api/orders/{orderId}/payment-success:
 *   put:
 *     summary: Update order payment status after online payment
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: orderId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - paymentId
 *             properties:
 *               paymentId:
 *                 type: string
 *     responses:
 *       200:
 *         description: Payment updated successfully
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Something went wrong. Please try again later.
 */

// PUT /api/orders/:orderId/payment-success - Update order payment status after online payment completion
// Called by payment gateway webhook or frontend after successful payment processing
// Marks order as paid and stores payment gateway reference ID for reconciliation
// Critical for order fulfillment workflow and financial tracking
router.put("/:orderId/payment-success", authMiddleware, async (req, res) => {
  // Extract order ID from URL parameters
  const { orderId } = req.params;
  // Extract payment gateway ID from request body
  const { paymentId } = req.body;
  // Get authenticated user's ID for security validation
  const userId = req.user.id;

  try {
    // Step 1: Update order payment status in database
    // Sets payment_status to 'paid' and stores payment gateway reference
    // Security: WHERE clause ensures users can only update their own orders
    await pool.execute(
      `UPDATE orders
       SET payment_status='paid', payment_id=?
       WHERE id=? AND user_id=?`,
      [paymentId, orderId, userId],
    );

    // Step 2: Log successful payment update for audit trail and financial tracking
    logger.info("Order payment status updated to paid successfully", {
      userId,
      orderId,
      paymentId,
      paymentMethod: "online_payment",
      updateType: "payment_success_callback",
      previousStatus: "pending/unpaid", // Assumed based on context
      newStatus: "paid",
    });

    // Return success response to payment gateway or frontend
    res.json({ message: "Payment status updated successfully" });
  } catch (err) {
    // Log error with comprehensive context for payment reconciliation debugging
    logger.error("Error updating order payment status", {
      userId,
      orderId,
      paymentId,
      error: err.message,
      stack: err.stack,
      impact:
        "Payment may not be properly recorded - manual reconciliation required",
    });
    // Return generic error message to client
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

router.put("/:orderId/schedule", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { qurbani_time } = req.body;

  if (!qurbani_time) {
    return res.status(400).json({ message: "Qurbani time required" });
  }

  const conn = await pool.getConnection();

  try {
    await conn.beginTransaction();
    console.log("schedle updatebegins");
    // Update animal_details
    const [animalResult] = await conn.execute(
      `UPDATE animal_details
         SET qurbani_datetime = ?
         WHERE order_id = ?`,
      [qurbani_time, orderId],
    );
    console.log("schedle ends", animalResult);

    if (animalResult.affectedRows === 0) {
      await conn.rollback();
      return res.status(404).json({
        message: "Animal details not found for this order",
      });
    }

    //  Update order status
    await conn.execute(
      `UPDATE orders
         SET processing_status = 'confirmed'
         WHERE id = ?`,
      [orderId],
    );

    await conn.commit();

    res.json({
      message: "Qurbani scheduled successfully",
      processing_status: "confirmed",
    });
  } catch (err) {
    await conn.rollback();
    logger.error("Schedule update failed", err);
    res.status(500).json({ message: "Failed to update schedule" });
  } finally {
    conn.release();
  }
});

module.exports = router;

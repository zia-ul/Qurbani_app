const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const { v4: uuidv4 } = require("uuid");

router.use("/", require("../controllers/user_order"));
router.use("/admin", require("../controllers/admin_order"));

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
 *         description: Internal server error
 */


// GET /api/orders/:orderId - Fetch order details for user
router.get("/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    const [orders] = await pool.execute(
      `SELECT o.id, o.user_id, o.admin_id, o.delivery_status, o.payment_status,
              o.processing_status, o.created_at, o.cancelled_at,
              p.title, p.image_url, p.shares, p.price, p.barcode,
              a.name AS admin_name, a.phone AS admin_phone, a.address AS admin_address
       FROM orders o
       JOIN animals p ON o.animal_id = p.id
       JOIN users a ON o.admin_id = a.id
       WHERE o.id = ? AND o.user_id = ?`,
      [orderId, userId]
    );

    if (!orders.length) {
      logger.warn("Order not found for user", { userId, orderId });
      return res.status(404).json({ message: "Order not found" });
    }

    logger.info("Order fetched successfully", { userId, orderId });
    res.json({ order: orders[0] });
  } catch (err) {
    logger.error("Error fetching order", {
      userId,
      orderId,
      error: err.message,
      stack: err.stack,
    });
    res.status(500).json({ message: "Internal server error" });
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
 *         description: Internal server error
 */

router.put("/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const adminId = req.user.id;

  const { processing_status, delivery_status, delivery_person_id } = req.body;

  try {
    const [admins] = await pool.execute(
      `SELECT role FROM users WHERE id = ?`,
      [adminId]
    );

    if (!admins.length || admins[0].role !== "admin") {
      logger.warn("Unauthorized order update attempt", { adminId, orderId });
      return res.status(403).json({ message: "Access denied" });
    }

    const [orders] = await pool.execute(
      `SELECT id FROM orders WHERE id = ? AND admin_id = ?`,
      [orderId, adminId]
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
      [processing_status, delivery_status, delivery_person_id || null, orderId]
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
    res.status(500).json({ message: "Internal server error" });
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
 *         description: Internal server error
 */


// PUT /api/orders/:orderId/cancel - Cancel order
router.put("/:orderId/cancel", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    const [orders] = await pool.execute(
      `SELECT delivery_status, created_at FROM orders WHERE id = ? AND user_id = ?`,
      [orderId, userId]
    );

    if (!orders.length) {
      logger.warn("Cancel attempt on non-existent order", { userId, orderId });
      return res.status(404).json({ message: "Order not found" });
    }

    const order = orders[0];
    const isDelivered = order.delivery_status === "delivered";
    const isCancelled = order.delivery_status === "cancelled";
    const canCancel =
      Date.now() - new Date(order.created_at).getTime() < 24 * 60 * 60 * 1000 &&
      !isDelivered &&
      !isCancelled;

    if (!canCancel) {
      logger.warn("Invalid cancel attempt", { userId, orderId });
      return res.status(400).json({ message: "Cannot cancel this order" });
    }

    await pool.execute(
      `UPDATE orders
       SET delivery_status='cancelled',
           payment_status='cancelled',
           processing_status='cancelled',
           cancelled_at=NOW()
       WHERE id=?`,
      [orderId]
    );

    logger.info("Order cancelled by user", { userId, orderId });
    res.json({ message: "Order cancelled" });
  } catch (err) {
    logger.error("Error cancelling order", {
      userId,
      orderId,
      error: err.message,
    });
    res.status(500).json({ message: "Internal server error" });
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
 *         description: Internal server error
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
    return res.status(400).json({ message: "Title and description are required" });
  }

  try {
    // Check if order exists and belongs to user
    const [orders] = await pool.execute(
      `SELECT id FROM orders WHERE id = ? AND user_id = ?`,
      [orderId, userId]
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
      [requestId, orderId, userId, title, description]
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

    res.status(500).json({ message: "Internal server error" });
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
 *         description: Internal server error
 */


// PUT /api/orders/:orderId/payment-success - Update payment status after online payment
router.put("/:orderId/payment-success", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { paymentId } = req.body;
  const userId = req.user.id;

  try {
    await pool.execute(
      `UPDATE orders
       SET payment_status='paid', payment_id=?
       WHERE id=? AND user_id=?`,
      [paymentId, orderId, userId]
    );

    logger.info("Payment marked as paid", {
      userId,
      orderId,
      paymentId,
    });

    res.json({ message: "Payment updated" });
  } catch (err) {
    logger.error("Payment update failed", {
      userId,
      orderId,
      error: err.message,
    });
    res.status(500).json({ message: "Internal server error" });
  }
});


module.exports = router;

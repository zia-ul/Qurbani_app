const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");

router.use("/", require("../controllers/user_order"));
router.use("/admin", require("../controllers/admin_order"));

// GET /api/orders/:orderId - Fetch order details for user
router.get("/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    const [orders] = await pool.execute(
      `SELECT o.id, o.user_id, o.admin_id, o.delivery_status, o.payment_status, o.processing_status, o.created_at, o.cancelled_at,
              p.title, p.image_url, p.shares, p.price, p.barcode,
              a.name AS admin_name, a.phone AS admin_phone, a.address AS admin_address
       FROM orders o
       JOIN animals p ON o.animal_id = p.id
       JOIN users a ON o.admin_id = a.id
       WHERE o.id = ? AND o.user_id = ?`,
      [orderId, userId]
    );
    if (orders.length === 0) {
      return res.status(404).json({ message: "Order not found" });
    }
    res.json({ order: orders[0] });
  } catch (err) {
    console.error("Error fetching order:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// PUT /api/orders/:orderId/cancel - Cancel order
router.put("/:orderId/cancel", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    const [orders] = await pool.execute(
      `SELECT delivery_status, created_at FROM orders WHERE id = ? AND user_id = ?`,
      [orderId, userId]
    );
    if (orders.length === 0) {
      return res.status(404).json({ message: "Order not found" });
    }

    const order = orders[0];
    const isDelivered = order.delivery_status?.toLowerCase() === 'delivered';
    const isCancelled = order.delivery_status?.toLowerCase() === 'cancelled';
    const orderDate = new Date(order.created_at);
    const canCancel = Date.now() - orderDate.getTime() < 24 * 60 * 60 * 1000 && !isDelivered && !isCancelled;

    if (!canCancel) {
      return res.status(400).json({ message: "Cannot cancel this order" });
    }

    await pool.execute(
      `UPDATE orders SET delivery_status = 'cancelled', payment_status = 'cancelled', processing_status = 'cancelled', cancelled_at = NOW() WHERE id = ?`,
      [orderId]
    );
    res.json({ message: "Order cancelled" });
  } catch (err) {
    console.error("Error cancelling order:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// POST /api/orders/:orderId/special-request - Submit special request
router.post("/:orderId/special-request", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;
  const { title, description } = req.body;

  try {
    // Check if order exists and belongs to user
    const [orders] = await pool.execute(
      `SELECT id FROM orders WHERE id = ? AND user_id = ?`,
      [orderId, userId]
    );
    if (orders.length === 0) {
      return res.status(404).json({ message: "Order not found" });
    }

    const requestId = uuidv4();
    await pool.execute(
      `INSERT INTO special_requests (id, order_id, user_id, title, description, status) VALUES (?, ?, ?, ?, ?, 'pending')`,
      [requestId, orderId, userId, title, description]
    );
    res.status(201).json({ message: "Special request submitted" });
  } catch (err) {
    console.error("Error submitting special request:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// PUT /api/orders/:orderId/payment-success - Update payment status after online payment
router.put("/:orderId/payment-success", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { paymentId } = req.body;
  const userId = req.user.id;

  try {
    await pool.execute(
      `UPDATE orders SET payment_status = 'paid', payment_id = ? WHERE id = ? AND user_id = ?`,
      [paymentId, orderId, userId]
    );
    res.json({ message: "Payment updated" });
  } catch (err) {
    console.error("Error updating payment:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// GET /api/admin/notifications - Fetch pending notifications for admin
router.get("/notifications", authMiddleware, async (req, res) => {
  const adminId = req.user.id;

  try {
    // Assuming a 'notifications' table with columns: id, type, order_id, admin_id, is_notified, created_at
    const [notifications] = await pool.execute(
      `SELECT id, type, order_id FROM notifications WHERE admin_id = ? AND is_notified = FALSE ORDER BY created_at DESC`,
      [adminId]
    );

    res.json({ notifications });
  } catch (err) {
    console.error("Error fetching notifications:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// PUT /api/admin/notifications/:id/mark-notified - Mark notification as notified
router.put("/notifications/:id/mark-notified", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const adminId = req.user.id;

  try {
    await pool.execute(
      `UPDATE notifications SET is_notified = TRUE WHERE id = ? AND admin_id = ?`,
      [id, adminId]
    );
    res.json({ message: "Notification marked as notified" });
  } catch (err) {
    console.error("Error updating notification:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});


module.exports = router;

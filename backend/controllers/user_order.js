const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const auth = require("../middleware/authmiddleware");
const { v4: uuidv4 } = require("uuid");

// GET /api/orders/my
router.get("/my", auth, async (req, res) => {
  const userId = req.user.id;

  const [orders] = await pool.execute(
    `SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC`,
    [userId]
  );

  res.json({ orders });
});

// GET /api/orders/:orderId
router.get("/:orderId", auth, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  const [rows] = await pool.execute(
    `SELECT * FROM orders WHERE id = ? AND user_id = ?`,
    [orderId, userId]
  );

  if (!rows.length) {
    return res.status(404).json({ message: "Order not found" });
  }

  res.json({ order: rows[0] });
});

// POST /api/orders - Place order
router.post("/", auth, async (req, res) => {
  const { adminId, paymentMethod } = req.body;
  const userId = req.user.id;

  try {
    const orderId = uuidv4();

    // payment status logic
    const paymentStatus = paymentMethod === "Cash" ? "unpaid" : "pending";

    await pool.execute(
      `
      INSERT INTO orders 
        (id, user_id, admin_id, status, payment_status, processing_status, delivery_status, created_at)
      VALUES 
        (?, ?, ?, 'active', ?, 'pending', 'pending', NOW())
      `,
      [orderId, userId, adminId, paymentStatus]
    );

    res.status(201).json({
      message: "Order placed successfully",
      orderId,
      status: "active",
      paymentStatus,
    });
  } catch (err) {
    console.error("Error placing order:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

module.exports = router;

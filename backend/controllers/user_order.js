const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const auth = require("../middleware/authmiddleware");

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

// POST /api/orders
router.post("/", auth, async (req, res) => {
  // create order logic
});

module.exports = router;

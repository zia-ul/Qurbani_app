// routes/orders.js
const express = require("express");
const router = express.Router();
const { v4: uuidv4 } = require("uuid");
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");

// POST /api/orders
router.post("/", authMiddleware, async (req, res) => {
  const userId = req.user.id; // FROM JWT
  const { adminId, paymentMethod, shareholders } = req.body;

  if (!adminId || !paymentMethod || !Array.isArray(shareholders) || shareholders.length === 0) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const orderId = uuidv4();
    const totalShares = shareholders.length;

    // Insert order
    await connection.execute(
      `INSERT INTO orders (id, user_id, admin_id, payment_method, total_shares)
       VALUES (?, ?, ?, ?, ?)`,
      [orderId, userId, adminId, paymentMethod, totalShares]
    );

    // Insert shareholders
    const shareholderValues = shareholders.map((s) => [
      uuidv4(),
      orderId,
      s.name,
      s.guardianName,
      s.qurbaniDay || "Day 1",
    ]);

    await connection.query(
      `INSERT INTO shareholders (id, order_id, name, guardian_name, qurbani_day)
       VALUES ?`,
      [shareholderValues]
    );

    await connection.commit();
    res.status(201).json({ message: "Order placed successfully", orderId });
  } catch (err) {
    await connection.rollback();
    console.error("Error placing order:", err);
    res.status(500).json({ message: "Internal server error" });
  } finally {
    connection.release();
  }
});

module.exports = router;

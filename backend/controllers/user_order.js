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
  const { adminId, paymentMethod, shareholders } = req.body;
  const userId = req.user.id;

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const orderId = uuidv4();
    const totalShares = shareholders.length;

    // 1️⃣ Insert order
    await connection.execute(
      `
      INSERT INTO orders
      (id, user_id, admin_id, payment_method, total_shares)
      VALUES (?, ?, ?, ?, ?)
      `,
      [orderId, userId, adminId, paymentMethod, totalShares]
    );

    // 2️⃣ Insert shareholders
    for (const s of shareholders) {
      await connection.execute(
        `
        INSERT INTO order_shareholders
        (id, order_id, animal_id, shareholder_name, guardian_name, qurbani_day, price)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        `,
        [
          uuidv4(),
          orderId,
          s.animalId,
          s.name,
          s.guardianName,
          s.qurbaniDay,
          s.price,
        ]
      );
    }

    await connection.commit();

    res.status(201).json({
      message: "Order placed successfully",
      orderId,
    });
  } catch (err) {
    await connection.rollback();
    console.error(err);
    res.status(500).json({ message: "Failed to place order" });
  } finally {
    connection.release();
  }
});


module.exports = router;

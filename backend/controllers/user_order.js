const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const auth = require("../middleware/authmiddleware");
const logger = require("../middlewares/logger");

const { v4: uuidv4 } = require("uuid");


// GET /api/orders/my
router.get("/my", auth, async (req, res) => {
  const userId = req.user.id;

  try {
    const [orders] = await pool.execute(
      `SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC`,
      [userId]
    );

    logger.info("Fetched user orders", { userId, count: orders.length });

    res.json({ orders });
  } catch (err) {
    logger.error("Failed to fetch user orders", {
      userId,
      error: err.message,
      stack: err.stack
    });
    res.status(500).json({ message: "Server error" });
  }
});


// GET /api/orders/:orderId
router.get("/:orderId", auth, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    const [orderRows] = await pool.execute(
      `
      SELECT o.*, 
             u.name AS admin_name, 
             u.phone AS admin_phone, 
             u.address AS admin_address
      FROM orders o
      JOIN users u ON o.admin_id = u.id
      WHERE o.id = ? AND o.user_id = ?
      `,
      [orderId, userId]
    );

    if (!orderRows.length) {
      logger.warn("Order not found or unauthorized access", {
        orderId,
        userId
      });

      return res.status(404).json({ message: "Order not found" });
    }

    const order = orderRows[0];

    const [animalRows] = await pool.execute(
      `
      SELECT a.id, a.animal_type, a.breed, a.price, a.age, a.weight, a.shares,
             s.shareholder_name, s.guardian_name, s.qurbani_day
      FROM order_shareholders s
      JOIN animals a ON s.animal_id = a.id
      WHERE s.order_id = ?
      `,
      [orderId]
    );

    order.animals = animalRows;

    logger.info("Fetched order details", {
      orderId,
      userId,
      animalsCount: animalRows.length
    });

    res.json({ order });
  } catch (err) {
    logger.error("Failed to fetch order details", {
      orderId,
      userId,
      error: err.message,
      stack: err.stack
    });
    res.status(500).json({ message: "Server error" });
  }
});




// POST /api/orders - Place order
router.post("/", auth, async (req, res) => {
  const { adminId, paymentMethod, shareholders } = req.body;
  const userId = req.user.id;

  if (!adminId || !paymentMethod) {
    logger.warn("Order validation failed", { userId });
    return res.status(400).json({ message: "Admin ID and payment method are required" });
  }

  if (!Array.isArray(shareholders) || shareholders.length === 0) {
    logger.warn("Order has no shareholders", { userId });
    return res.status(400).json({ message: "At least one shareholder is required" });
  }

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    const orderId = uuidv4();

    await connection.execute(
      `
      INSERT INTO orders
      (id, user_id, admin_id, payment_method, total_shares)
      VALUES (?, ?, ?, ?, ?)
      `,
      [orderId, userId, adminId, paymentMethod, shareholders.length]
    );

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

    logger.info("Order placed successfully", {
      orderId,
      userId,
      adminId,
      shares: shareholders.length
    });

    res.status(201).json({
      message: "Order placed successfully",
      orderId,
    });
  } catch (err) {
    await connection.rollback();

    logger.error("Order placement failed", {
      userId,
      adminId,
      error: err.message,
      stack: err.stack
    });

    res.status(500).json({ message: "Failed to place order" });
  } finally {
    connection.release();
  }
});


module.exports = router;

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

  try {
    // Fetch order + admin info
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
      return res.status(404).json({ message: "Order not found" });
    }

    const order = orderRows[0];

    // Fetch only the animals for this order via shareholders
    const [animalRows] = await pool.execute(
      `
      SELECT a.id, a.animal_type, a.breed, a.price, a.age, a.weight, a.shares, a.delivery_type, a.is_available,
             s.shareholder_name AS shareholder_name, s.guardian_name, s.qurbani_day
      FROM order_shareholders s
      JOIN animals a ON s.animal_id = a.id
      WHERE s.order_id = ?
      `,
      [orderId]
    );

    console.log(animalRows);

    // Attach animals to order
    order.animals = animalRows;

    res.json({ order });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error", error: err.message });
  }
});



// POST /api/orders - Place order
router.post("/", auth, async (req, res) => {
  const { adminId, paymentMethod, shareholders } = req.body;
  const userId = req.user.id;

  // Validate request body
  if (!adminId || !paymentMethod) {
    return res.status(400).json({ message: "Admin ID and payment method are required" });
  }

  if (!Array.isArray(shareholders) || shareholders.length === 0) {
    return res.status(400).json({ message: "At least one shareholder is required" });
  }

  // Validate each shareholder
  // for (const [index, s] of shareholders.entries()) {
  //   if (!s.animalId) {
  //     return res.status(400).json({ message: `Shareholder at index ${index} is missing animalId` });
  //   }
  //   if (!s.name) {
  //     return res.status(400).json({ message: `Shareholder at index ${index} is missing name` });
  //   }
  //   if (!s.guardianName) {
  //     return res.status(400).json({ message: `Shareholder at index ${index} is missing guardianName` });
  //   }
  //   if (!s.qurbaniDay) {
  //     return res.status(400).json({ message: `Shareholder at index ${index} is missing qurbaniDay` });
  //   }
  // }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const orderId = uuidv4();
    const totalShares = shareholders.length;

    // Insert order
    await connection.execute(
      `
      INSERT INTO orders
      (id, user_id, admin_id, payment_method, total_shares)
      VALUES (?, ?, ?, ?, ?)
      `,
      [orderId, userId, adminId, paymentMethod, totalShares]
    );

    // Insert shareholders
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

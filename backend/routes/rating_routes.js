const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const auth = require("../middleware/authmiddleware");

/**
 * GET /api/ratings/:orderId/:userId
 * Fetch ratings + related order info for a user
 */
router.get("/:orderId/:userId", auth, async (req, res) => {
  const { orderId, userId } = req.params;

  if (req.user.id !== userId) {
    return res.status(403).json({ message: "Unauthorized" });
  }

  try {
    // Fetch order + admin + delivery person
    const [orders] = await pool.execute(
      `
      SELECT 
        o.id AS order_id,
        o.admin_id,
        a.name AS admin_name,
        o.delivery_person_id,
        d.name AS delivery_person_name
      FROM orders o
      JOIN users a ON a.id = o.admin_id
      LEFT JOIN users d ON d.id = o.delivery_person_id
      WHERE o.id = ? AND o.user_id = ?
      `,
      [orderId, userId]
    );

    if (!orders.length) {
      return res.status(404).json({ message: "Order not found" });
    }

    // Fetch existing ratings
    const [ratings] = await pool.execute(
      `
      SELECT admin_id, admin_rating, delivery_rating, feedback
      FROM ratings
      WHERE order_id = ? AND user_id = ?
      `,
      [orderId, userId]
    );

    const ratingsMap = {};
    ratings.forEach((r) => {
      ratingsMap[r.admin_id] = {
        adminRating: r.admin_rating,
        deliveryRating: r.delivery_rating,
        feedback: r.feedback,
      };
    });

    res.json({
      order: orders[0],
      ratings: ratingsMap,
      submitted: ratings.length > 0,
    });
  } catch (err) {
    console.error("Error fetching ratings:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

/**
 * POST /api/ratings
 * Submit or update ratings
 */
router.post("/", auth, async (req, res) => {
  const { orderId, userId, ratings } = req.body;

  if (req.user.id !== userId) {
    return res.status(403).json({ message: "Unauthorized" });
  }

  if (!orderId || !Array.isArray(ratings) || ratings.length === 0) {
    return res.status(400).json({ message: "Invalid ratings data" });
  }

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    for (const r of ratings) {
      const {
        adminId,
        adminRating,
        deliveryRating,
        feedback,
      } = r;

      if (
        !adminId ||
        adminRating < 1 ||
        adminRating > 5 ||
        deliveryRating < 1 ||
        deliveryRating > 5
      ) {
        throw new Error("Invalid rating values");
      }

      await connection.execute(
        `
        INSERT INTO ratings 
          (order_id, user_id, admin_id, admin_rating, delivery_rating, feedback)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
          admin_rating = VALUES(admin_rating),
          delivery_rating = VALUES(delivery_rating),
          feedback = VALUES(feedback)
        `,
        [
          orderId,
          userId,
          adminId,
          adminRating,
          deliveryRating,
          feedback || null,
        ]
      );
    }

    await connection.commit();
    res.json({ message: "Ratings submitted successfully" });
  } catch (err) {
    await connection.rollback();
    console.error("Error submitting ratings:", err);
    res.status(500).json({ message: "Internal server error" });
  } finally {
    connection.release();
  }
});

module.exports = router;

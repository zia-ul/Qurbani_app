// routes/admin.js
const express = require("express");
const db = require("../config/db"); // Your MySQL connection
const authMiddleware = require("../middleware/authmiddleware"); // JWT verification middleware

const router = express.Router();

/**
 * GET /api/auth/admin/:id
 * Requires JWT in Authorization header
 */
router.get("/:id", authMiddleware, async (req, res) => {
  const adminId = req.params.id;

  try {
    // Fetch admin user
    const [users] = await db.query(
      `SELECT id, name, email, phone, address, city
       FROM users 
       WHERE id = ? AND role = 'admin'`,
      [adminId]
    );

    if (users.length === 0) {
      return res.status(404).json({ message: "Admin not found" });
    }

    const admin = users[0];

    // Fetch admin order stats
    const [orders] = await db.query(
      `SELECT status FROM orders WHERE admin_id = ?`,
      [adminId]
    );

    const totalOrders = orders.length;
    const completedOrders = orders.filter(o => o.status === "completed").length;

    // Calculate average rating (if you have a ratings table)
    // const [ratings] = await db.query(
    //   `SELECT AVG(rating) AS avgRating FROM ratings WHERE admin_id = ?`,
    //   [adminId]
    // );

    // const avgRating = ratings[0].avgRating || 0;

    // Return data
    return res.json({
      ...admin,
      totalOrders,
      completedOrders,
      // averageRating: parseFloat(avgRating.toFixed(1)),
    });
  } catch (err) {
    console.error("Admin profile error:", err);
    return res.status(500).json({ message: "Server error" });
  }
});

module.exports = router;

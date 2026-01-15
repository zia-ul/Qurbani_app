const express = require("express");
const { fetchVerifiedAdmins } = require("../controllers/marketplaceAdmin");
const authMiddleware = require("../middleware/authmiddleware");
const pool = require("../config/db");

const router = express.Router();

/**
 * PUBLIC – Fetch verified admins
 */
router.get("/verified", fetchVerifiedAdmins);

// GET /api/admin/dashboard-stats - Fetch quick stats for admin dashboard
router.get("/dashboard-stats", authMiddleware, async (req, res) => {
  const adminId = req.user.id; // From JWT payload

  try {
    // Query for animal count (animals added by this admin)
    const [animalResult] = await pool.execute(
      "SELECT COUNT(*) AS count FROM animals WHERE admin_id = ?",
      [adminId]
    );
    const animalCount = animalResult[0].count;

    // Query for order count (orders placed for this admin's animals)
    const [orderResult] = await pool.execute(
      "SELECT COUNT(*) AS count FROM orders WHERE admin_id = ?",
      [adminId]
    );
    const orderCount = orderResult[0].count;

    // Query for request count (requests linked to this admin's orders via join)
    const [requestResult] = await pool.execute(
      "SELECT COUNT(*) AS count FROM requests r JOIN orders o ON r.order_id = o.id WHERE o.admin_id = ?",
      [adminId]
    );
    const requestCount = requestResult[0].count;

    // Return stats as JSON
    res.json({
      animals: animalCount,
      orders: orderCount,
      requests: requestCount,
    });
  } catch (err) {
    console.error("Error fetching dashboard stats:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// GET /api/admins/:adminId/animals - Get Animals for Admin
router.get("/:adminId/animals", authMiddleware, async (req, res) => {
  const { adminId } = req.params;

  try {
    const [animals] = await pool.execute(
      `SELECT 
        id,
        animal_type,
        breed,
        price,
        payment_methods,
        delivery_type,
        delivery_fee,
        delivery_threshold
        FROM animals
        WHERE admin_id = ?
        `,
      [adminId]
    );
    res.json({ animals });
  } catch (err) {
    console.error("Error fetching animals:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

module.exports = router;

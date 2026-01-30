/**
 * @swagger
 * /api/auth/admin/{id}:
 *   get:
 *     summary: Get admin profile and order statistics
 *     description: >
 *       Returns admin user details along with total and completed order statistics.
 *       Requires a valid JWT token in the Authorization header.
 *     tags:
 *       - Admin
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Admin user ID
 *     responses:
 *       200:
 *         description: Admin profile fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 id:
 *                   type: integer
 *                   example: 1
 *                 name:
 *                   type: string
 *                   example: Admin User
 *                 email:
 *                   type: string
 *                   example: admin@example.com
 *                 phone:
 *                   type: string
 *                   example: "+923001234567"
 *                 address:
 *                   type: string
 *                   example: Main Street
 *                 city:
 *                   type: string
 *                   example: Lahore
 *                 totalOrders:
 *                   type: integer
 *                   example: 25
 *                 completedOrders:
 *                   type: integer
 *                   example: 18
 *       401:
 *         description: Unauthorized (missing or invalid JWT)
 *       404:
 *         description: Admin not found
 *       500:
 *         description: Something went wrong. Please try again later.
 */


// routes/admin.js
const express = require("express");
const db = require("../config/db"); // Your MySQL connection
const authMiddleware = require("../middleware/authmiddleware"); // JWT verification middleware
const logger = require("../middleware/logger"); // Logger middleware
const router = express.Router();

/**
 * GET /api/auth/admin/:id
 * Requires JWT in Authorization header
 */
router.get("/:id", authMiddleware, async (req, res) => {
  const adminId = req.params.id;

  logger.info("Fetching admin profile", {
    adminId,
  });

  try {
    // Fetch admin user
    const [users] = await db.query(
      `SELECT id, name, email, phone, address, description, city, order_deadline, photo_url
       FROM users 
       WHERE id = ? AND role = 'admin'`,
      [adminId]
    );

    if (users.length === 0) {
      logger.warn("Admin not found", {
        adminId,
      });

      return res.status(404).json({ message: "Admin not found" });
    }

    const admin = users[0];

    // Fetch admin order stats
    const [orders] = await db.query(
      `SELECT status FROM orders WHERE admin_id = ?`,
      [adminId]
    );

    const totalOrders = orders.length;
    const completedOrders = orders.filter(
      (o) => o.status === "completed"
    ).length;

    logger.info("Admin profile fetched successfully", {
      adminId,
      totalOrders,
      completedOrders,
    });

    return res.json({
      ...admin,
      totalOrders,
      completedOrders,
    });
  } catch (err) {
    logger.error("Error fetching admin profile", {
      adminId,
      error: err.message,
      stack: err.stack,
    });

    return res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});


module.exports = router;

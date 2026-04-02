

// routes/admin.js
const express = require("express");
const db = require("../config/db"); // Your MySQL connection
const authMiddleware = require("../middleware/authmiddleware"); // JWT verification middleware
const logger = require("../middleware/logger"); // Logger middleware
const router = express.Router();


/**
 * @swagger
 * /api/auth/admin/{id}:
 *   get:
 *     summary: Get admin profile and order statistics
 *     description: >
 *       Fetches an admin user's profile details along with total
 *       and completed order statistics. Requires a valid JWT token
 *       in the Authorization header.
 *     tags:
 *       - Admin
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: Admin user ID (UUID)
 *     responses:
 *       200:
 *         description: Admin profile fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 id:
 *                   type: string
 *                   format: uuid
 *                   example: "573b7cb3-a55e-40e8-a3c8-40369b5e83ec"
 *                 name:
 *                   type: string
 *                   example: "Admin User"
 *                 email:
 *                   type: string
 *                   example: "admin@example.com"
 *                 phone:
 *                   type: string
 *                   example: "+923001234567"
 *                 address:
 *                   type: string
 *                   example: "Main Street"
 *                 description:
 *                   type: string
 *                   example: "Platform administrator"
 *                 city:
 *                   type: string
 *                   example: "Lahore"
 *                 order_deadline:
 *                   type: string
 *                   example: "18:00"
 *                 photo_url:
 *                   type: string
 *                   example: "https://example.com/photo.jpg"
 *                 totalOrders:
 *                   type: integer
 *                   example: 25
 *                 completedOrders:
 *                   type: integer
 *                   example: 18
 *                 averageRating:
 *                   type: number
 *                   example: 4.7
 *                 totalRatings:
 *                   type: integer
 *                   example: 23
 *       401:
 *         description: Unauthorized – missing or invalid JWT token
 *       404:
 *         description: Admin not found
 *       500:
 *         description: Something went wrong. Please try again later.
 */


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

    const [[ratingSummary]] = await db.query(
      `
      SELECT
        COUNT(*) AS totalRatings,
        COALESCE(ROUND(AVG(admin_rating), 1), 0) AS averageRating
      FROM ratings
      WHERE admin_id = ?
      `,
      [adminId],
    );

    const totalOrders = orders.length;
    const completedOrders = orders.filter(
      (o) => {
        const normalizedStatus = String(o.status ?? "").trim().toLowerCase();
        return normalizedStatus === "completed" || normalizedStatus === "1";
      }
    ).length;
    const totalRatings = Number(ratingSummary?.totalRatings || 0);
    const averageRating = Number(ratingSummary?.averageRating || 0);

    logger.info("Admin profile fetched successfully", {
      adminId,
      totalOrders,
      completedOrders,
      totalRatings,
      averageRating,
    });

    return res.json({
      ...admin,
      totalOrders,
      completedOrders,
      totalRatings,
      averageRating,
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

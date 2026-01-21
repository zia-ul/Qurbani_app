const express = require("express");
const { fetchVerifiedAdmins } = require("../controllers/marketplaceAdmin");
const authMiddleware = require("../middleware/authmiddleware");
const pool = require("../config/db");
const logger = require("../middleware/logger");

const router = express.Router();

/**
 * @swagger
 * /api/admin/verified:
 *   get:
 *     summary: Fetch verified admins for marketplace
 *     description: Public endpoint to list all verified admins available in marketplace.
 *     tags: [Marketplace]
 *     responses:
 *       200:
 *         description: List of verified admins
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   id:
 *                     type: string
 *                   name:
 *                     type: string
 *                   email:
 *                     type: string
 *                   phone:
 *                     type: string
 *                   city:
 *                     type: string
 *       500:
 *         description: Something went wrong. Please try again later.
 */


/**
 * PUBLIC – Fetch verified admins
 */
router.get("/verified", fetchVerifiedAdmins);


/**
 * @swagger
 * /api/admin/dashboard-stats:
 *   get:
 *     summary: Get admin dashboard statistics
 *     description: Returns quick statistics for admin dashboard including animals, orders, and requests.
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Dashboard statistics fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 animals:
 *                   type: integer
 *                   example: 12
 *                 orders:
 *                   type: integer
 *                   example: 45
 *                 requests:
 *                   type: integer
 *                   example: 7
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Something went wrong. Please try again later.
 */


// GET /api/admin/dashboard-stats - Fetch quick stats for admin dashboard
router.get("/dashboard-stats", authMiddleware, async (req, res) => {
  const adminId = req.user.id;

  logger.info("Fetching admin dashboard stats", { adminId });

  try {
    const [animalResult] = await pool.execute(
      "SELECT COUNT(*) AS count FROM animals WHERE admin_id = ?",
      [adminId]
    );

    const [orderResult] = await pool.execute(
      "SELECT COUNT(*) AS count FROM orders WHERE admin_id = ?",
      [adminId]
    );

    const [requestResult] = await pool.execute(
      `SELECT COUNT(*) AS count 
       FROM requests r 
       JOIN orders o ON r.order_id = o.id 
       WHERE o.admin_id = ?`,
      [adminId]
    );

    const stats = {
      animals: animalResult[0].count,
      orders: orderResult[0].count,
      requests: requestResult[0].count,
    };

    logger.info("Admin dashboard stats fetched", {
      adminId,
      ...stats,
    });

    res.json(stats);
  } catch (err) {
    logger.error("Error fetching admin dashboard stats", {
      adminId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});


/**
 * @swagger
 * /api/admin/{adminId}/animals:
 *   get:
 *     summary: Get animals for a specific admin
 *     description: Fetch all animals listed by a specific admin.
 *     tags: [Marketplace]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: adminId
 *         required: true
 *         schema:
 *           type: string
 *         description: Admin ID
 *     responses:
 *       200:
 *         description: Animals fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 animals:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       animal_type:
 *                         type: string
 *                         example: Sheep
 *                       breed:
 *                         type: string
 *                         example: Kajli
 *                       price:
 *                         type: number
 *                         example: 35000
 *                       delivery_type:
 *                         type: string
 *                         enum: [Free, Paid]
 *                       delivery_fee:
 *                         type: number
 *                         example: 500
 *                       delivery_threshold:
 *                         type: number
 *                         example: 10000
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Something went wrong. Please try again later.
 */


// GET /api/admins/:adminId/animals - Get Animals for Admin
router.get("/:adminId/animals", authMiddleware, async (req, res) => {
  const { adminId } = req.params;

  logger.info("Fetching animals for admin", { adminId });

  try {
    const [animals] = await pool.execute(
      `
      SELECT 
        id,
        animal_type,
        breed,
        price,
        delivery_type,
        delivery_fee,
        delivery_threshold
      FROM animals
      WHERE admin_id = ?
      `,
      [adminId]
    );

    logger.info("Animals fetched for admin", {
      adminId,
      count: animals.length,
    });

    res.json({ animals });
  } catch (err) {
    logger.error("Error fetching animals for admin", {
      adminId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});


module.exports = router;

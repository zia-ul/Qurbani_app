const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const auth = require("../middleware/authmiddleware");

/**
 * @swagger
 * /api/ratings/{orderId}/{userId}:
 *   get:
 *     summary: Fetch ratings and order info for a user
 *     description: Returns order details along with existing ratings for admin and delivery person. User can only access their own data.
 *     tags: [Ratings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: orderId
 *         required: true
 *         description: Order ID
 *         schema:
 *           type: string
 *       - in: path
 *         name: userId
 *         required: true
 *         description: Logged-in user ID
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Ratings and order info fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 order:
 *                   type: object
 *                   properties:
 *                     order_id:
 *                       type: string
 *                     admin_id:
 *                       type: string
 *                     admin_name:
 *                       type: string
 *                     delivery_person_id:
 *                       type: string
 *                       nullable: true
 *                     delivery_person_name:
 *                       type: string
 *                       nullable: true
 *                 ratings:
 *                   type: object
 *                   additionalProperties:
 *                     type: object
 *                     properties:
 *                       adminRating:
 *                         type: integer
 *                         example: 5
 *                       deliveryRating:
 *                         type: integer
 *                         example: 4
 *                       feedback:
 *                         type: string
 *                         example: "Very good service"
 *                 submitted:
 *                   type: boolean
 *                   example: true
 *       403:
 *         description: Unauthorized access
 *       404:
 *         description: Order not found
 *       500:
 *         description: Internal server error
 */


/**
 * GET /api/ratings/:orderId/:userId
 * Fetch ratings + related order info for a user
 */
router.get("/:orderId/:userId", auth, async (req, res) => {
  const { orderId, userId } = req.params;

  if (req.user.id !== userId) {
    logger.warn("Unauthorized ratings fetch attempt", {
      authUserId: req.user.id,
      userId,
      orderId,
    });
    return res.status(403).json({ message: "Unauthorized" });
  }

  try {
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
      logger.warn("Order not found for ratings fetch", {
        orderId,
        userId,
      });
      return res.status(404).json({ message: "Order not found" });
    }

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

    logger.info("Fetched ratings for order", {
      userId,
      orderId,
      ratingsCount: ratings.length,
    });

    res.json({
      order: orders[0],
      ratings: ratingsMap,
      submitted: ratings.length > 0,
    });
  } catch (err) {
    logger.error("Error fetching ratings", {
      userId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Internal server error" });
  }
});




/**
 * @swagger
 * /api/ratings:
 *   post:
 *     summary: Submit or update ratings for an order
 *     description: Allows a user to submit or update ratings for admin and delivery person for an order.
 *     tags: [Ratings]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - orderId
 *               - userId
 *               - ratings
 *             properties:
 *               orderId:
 *                 type: string
 *               userId:
 *                 type: string
 *               ratings:
 *                 type: array
 *                 items:
 *                   type: object
 *                   required:
 *                     - adminId
 *                     - adminRating
 *                     - deliveryRating
 *                   properties:
 *                     adminId:
 *                       type: string
 *                     adminRating:
 *                       type: integer
 *                       minimum: 1
 *                       maximum: 5
 *                       example: 5
 *                     deliveryRating:
 *                       type: integer
 *                       minimum: 1
 *                       maximum: 5
 *                       example: 4
 *                     feedback:
 *                       type: string
 *                       example: "Excellent handling and timely delivery"
 *     responses:
 *       200:
 *         description: Ratings submitted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Ratings submitted successfully
 *       400:
 *         description: Invalid ratings data
 *       403:
 *         description: Unauthorized
 *       500:
 *         description: Internal server error
 */


/**
 * POST /api/ratings
 * Submit or update ratings
 */
router.post("/", auth, async (req, res) => {
  const { orderId, userId, ratings } = req.body;

  if (req.user.id !== userId) {
    logger.warn("Unauthorized ratings submission attempt", {
      authUserId: req.user.id,
      userId,
      orderId,
    });
    return res.status(403).json({ message: "Unauthorized" });
  }

  if (!orderId || !Array.isArray(ratings) || ratings.length === 0) {
    logger.warn("Invalid ratings payload", {
      userId,
      orderId,
    });
    return res.status(400).json({ message: "Invalid ratings data" });
  }

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    for (const r of ratings) {
      const { adminId, adminRating, deliveryRating, feedback } = r;

      if (
        !adminId ||
        adminRating < 1 ||
        adminRating > 5 ||
        deliveryRating < 1 ||
        deliveryRating > 5
      ) {
        logger.warn("Invalid rating values detected", {
          userId,
          orderId,
          adminId,
          adminRating,
          deliveryRating,
        });
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

    logger.info("Ratings submitted successfully", {
      userId,
      orderId,
      ratingsCount: ratings.length,
    });

    res.json({ message: "Ratings submitted successfully" });
  } catch (err) {
    await connection.rollback();

    logger.error("Error submitting ratings", {
      userId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Internal server error" });
  } finally {
    connection.release();
  }
});

module.exports = router;

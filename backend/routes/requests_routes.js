const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const auth = require("../middleware/authmiddleware");

/**
 * @swagger
 * /api/requests:
 *   post:
 *     summary: Submit a special request for an order
 *     description: Allows a user to submit a special request related to an order.
 *     tags: [Requests]
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
 *               - title
 *               - description
 *             properties:
 *               orderId:
 *                 type: string
 *               userId:
 *                 type: string
 *               title:
 *                 type: string
 *                 example: "Change delivery time"
 *               description:
 *                 type: string
 *                 example: "Please deliver after 6 PM"
 *     responses:
 *       201:
 *         description: Request submitted successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Request submitted successfully
 *       400:
 *         description: Missing required fields
 *       403:
 *         description: Unauthorized
 *       500:
 *         description: Internal server error
 */


/**
 * POST /api/requests
 * Submit a special request for an order
 */
router.post("/", auth, async (req, res) => {
  const { orderId, userId, title, description } = req.body;

  if (req.user.id !== userId) {
    logger.warn("Unauthorized request submission attempt", {
      authUserId: req.user.id,
      bodyUserId: userId,
      orderId,
    });
    return res.status(403).json({ message: "Unauthorized" });
  }

  if (!orderId || !title || !description) {
    logger.warn("Missing fields in request submission", {
      userId,
      orderId,
    });
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    await pool.execute(
      `
      INSERT INTO requests (order_id, user_id, title, description, status)
      VALUES (?, ?, ?, ?, 'Pending')
      `,
      [orderId, userId, title, description]
    );

    logger.info("Special request submitted", {
      userId,
      orderId,
      title,
    });

    res.status(201).json({ message: "Request submitted successfully" });
  } catch (err) {
    logger.error("Error submitting special request", {
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
 * /api/requests/{orderId}/{userId}:
 *   get:
 *     summary: Get all special requests for a user and order
 *     description: Fetches all special requests submitted by a user for a specific order.
 *     tags: [Requests]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: orderId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Requests fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 requests:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       title:
 *                         type: string
 *                       description:
 *                         type: string
 *                       status:
 *                         type: string
 *                         example: Pending
 *                       created_at:
 *                         type: string
 *                         format: date-time
 *       403:
 *         description: Unauthorized
 *       500:
 *         description: Internal server error
 */


/**
 * GET /api/requests/:orderId/:userId
 * Fetch all requests for a user & order
 */
router.get("/:orderId/:userId", auth, async (req, res) => {
  const { orderId, userId } = req.params;

  if (req.user.id !== userId) {
    logger.warn("Unauthorized request fetch attempt", {
      authUserId: req.user.id,
      userId,
      orderId,
    });
    return res.status(403).json({ message: "Unauthorized" });
  }

  try {
    const [requests] = await pool.execute(
      `
      SELECT id, title, description, status, created_at
      FROM requests
      WHERE order_id = ? AND user_id = ?
      ORDER BY created_at DESC
      `,
      [orderId, userId]
    );

    logger.info("Fetched user special requests", {
      userId,
      orderId,
      count: requests.length,
    });

    res.json({ requests });
  } catch (err) {
    logger.error("Error fetching user requests", {
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
 * /api/requests/admin:
 *   get:
 *     summary: Fetch all special requests for admin
 *     description: Admin can fetch all special requests with optional status filtering.
 *     tags: [Admin Requests]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *           enum: [All, Pending, Replied, Closed]
 *         description: Filter requests by status
 *     responses:
 *       200:
 *         description: Requests fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 requests:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       order_id:
 *                         type: string
 *                       user_id:
 *                         type: string
 *                       title:
 *                         type: string
 *                       description:
 *                         type: string
 *                       status:
 *                         type: string
 *                       reply_message:
 *                         type: string
 *                         nullable: true
 *                       created_at:
 *                         type: string
 *                         format: date-time
 *                       user_name:
 *                         type: string
 *                       user_email:
 *                         type: string
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Internal server error
 */


/**
 * GET /api/requests/admin
 * Fetch all special requests for admin (with optional status filter)
 * Query params: ?status=All|Pending|Replied|Closed
 */
router.get("/admin", auth, async (req, res) => {
  const adminId = req.user.id;
  const { status } = req.query;

  try {
    let query = `
      SELECT 
        r.id, r.order_id, r.user_id, r.title, r.description, r.status, r.created_at,
        r.reply_message, r.replied_at, r.closed_at,
        u.name as user_name, u.email as user_email
      FROM requests r
      JOIN users u ON r.user_id = u.id
      ORDER BY r.created_at DESC
    `;
    let params = [];

    if (status && status !== "All") {
      query = query.replace("ORDER BY", "WHERE r.status = ? ORDER BY");
      params = [status];
    }

    const [requests] = await pool.execute(query, params);

    logger.info("Admin fetched special requests", {
      adminId,
      status: status || "All",
      count: requests.length,
    });

    res.json({ requests });
  } catch (err) {
    logger.error("Error fetching admin requests", {
      adminId,
      status,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Internal server error" });
  }
});



/**
 * @swagger
 * /api/requests/admin/{requestId}:
 *   put:
 *     summary: Update a special request (reply or close)
 *     description: Admin can reply to or close a special request.
 *     tags: [Admin Requests]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: requestId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - action
 *             properties:
 *               action:
 *                 type: string
 *                 enum: [reply, close]
 *               replyMessage:
 *                 type: string
 *                 example: "Your request has been approved"
 *     responses:
 *       200:
 *         description: Request updated successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Request updated successfully
 *       400:
 *         description: Missing required fields
 *       500:
 *         description: Internal server error
 */


/**
 * PUT /api/requests/admin/:requestId
 * Update a request (reply or close) for admin
 */
router.put("/admin/:requestId", auth, async (req, res) => {
  const { requestId } = req.params;
  const { replyMessage, action } = req.body;
  const adminId = req.user.id;

  if (!action || (action === "reply" && !replyMessage)) {
    logger.warn("Invalid admin request update payload", {
      adminId,
      requestId,
      action,
    });
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    let updateFields = {};

    if (action === "reply") {
      updateFields = {
        reply_message: replyMessage,
        status: "Replied",
        replied_at: new Date(),
      };
    } else if (action === "close") {
      updateFields = {
        status: "Closed",
        closed_at: new Date(),
      };
    }

    const setClause = Object.keys(updateFields)
      .map((key) => `${key} = ?`)
      .join(", ");
    const values = [...Object.values(updateFields), requestId];

    await pool.execute(
      `UPDATE requests SET ${setClause} WHERE id = ?`,
      values
    );

    logger.info("Admin updated special request", {
      adminId,
      requestId,
      action,
    });

    res.json({ message: "Request updated successfully" });
  } catch (err) {
    logger.error("Error updating special request", {
      adminId,
      requestId,
      action,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Internal server error" });
  }
});


module.exports = router;
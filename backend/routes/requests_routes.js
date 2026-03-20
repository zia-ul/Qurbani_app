/**
 * Special Requests Routes Module
 *
 * This module handles all special request operations in the Qurbani application.
 * Special requests allow users to submit custom requests related to their orders,
 * such as delivery time changes, special handling instructions, or other modifications.
 *
 * Routes are organized by functionality:
 * - User Routes: Submit and view personal requests
 * - Admin Routes: Manage and respond to all requests
 *
 * Key Features:
 * - Secure request submission with user authentication
 * - Admin dashboard for request management
 * - Status tracking (Pending, Replied, Closed)
 * - Audit logging for all operations
 */

const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const auth = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");
const { sendPushNotification } = require("../utils/notification_service");

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
 *         description: Something went wrong. Please try again later.
 */


/**
 * ===========================================
 * USER REQUEST ROUTES
 * ===========================================
 * Routes for users to submit and view their special requests
 */

/**
 * POST /api/requests
 * Submit a special request for an order
 * Allows authenticated users to create custom requests related to their orders
 * such as delivery time changes, special handling, or other modifications
 */
router.post("/", auth, async (req, res) => {
  // Extract request data from the authenticated user's input
  const { orderId, userId, title, description } = req.body;

  // Security check: Ensure the authenticated user can only submit requests for themselves
  if (req.user.id !== userId) {
    logger.warn("Unauthorized request submission attempt", {
      authUserId: req.user.id,
      bodyUserId: userId,
      orderId,
    });
    return res.status(403).json({ message: "Unauthorized" });
  }

  // Validation: Ensure all required fields are provided
  if (!orderId || !title || !description) {
    logger.warn("Missing fields in request submission", {
      userId,
      orderId,
      hasTitle: !!title,
      hasDescription: !!description,
    });
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    // Insert the new request into the database
    await pool.execute(
      `
      INSERT INTO requests (order_id, user_id, title, description, status)
      VALUES (?, ?, ?, ?, 'Pending')
      `,
      [orderId, userId, title, description]
    );

    // ================================
    // 🔔 SEND NOTIFICATION TO ADMINS
    // ================================

    // 1️⃣ Get all admin IDs
    const [admins] = await pool.execute(
      `SELECT id FROM users WHERE role = 'admin'`
    );

    const adminIds = admins.map((admin) => admin.id);

    let adminSubscriptionIds = [];

    if (adminIds.length > 0) {
      // 2️⃣ Get all subscription IDs from user_devices
      const [devices] = await pool.query(
        `SELECT subscription_id 
         FROM user_devices 
         WHERE user_id IN (?) 
         AND subscription_id IS NOT NULL`,
        [adminIds]
      );

      adminSubscriptionIds = devices.map(
        (device) => device.subscription_id
      );
    }

    // 3️⃣ Send push notification
    if (adminSubscriptionIds.length > 0) {
      await sendPushNotification(
        adminSubscriptionIds,
        "New Special Request 📩",
        `Order #${orderId} has a new request: ${title}`,
        {
          type: "special_request",
          orderId,
          userId,
        }
      );
    }

    // ================================

    // Log successful request submission for audit trail
    logger.info("Special request submitted successfully", {
      userId,
      orderId,
      title,
      requestType: "special_request",
    });

    // Return success response to the client
    res.status(201).json({ message: "Request submitted successfully" });

  } catch (err) {
    logger.error("Error submitting special request", {
      userId,
      orderId,
      title,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({
      message: "Something went wrong. Please try again later."
    });
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
 *         description: Something went wrong. Please try again later.
 */


/**
 * GET /api/requests/:orderId/:userId
 * Fetch all special requests for a specific user and order combination
 * Allows users to view their own requests for a particular order
 * Results are ordered by creation date (newest first) for better UX
 */
router.get("/:orderId/:userId", auth, async (req, res) => {
  // Extract order and user IDs from URL parameters
  const { orderId, userId } = req.params;

  // Security check: Users can only view their own requests
  // This prevents unauthorized access to other users' private requests
  if (req.user.id !== userId) {
    logger.warn("Unauthorized request fetch attempt", {
      authUserId: req.user.id,      // Who is actually logged in
      requestedUserId: userId,      // Whose requests are being requested
      orderId,
    });
    return res.status(403).json({ message: "Unauthorized" });
  }

  try {
    // Query the database for all requests matching the user and order
    // Only return basic request information (excluding admin-only fields like replies)
    const [requests] = await pool.execute(
      `
      SELECT id, title, description, status, created_at
      FROM requests
      WHERE order_id = ? AND user_id = ?
      ORDER BY created_at DESC
      `,
      [orderId, userId]
    );

    // Log successful request fetch for audit trail
    logger.info("User successfully fetched their special requests", {
      userId,
      orderId,
      requestCount: requests.length,
      requestStatuses: requests.map(r => r.status), // For monitoring request status distribution
    });

    // Return the requests array to the client
    res.json({ requests });
  } catch (err) {
    // Log error with full context for debugging
    logger.error("Error fetching user special requests", {
      userId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    // Return generic error message to client
    res.status(500).json({ message: "Something went wrong. Please try again later." });
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
 *         description: Something went wrong. Please try again later.
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

    res.status(500).json({ message: "Something went wrong. Please try again later." });
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
 *         description: Something went wrong. Please try again later.
 */


/**
 * PUT /api/requests/admin/:requestId
 * Admin endpoint to update special requests by replying or closing them
 * Supports two actions: 'reply' (provide response message) and 'close' (mark as resolved)
 * Critical for maintaining communication flow between admins and users
 * Updates request status and timestamps accordingly
 */
router.put("/admin/:requestId", auth, async (req, res) => {
  const { requestId } = req.params;
  const { replyMessage, action } = req.body;
  const adminId = req.user.id;

  if (!action || (action === "reply" && !replyMessage)) {
    logger.warn("Invalid admin request update attempt - missing required fields", {
      adminId,
      requestId,
      action,
      hasReplyMessage: !!replyMessage,
    });
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    let updateFields = {};

    if (action === "reply") {
      updateFields = {
        reply_message: replyMessage,
        status: 1, // Replied
        replied_at: new Date(),
      };
    } else if (action === "close") {
      updateFields = {
        status: 2, // Closed
        closed_at: new Date(),
      };
    } else {
      return res.status(400).json({ message: "Invalid action" });
    }

    const setClause = Object.keys(updateFields)
      .map((key) => `${key} = ?`)
      .join(", ");

    const values = [...Object.values(updateFields), requestId];

    await pool.execute(
      `UPDATE requests SET ${setClause} WHERE id = ?`,
      values
    );

    // 🔔 SEND PUSH TO USER
    try {
      const [requestRows] = await pool.execute(
        `SELECT user_id, order_id, title FROM requests WHERE id = ?`,
        [requestId]
      );

      if (requestRows.length) {
        const { user_id, order_id, title } = requestRows[0];

        const [devices] = await pool.execute(
          `SELECT subscription_id FROM user_devices WHERE user_id = ?`,
          [user_id]
        );

        const subscriptionIds = devices.map((d) => d.subscription_id);

        if (subscriptionIds.length > 0) {
          if (action === "reply") {
            await sendPushNotification(
              subscriptionIds,
              `Request #${requestId} Replied`,
              `Your request #${requestId} "${title}" has been replied to.`,
              {
                type: "REQUEST_REPLIED",
                requestId: Number(requestId),
                requestTitle: title,
                orderId: order_id,
              }
            );
          }

          if (action === "close") {
            await sendPushNotification(
              subscriptionIds,
              `Request #${requestId} Closed`,
              `Your request #${requestId} "${title}" has been closed.`,
              {
                type: "REQUEST_CLOSED",
                requestId: Number(requestId),
                requestTitle: title,
                orderId: order_id,
              }
            );
          }
        }
      }
    } catch (pushErr) {
      logger.error("Request notification failed", {
        requestId,
        action,
        error: pushErr.message,
      });
    }

    logger.info("Admin successfully updated special request", {
      adminId,
      requestId,
      action,
      newStatus: updateFields.status,
      hasReplyMessage: action === "reply",
    });

    res.json({ message: "Request updated successfully" });
  } catch (err) {
    logger.error("Error updating special request by admin", {
      adminId,
      requestId,
      action,
      attemptedReplyMessage: action === "reply" ? replyMessage : null,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
});

module.exports = router;
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

async function getRequestsTableConfig(connection) {
  const [columns] = await connection.query(
    `
    SELECT
      COLUMN_NAME AS column_name,
      DATA_TYPE AS data_type,
      COLUMN_TYPE AS column_type,
      EXTRA AS extra
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'requests'
      AND COLUMN_NAME IN ('id', 'status')
    `,
  );

  const idColumn = columns.find((column) => column.column_name === "id");
  const statusColumn = columns.find(
    (column) => column.column_name === "status",
  );

  const idDataType = (idColumn?.data_type || "").toLowerCase();
  const idExtra = (idColumn?.extra || "").toLowerCase();
  const statusDataType = (statusColumn?.data_type || "").toLowerCase();

  return {
    requiresExplicitId: Boolean(idColumn) && !idExtra.includes("auto_increment"),
    idIsNumeric: [
      "tinyint",
      "smallint",
      "mediumint",
      "int",
      "bigint",
      "decimal",
      "numeric",
    ].includes(idDataType),
    statusIsNumeric: [
      "tinyint",
      "smallint",
      "mediumint",
      "int",
      "bigint",
      "decimal",
      "numeric",
    ].includes(statusDataType),
  };
}

async function buildRequestInsertPayload(
  connection,
  orderId,
  userId,
  title,
  description,
) {
  const tableConfig = await getRequestsTableConfig(connection);
  const columns = [];
  const values = [];

  if (tableConfig.requiresExplicitId) {
    columns.push("id");

    if (tableConfig.idIsNumeric) {
      const [[row]] = await connection.query(
        `SELECT COALESCE(MAX(id), 0) AS maxId FROM requests`,
      );
      values.push(Number(row?.maxId || 0) + 1);
    } else {
      values.push(`${Date.now()}${Math.floor(1000 + Math.random() * 9000)}`);
    }
  }

  columns.push("order_id", "user_id", "title", "description", "status");
  values.push(
    orderId,
    userId,
    title,
    description,
    tableConfig.statusIsNumeric ? 0 : "Pending",
  );

  return { columns, values, tableConfig };
}

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
  const { orderId, userId, title, description } = req.body;
  const authUserId = req.user.id;
  const normalizedUserId = (userId ?? authUserId).toString().trim();
  const normalizedOrderId = orderId?.toString().trim();
  const normalizedTitle = title?.toString().trim();
  const normalizedDescription = description?.toString().trim();

  // Security check: Ensure the authenticated user can only submit requests for themselves
  if (authUserId !== normalizedUserId) {
    logger.warn("Unauthorized request submission attempt", {
      authUserId,
      bodyUserId: normalizedUserId,
      orderId: normalizedOrderId,
    });
    return res.status(403).json({ message: "Unauthorized" });
  }

  // Validation: Ensure all required fields are provided
  if (!normalizedOrderId || !normalizedTitle || !normalizedDescription) {
    logger.warn("Missing fields in request submission", {
      userId: normalizedUserId,
      orderId: normalizedOrderId,
      hasTitle: !!normalizedTitle,
      hasDescription: !!normalizedDescription,
    });
    return res.status(400).json({ message: "Missing required fields" });
  }

  const connection = await pool.getConnection();

  try {
    const [orderRows] = await connection.execute(
      `
      SELECT id, admin_id
      FROM orders
      WHERE id = ? AND user_id = ?
      LIMIT 1
      `,
      [normalizedOrderId, normalizedUserId]
    );

    if (!orderRows.length) {
      logger.warn("Special request submission blocked for inaccessible order", {
        userId: normalizedUserId,
        orderId: normalizedOrderId,
      });
      return res.status(404).json({
        message: "Order not found for this user",
      });
    }

    const adminId = orderRows[0].admin_id;
    const requestInsert = await buildRequestInsertPayload(
      connection,
      normalizedOrderId,
      normalizedUserId,
      normalizedTitle,
      normalizedDescription,
    );

    await connection.execute(
      `
      INSERT INTO requests (${requestInsert.columns.join(", ")})
      VALUES (${requestInsert.columns.map(() => "?").join(", ")})
      `,
      requestInsert.values,
    );

    // ================================
    // 🔔 SEND NOTIFICATION TO ADMINS
    // ================================

    // 1️⃣ Get all admin IDs
    const admins = adminId ? [{ id: adminId }] : [];

    const adminIds = admins.map((admin) => admin.id);

    let adminSubscriptionIds = [];

    if (adminIds.length > 0) {
      // 2️⃣ Get all subscription IDs from user_devices
      const [devices] = await connection.query(
        `SELECT subscription_id 
         FROM user_devices 
         WHERE user_id IN (?) 
         AND subscription_id IS NOT NULL`,
        [adminIds]
      );

      adminSubscriptionIds = devices
        .map((device) => device.subscription_id)
        .filter(Boolean);
    }

    // 3️⃣ Send push notification
    if (adminSubscriptionIds.length > 0) {
      await sendPushNotification(
        adminSubscriptionIds,
        "New Special Request 📩",
        `Order #${normalizedOrderId} has a new request: ${normalizedTitle}`,
        {
          type: "special_request",
          orderId: normalizedOrderId,
          userId: normalizedUserId,
        }
      );
    }

    // ================================

    // Log successful request submission for audit trail
    logger.info("Special request submitted successfully", {
      userId: normalizedUserId,
      orderId: normalizedOrderId,
      title: normalizedTitle,
      requestInsertConfig: requestInsert.tableConfig,
      requestType: "special_request",
    });

    // Return success response to the client
    res.status(201).json({ message: "Request submitted successfully" });

  } catch (err) {
    const statusCode = err.code === "ER_DUP_ENTRY" ? 409 : 500;

    logger.error("Error submitting special request", {
      userId: normalizedUserId,
      orderId: normalizedOrderId,
      title: normalizedTitle,
      error: err.message,
      code: err.code,
      stack: err.stack,
    });

    res.status(statusCode).json({
      message:
        statusCode === 409
          ? "This special request already exists."
          : "Something went wrong. Please try again later."
    });
  } finally {
    connection.release();
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
const adminRequestStatusMap = {
  Pending: 0,
  Replied: 1,
  Closed: 2,
};

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
      JOIN orders o ON r.order_id = o.id
      JOIN users u ON r.user_id = u.id
      WHERE o.admin_id = ?
      ORDER BY r.created_at DESC
    `;
    let params = [adminId];

    if (status && status !== "All") {
      const normalizedStatus = Number.isNaN(Number(status))
        ? adminRequestStatusMap[status]
        : Number(status);

      if (!Number.isInteger(normalizedStatus)) {
        return res.status(400).json({ message: "Invalid status filter" });
      }

      query = query.replace("ORDER BY", "AND r.status = ? ORDER BY");
      params = [adminId, normalizedStatus];
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

    const [requestRows] = await pool.execute(
      `
      SELECT r.id, r.user_id, r.order_id, r.title
      FROM requests r
      JOIN orders o ON r.order_id = o.id
      WHERE r.id = ?
        AND o.admin_id = ?
      LIMIT 1
      `,
      [requestId, adminId]
    );

    if (!requestRows.length) {
      logger.warn("Admin tried to update an inaccessible request", {
        adminId,
        requestId,
      });
      return res.status(404).json({ message: "Request not found" });
    }

    const values = [...Object.values(updateFields), requestId];

    await pool.execute(
      `UPDATE requests SET ${setClause} WHERE id = ?`,
      values
    );

    // 🔔 SEND PUSH TO USER
    try {
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

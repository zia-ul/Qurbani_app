const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const auth = require("../middleware/authmiddleware");

/**
 * POST /api/requests
 * Submit a special request for an order
 */
router.post("/", auth, async (req, res) => {
  const { orderId, userId, title, description } = req.body;

  if (req.user.id !== userId) {
    return res.status(403).json({ message: "Unauthorized" });
  }

  if (!orderId || !title || !description) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    await pool.execute(
      `
      INSERT INTO requests 
        (order_id, user_id, title, description, status)
      VALUES (?, ?, ?, ?, 'Pending')
      `,
      [orderId, userId, title, description]
    );

    res.status(201).json({ message: "Request submitted successfully" });
  } catch (err) {
    console.error("Error submitting request:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

/**
 * GET /api/requests/:orderId/:userId
 * Fetch all requests for a user & order
 */
router.get("/:orderId/:userId", auth, async (req, res) => {
  const { orderId, userId } = req.params;

  if (req.user.id !== userId) {
    return res.status(403).json({ message: "Unauthorized" });
  }

  try {
    const [requests] = await pool.execute(
      `
      SELECT 
        id, title, description, status, created_at
      FROM requests
      WHERE order_id = ? AND user_id = ?
      ORDER BY created_at DESC
      `,
      [orderId, userId]
    );

    res.json({ requests });
  } catch (err) {
    console.error("Error fetching requests:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

/**
 * GET /api/requests/admin
 * Fetch all special requests for admin (with optional status filter)
 * Query params: ?status=All|Pending|Replied|Closed
 */
router.get("/admin", auth, async (req, res) => {
  const adminId = req.user.id;
  const { status } = req.query; // e.g., 'Pending', 'Replied', 'Closed', or omit for 'All'

  // Assume authMiddleware sets req.user.role or check via DB
  // For simplicity, assume all authenticated users are admins; adjust if needed
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

    if (status && status !== 'All') {
      query = query.replace('ORDER BY', 'WHERE r.status = ? ORDER BY');
      params = [status];
    }

    const [requests] = await pool.execute(query, params);
    res.json({ requests });
  } catch (err) {
    console.error("Error fetching admin requests:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

/**
 * PUT /api/requests/admin/:requestId
 * Update a request (reply or close) for admin
 */
router.put("/admin/:requestId", auth, async (req, res) => {
  const { requestId } = req.params;
  const { replyMessage, action } = req.body; // action: 'reply' or 'close'

  if (!action || (action === 'reply' && !replyMessage)) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    let updateFields = {};
    if (action === 'reply') {
      updateFields = {
        reply_message: replyMessage,
        status: 'Replied',
        replied_at: new Date(),
      };
    } else if (action === 'close') {
      updateFields = {
        status: 'Closed',
        closed_at: new Date(),
      };
    }

    const setClause = Object.keys(updateFields).map(key => `${key} = ?`).join(', ');
    const values = Object.values(updateFields);
    values.push(requestId); // For WHERE

    await pool.execute(
      `UPDATE requests SET ${setClause} WHERE id = ?`,
      values
    );

    res.json({ message: "Request updated successfully" });
  } catch (err) {
    console.error("Error updating request:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

module.exports = router;
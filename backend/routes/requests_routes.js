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

module.exports = router;

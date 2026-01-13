const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const authMiddleware = require('../middleware/authmiddleware');

// GET /api/slots/:adminId - Fetch slots for an admin
router.get("/:adminId", authMiddleware, async (req, res) => {
  const { adminId } = req.params;

  try {
    const [slots] = await pool.execute(
      `SELECT day, slots FROM eid_slots WHERE admin_id = ?`,
      [adminId]
    );

    // Group by day
    const slotData = {};
    slots.forEach(slot => {
      slotData[slot.day] = slot.slots;
    });

    res.json({ slots: slotData });
  } catch (err) {
    console.error("Error fetching slots:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

module.exports = router;
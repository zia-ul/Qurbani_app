const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const authMiddleware = require('../middleware/authmiddleware');

/**
 * @swagger
 * /api/slots/{adminId}:
 *   get:
 *     summary: Fetch Eid slots for an admin
 *     description: Returns available Eid booking slots grouped by day for a specific admin.
 *     tags: [Slots]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: adminId
 *         required: true
 *         description: Admin ID
 *         schema:
 *           type: string
 *           example: "a1b2c3d4"
 *     responses:
 *       200:
 *         description: Slots fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 slots:
 *                   type: object
 *                   additionalProperties:
 *                     type: array
 *                     items:
 *                       type: string
 *                     example:
 *                       - "08:00 - 10:00"
 *                       - "10:00 - 12:00"
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Internal server error
 */


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
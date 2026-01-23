const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const express = require("express");
const router = express.Router();

/**
 * @swagger
 * /slots/{adminId}/{day}:
 *   get:
 *     summary: Fetch Eid slots for an admin by day
 *     description: Returns all Eid booking slots for a specific admin and day.
 *     tags: [Slots]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: adminId
 *         required: true
 *         schema:
 *           type: string
 *           example: "3a98f791-9839-4158-86e3-ba8cac74f354"
 *       - in: path
 *         name: day
 *         required: true
 *         schema:
 *           type: string
 *           enum: [day1, day2, day3]
 *           example: "day1"
 *     responses:
 *       200:
 *         description: Slots fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Slot'
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Server error
 */


// GET /api/slots/:adminId - Fetch slots for an admin

/**
 * GET slots by admin + day
 * /slots/:adminId/:day
 */
router.get("/:adminId/:day", async (req, res) => {
  const { adminId, day } = req.params;

  try {
    const [rows] = await pool.query(
      `
      SELECT slot_time, slot_order, status
      FROM eid_slots
      WHERE admin_id = ? AND day = ?
      ORDER BY slot_order
      `,
      [adminId, day]
    );

    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Failed to fetch slots" });
  }
});


/**
 * @swagger
 * /slots/{adminId}/{day}:
 *   post:
 *     summary: Save or update Eid slots for an admin
 *     description: Overwrites all existing slots for the given admin and day.
 *     tags: [Slots]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: adminId
 *         required: true
 *         schema:
 *           type: string
 *           example: "3a98f791-9839-4158-86e3-ba8cac74f354"
 *       - in: path
 *         name: day
 *         required: true
 *         schema:
 *           type: string
 *           enum: [day1, day2, day3]
 *           example: "day1"
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               slots:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     time:
 *                       type: string
 *                       example: "10:30 AM"
 *                     slot_order:
 *                       type: integer
 *                       example: 1
 *                     status:
 *                       type: string
 *                       example: "Free"
 *     responses:
 *       200:
 *         description: Slots saved successfully
 *       400:
 *         description: Invalid input
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Server error
 */


/**
 * SAVE / OVERWRITE slots for admin + day
 * /slots/:adminId/:day
 */
router.post("/:adminId/:day", async (req, res) => {
  const { adminId, day } = req.params;
  const { slots } = req.body;

  if (!Array.isArray(slots)) {
    return res.status(400).json({ message: "Invalid slots data" });
  }

  const conn = await pool.getConnection();

  try {
    await conn.beginTransaction();

    // 🔥 Remove old slots for the day
    await conn.query(
      "DELETE FROM eid_slots WHERE admin_id = ? AND day = ?",
      [adminId, day]
    );

    // 🔥 Insert new slots
    for (const slot of slots) {
      await conn.query(
        `
        INSERT INTO eid_slots
        (admin_id, day, slot_time, slot_order, status)
        VALUES (?, ?, ?, ?, ?)
        `,
        [
          adminId,
          day,
          slot.time,
          slot.slot_order,
          slot.status || "Free",
        ]
      );
    }

    await conn.commit();
    res.json({ message: "Slots saved successfully" });
  } catch (err) {
    await conn.rollback();
    console.error(err);
    res.status(500).json({ message: "Failed to save slots" });
  } finally {
    conn.release();
  }
});

module.exports = router;

const express = require("express");
const router = express.Router();
const db = require("../config/db");
const verifyToken = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");

/**
 * POST /api/notifications/save-device
 */
router.post("/save-device", verifyToken, async (req, res) => {
  const { subscription_id, role } = req.body;
  const userId = req.user.id;


  console.log("Saving device for userId:", userId, "subscription_id:", subscription_id, "role:", role);

  try {
    if (!subscription_id) {
      return res.status(400).json({ message: "Subscription ID is required" });
    }

    // Check if device already exists
    const [existing] = await db.query(
      `SELECT id FROM user_devices WHERE subscription_id = ?`,
      [subscription_id],
    );

    console.log("Existing device check result:", existing);

    if (existing.length > 0) {
      // Update user association (if user changed)
      await db.query(
        `UPDATE user_devices 
         SET user_id = ?, role = ? 
         WHERE subscription_id = ?`,
        [userId, role, subscription_id],
      );

      logger.info("Device updated", { userId, subscription_id });
    } else {

      console.log("No existing device found, inserting new device for subscription_id:", subscription_id);
      // Insert new device
      await db.query(
        `INSERT INTO user_devices 
         (user_id, role, subscription_id) 
         VALUES (?, ?, ?)`,
        [userId, role, subscription_id],
      );

      logger.info("Device registered", { userId, subscription_id });
    }

    return res.json({ message: "Device saved successfully" });
  } catch (err) {
    logger.error("Save device error", {
      userId,
      error: err.message,
    });

    return res.status(500).json({ message: "Failed to save device" });
  }
});

module.exports = router;

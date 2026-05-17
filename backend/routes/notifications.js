const express = require("express");
const router = express.Router();
const db = require("../config/db");
const verifyToken = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");
const supabase = require("../config/supabase");

/**
 * POST /api/notifications/save-device
 */
// router.post("/save-device", verifyToken, async (req, res) => {
//   const { subscription_id, role } = req.body;
//   const userId = req.user.id;


//   console.log("Saving device for userId:", userId, "subscription_id:", subscription_id, "role:", role);

//   try {
//     if (!subscription_id) {
//       return res.status(400).json({ message: "Subscription ID is required" });
//     }

//     // Check if device already exists
//     const [existing] = await db.query(
//       `SELECT id FROM user_devices WHERE subscription_id = ?`,
//       [subscription_id],
//     );

//     console.log("Existing device check result:", existing);

//     if (existing.length > 0) {
//       // Update user association (if user changed)
//       await db.query(
//         `UPDATE user_devices 
//          SET user_id = ?, role = ? 
//          WHERE subscription_id = ?`,
//         [userId, role, subscription_id],
//       );

//       logger.info("Device updated", { userId, subscription_id });
//     } else {

//       console.log("No existing device found, inserting new device for subscription_id:", subscription_id);
//       // Insert new device
//       await db.query(
//         `INSERT INTO user_devices 
//          (user_id, role, subscription_id) 
//          VALUES (?, ?, ?)`,
//         [userId, role, subscription_id],
//       );

//       logger.info("Device registered", { userId, subscription_id });
//     }

//     return res.json({ message: "Device saved successfully" });
//   } catch (err) {
//     logger.error("Save device error", {
//       userId,
//       error: err.message,
//     });

//     return res.status(500).json({ message: "Failed to save device" });
//   }
// });

/**
 * =========================================
 * SAVE / UPDATE USER DEVICE
 * =========================================
 */
router.post("/save-device", verifyToken, async (req, res) => {
  const userId = req.user.id;

  try {
    const { subscription_id, role } = req.body;

    /**
     * ================================
     * Validation
     * ================================
     */
    if (!subscription_id) {
      logger.warn("Subscription ID missing", {
        userId,
      });

      return res.status(400).json({
        success: false,
        message: "Subscription ID is required",
      });
    }

    /**
     * ================================
     * Normalize Data
     * ================================
     */
    const normalizedRole =
      typeof role === "string"
        ? role.trim().toLowerCase()
        : "user";

    /**
     * ================================
     * Check Existing Device
     * ================================
     */
    const { data: existingDevice, error: fetchError } = await supabase
      .from("user_devices")
      .select("id")
      .eq("subscription_id", subscription_id)
      .maybeSingle();

    if (fetchError) {
      logger.error("Failed to check existing device", {
        userId,
        error: fetchError.message,
      });

      return res.status(500).json({
        success: false,
        message: "Failed to validate device",
      });
    }

    /**
     * ================================
     * UPDATE Existing Device
     * ================================
     */
    if (existingDevice) {
      const { error: updateError } = await supabase
        .from("user_devices")
        .update({
          user_id: userId,
          role: normalizedRole,
          updated_at: new Date().toISOString(),
        })
        .eq("subscription_id", subscription_id);

      if (updateError) {
        logger.error("Failed to update device", {
          userId,
          error: updateError.message,
        });

        return res.status(500).json({
          success: false,
          message: "Failed to update device",
        });
      }

      logger.info("Device updated successfully", {
        userId,
        subscription_id,
        role: normalizedRole,
      });

      return res.status(200).json({
        success: true,
        message: "Device updated successfully",
      });
    }

    /**
     * ================================
     * INSERT New Device
     * ================================
     */
    const { error: insertError } = await supabase
      .from("user_devices")
      .insert({
        user_id: userId,
        role: normalizedRole,
        subscription_id,
        created_at: new Date().toISOString(),
      });

    if (insertError) {
      logger.error("Failed to save device", {
        userId,
        error: insertError.message,
      });

      return res.status(500).json({
        success: false,
        message: "Failed to save device",
      });
    }

    /**
     * ================================
     * Success
     * ================================
     */
    logger.info("Device saved successfully", {
      userId,
      subscription_id,
      role: normalizedRole,
    });

    return res.status(201).json({
      success: true,
      message: "Device saved successfully",
    });
  } catch (err) {
    /**
     * ================================
     * Unexpected Errors
     * ================================
     */
    logger.error("Unexpected save device error", {
      userId,
      error: err.message,
      stack: err.stack,
    });

    return res.status(500).json({
      success: false,
      message: "Something went wrong. Please try again later.",
    });
  }
});

module.exports = router;
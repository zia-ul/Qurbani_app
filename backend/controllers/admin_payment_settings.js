/**
 * Controller for managing admin payment settings.
 * This module handles CRUD operations for admin-specific payment configurations,
 * including settings for Cash on Delivery (COD) and online payments.
 * It provides endpoints for admins to manage their settings and for public access to view them.
 */

// Import database connection module
const db = require("../config/db");
// Import logger middleware for logging operations
const logger = require("../middleware/logger");

/**
 * ADMIN (authenticated)
 * GET /api/admin/payment-settings
 * Retrieves the payment settings for the authenticated admin.
 * If no custom settings exist, returns default values.
 */
exports.getMyPaymentSettings = async (req, res) => {
  // Extract admin ID from authenticated user
  const adminId = req.user.id;

  logger.info("Admin fetching own payment settings", { adminId });

  try {
    // Query database for admin's payment settings
    const [rows] = await db.query(
      `SELECT allow_cod, allow_online, cod_deadline
       FROM admin_payment_settings
       WHERE admin_id = ?`,
      [adminId]
    );

    // If no settings found, return default values
    if (!rows.length) {
      logger.info("Admin has no custom payment settings, returning defaults", {
        adminId,
      });

      return res.json({
        allow_cod: 0,        // Default: COD not allowed
        allow_online: 1,     // Default: Online payments allowed
        cod_deadline: null,  // Default: No COD deadline
      });
    }

    // Return the found settings
    res.json(rows[0]);
  } catch (err) {
    logger.error("Failed to fetch admin payment settings", {
      adminId,
      error: err.message,
      stack: err.stack,
    });

    // Send error response
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
};


/**
 * ADMIN (authenticated)
 * PUT /api/admin/payment-settings
 * Updates the payment settings for the authenticated admin.
 * Uses INSERT ... ON DUPLICATE KEY UPDATE to handle both insert and update operations.
 */
exports.updateMyPaymentSettings = async (req, res) => {
  // Extract admin ID and settings from request
  const adminId = req.user.id;
  const { allow_cod, allow_online, cod_deadline } = req.body;

  logger.info("Admin updating payment settings", {
    adminId,
    allow_cod,
    allow_online,
    has_cod_deadline: !!cod_deadline,
  });

  try {
    // Insert or update payment settings in database
    // ON DUPLICATE KEY UPDATE handles both new and existing records
    await db.query(
      `
      INSERT INTO admin_payment_settings
        (admin_id, allow_cod, allow_online, cod_deadline)
      VALUES (?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        allow_cod = VALUES(allow_cod),
        allow_online = VALUES(allow_online),
        cod_deadline = VALUES(cod_deadline)
      `,
      [
        adminId,
        allow_cod ?? 0,      // Default to 0 if not provided
        allow_online ?? 0,   // Default to 0 if not provided
        cod_deadline ?? null, // Default to null if not provided
      ]
    );

    logger.info("Admin payment settings updated successfully", {
      adminId,
    });

    // Send success response
    res.json({ message: "Payment settings updated successfully" });
  } catch (err) {
    logger.error("Failed to update admin payment settings", {
      adminId,
      error: err.message,
      stack: err.stack,
    });

    // Send error response
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
};


/**
 * USER (public)
 * GET /api/admins/:adminId/payment-settings
 * Retrieves payment settings for a specific admin publicly.
 * Used by users to check payment options available from an admin.
 */
exports.getAdminPaymentSettingsPublic = async (req, res) => {
  // Extract admin ID from URL parameters
  const { adminId } = req.params;

  logger.info("Public fetch of admin payment settings", { adminId });

  try {
    // Query database for the specified admin's payment settings
    const [rows] = await db.query(
      `SELECT allow_cod, allow_online, cod_deadline
       FROM admin_payment_settings
       WHERE admin_id = ?`,
      [adminId]
    );

    // If no settings found, return default values
    if (!rows.length) {
      return res.json({
        allow_cod: 0,        // Default: COD not allowed
        allow_online: 1,     // Default: Online payments allowed
        cod_deadline: null,  // Default: No COD deadline
      });
    }

    // Return the found settings
    res.json(rows[0]);
  } catch (err) {
    logger.error("Failed to fetch public admin payment settings", {
      adminId,
      error: err.message,
    });

    // Send error response
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
};


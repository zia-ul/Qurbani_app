/**
 * Controller for managing admin payment settings.
 * This module handles CRUD operations for admin-specific payment configurations,
 * including settings for Cash (COD) and online payments.
 * It provides endpoints for admins to manage their settings and for public access to view them.
 */

// Import database connection module
const db = require("../config/db");
// Import logger middleware for logging operations
const logger = require("../middleware/logger");

const normalizeDate = (value) => {
  if (!value) {
    return null;
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }

  return date.toISOString().split("T")[0];
};

const latestPaymentSettingsQuery = `
  SELECT allow_cod, allow_online, cod_deadline
  FROM admin_payment_settings
  WHERE admin_id = ?
  ORDER BY updated_at DESC
  LIMIT 1
`;

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
      latestPaymentSettingsQuery,
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
 * Updates existing rows first and inserts a new row only when none exists.
 */
exports.updateMyPaymentSettings = async (req, res) => {
  // Extract admin ID and settings from request
  const adminId = req.user.id;
  const { allow_cod, allow_online, cod_deadline } = req.body;
  const normalizedCodDeadline = normalizeDate(cod_deadline);

  logger.info("Admin updating payment settings", {
    adminId,
    allow_cod,
    allow_online,
    has_cod_deadline: !!normalizedCodDeadline,
  });

  if (cod_deadline && !normalizedCodDeadline) {
    return res.status(400).json({
      message: "Please choose a valid COD deadline.",
    });
  }

  try {
    const normalizedAllowCod = allow_cod ?? 0;
    const normalizedAllowOnline = allow_online ?? 0;

    const [updateResult] = await db.query(
      `
      UPDATE admin_payment_settings
      SET allow_cod = ?, allow_online = ?, cod_deadline = ?
      WHERE admin_id = ?
      `,
      [
        normalizedAllowCod,
        normalizedAllowOnline,
        normalizedCodDeadline,
        adminId,
      ]
    );

    if (updateResult.affectedRows === 0) {
      await db.query(
        `
        INSERT INTO admin_payment_settings
          (admin_id, allow_cod, allow_online, cod_deadline)
        VALUES (?, ?, ?, ?)
        `,
        [
          adminId,
          normalizedAllowCod,
          normalizedAllowOnline,
          normalizedCodDeadline,
        ]
      );
    }

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
      latestPaymentSettingsQuery,
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


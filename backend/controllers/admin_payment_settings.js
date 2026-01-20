const db = require("../config/db");

/**
 * ADMIN (authenticated)
 * GET /api/admin/payment-settings
 */
exports.getMyPaymentSettings = async (req, res) => {
  const adminId = req.user.id;

  logger.info("Admin fetching own payment settings", { adminId });

  try {
    const [rows] = await db.query(
      `SELECT allow_cod, allow_online, cod_deadline
       FROM admin_payment_settings
       WHERE admin_id = ?`,
      [adminId]
    );

    if (!rows.length) {
      logger.info("Admin has no custom payment settings, returning defaults", {
        adminId,
      });

      return res.json({
        allow_cod: 0,
        allow_online: 1,
        cod_deadline: null,
      });
    }

    res.json(rows[0]);
  } catch (err) {
    logger.error("Failed to fetch admin payment settings", {
      adminId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Server error" });
  }
};


/**
 * ADMIN (authenticated)
 * PUT /api/admin/payment-settings
 */
exports.updateMyPaymentSettings = async (req, res) => {
  const adminId = req.user.id;
  const { allow_cod, allow_online, cod_deadline } = req.body;

  logger.info("Admin updating payment settings", {
    adminId,
    allow_cod,
    allow_online,
    has_cod_deadline: !!cod_deadline,
  });

  try {
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
        allow_cod ?? 0,
        allow_online ?? 0,
        cod_deadline ?? null,
      ]
    );

    logger.info("Admin payment settings updated successfully", {
      adminId,
    });

    res.json({ message: "Payment settings updated successfully" });
  } catch (err) {
    logger.error("Failed to update admin payment settings", {
      adminId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Server error" });
  }
};


/**
 * USER (public)
 * GET /api/admins/:adminId/payment-settings
 */
exports.getAdminPaymentSettingsPublic = async (req, res) => {
  const { adminId } = req.params;

  logger.info("Public fetch of admin payment settings", { adminId });

  try {
    const [rows] = await db.query(
      `SELECT allow_cod, allow_online, cod_deadline
       FROM admin_payment_settings
       WHERE admin_id = ?`,
      [adminId]
    );

    if (!rows.length) {
      return res.json({
        allow_cod: 0,
        allow_online: 1,
        cod_deadline: null,
      });
    }

    res.json(rows[0]);
  } catch (err) {
    logger.error("Failed to fetch public admin payment settings", {
      adminId,
      error: err.message,
    });

    res.status(500).json({ message: "Server error" });
  }
};


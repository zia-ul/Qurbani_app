const db = require("../config/db");

/**
 * ADMIN (authenticated)
 * GET /api/admin/payment-settings
 */
exports.getMyPaymentSettings = async (req, res) => {
  try {
    const adminId = req.user.id;

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
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

/**
 * ADMIN (authenticated)
 * PUT /api/admin/payment-settings
 */
exports.updateMyPaymentSettings = async (req, res) => {
  try {
    const adminId = req.user.id;
    const { allow_cod, allow_online, cod_deadline } = req.body;

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

    res.json({ message: "Payment settings updated successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

/**
 * USER (public)
 * GET /api/admins/:adminId/payment-settings
 */
exports.getAdminPaymentSettingsPublic = async (req, res) => {
  try {
    const { adminId } = req.params;

    const [rows] = await db.query(
      `SELECT allow_cod, allow_online, cod_deadline
       FROM admin_payment_settings
       WHERE admin_id = ?`,
      [adminId]
    );

    if (!rows.length) {
      // Default behavior if admin never configured settings
      return res.json({
        allow_cod: 0,
        allow_online: 1,
        cod_deadline: null,
      });
    }

    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

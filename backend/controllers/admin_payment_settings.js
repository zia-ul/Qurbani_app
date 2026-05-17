/**
 * Controller for managing admin payment settings.
 * PostgreSQL + Supabase version
 */

const db = require("../config/db");
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
  WHERE admin_id = $1
  ORDER BY updated_at DESC
  LIMIT 1
`;

/**
 * ADMIN (authenticated)
 * GET /api/admin/payment-settings
 */
exports.getMyPaymentSettings = async (req, res) => {
  const adminId = req.user.id;

  logger.info("Admin fetching own payment settings", {
    adminId,
  });

  try {
    const result = await db.query(
      latestPaymentSettingsQuery,
      [adminId]
    );

    const rows = result.rows;

    if (!rows.length) {
      logger.info(
        "Admin has no custom payment settings, returning defaults",
        { adminId }
      );

      return res.json({
        allow_cod: 0,
        allow_online: 1,
        cod_deadline: null,
      });
    }

    res.json(rows[0]);
  } catch (err) {
    logger.error(
      "Failed to fetch admin payment settings",
      {
        adminId,
        error: err.message,
        stack: err.stack,
      }
    );

    res.status(500).json({
      message:
        "Something went wrong. Please try again later.",
    });
  }
};

/**
 * ADMIN (authenticated)
 * PUT /api/admin/payment-settings
 */
exports.updateMyPaymentSettings = async (req, res) => {
  const adminId = req.user.id;

  const {
    allow_cod,
    allow_online,
    cod_deadline,
  } = req.body;

  const normalizedCodDeadline =
    normalizeDate(cod_deadline);

  logger.info(
    "Admin updating payment settings",
    {
      adminId,
      allow_cod,
      allow_online,
      has_cod_deadline:
        !!normalizedCodDeadline,
    }
  );

  if (
    cod_deadline &&
    !normalizedCodDeadline
  ) {
    return res.status(400).json({
      message:
        "Please choose a valid COD deadline.",
    });
  }

  try {
    const normalizedAllowCod =
      allow_cod ?? 0;

    const normalizedAllowOnline =
      allow_online ?? 0;

    const updateResult = await db.query(
      `
      UPDATE admin_payment_settings
      SET
        allow_cod = $1,
        allow_online = $2,
        cod_deadline = $3
      WHERE admin_id = $4
      `,
      [
        normalizedAllowCod,
        normalizedAllowOnline,
        normalizedCodDeadline,
        adminId,
      ]
    );

    if (updateResult.rowCount === 0) {
      await db.query(
        `
        INSERT INTO admin_payment_settings
        (
          admin_id,
          allow_cod,
          allow_online,
          cod_deadline
        )
        VALUES ($1, $2, $3, $4)
        `,
        [
          adminId,
          normalizedAllowCod,
          normalizedAllowOnline,
          normalizedCodDeadline,
        ]
      );
    }

    logger.info(
      "Admin payment settings updated successfully",
      {
        adminId,
      }
    );

    res.json({
      message:
        "Payment settings updated successfully",
    });
  } catch (err) {
    logger.error(
      "Failed to update admin payment settings",
      {
        adminId,
        error: err.message,
        stack: err.stack,
      }
    );

    res.status(500).json({
      message:
        "Something went wrong. Please try again later.",
    });
  }
};

/**
 * USER (public)
 * GET /api/admins/:adminId/payment-settings
 */
exports.getAdminPaymentSettingsPublic =
  async (req, res) => {
    const { adminId } = req.params;

    logger.info(
      "Public fetch of admin payment settings",
      {
        adminId,
      }
    );

    try {
      const result = await db.query(
        latestPaymentSettingsQuery,
        [adminId]
      );

      const rows = result.rows;

      if (!rows.length) {
        return res.json({
          allow_cod: 0,
          allow_online: 1,
          cod_deadline: null,
        });
      }

      res.json(rows[0]);
    } catch (err) {
      logger.error(
        "Failed to fetch public admin payment settings",
        {
          adminId,
          error: err.message,
        }
      );

      res.status(500).json({
        message:
          "Something went wrong. Please try again later.",
      });
    }
  };
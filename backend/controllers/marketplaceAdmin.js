const db = require("../config/db");
const logger = require("../middleware/logger");

/**
 * Get all VERIFIED admins
 */
exports.getVerifiedAdmins = async () => {
  try {
    const result = await db.query(`
      SELECT
        id,
        name,
        country,
        state,
        city,
        address,
        photo_url,
        order_deadline,

        CASE
          WHEN order_deadline IS NOT NULL
               AND order_deadline < NOW()
          THEN true
          ELSE false
        END AS is_order_closed

      FROM users
      WHERE role = 'admin'
        AND admin_status = 'approved'

      ORDER BY name ASC
    `);

    return result.rows;
  } catch (err) {
    logger.error(
      "DB error fetching verified admins",
      {
        error: err.message,
      }
    );

    throw new Error(
      "Failed to fetch verified admins"
    );
  }
};

/**
 * GET /api/admins/verified
 */
exports.fetchVerifiedAdmins = async (
  req,
  res
) => {
  try {
    const admins =
      await exports.getVerifiedAdmins();

    res.status(200).json({
      admins,
    });
  } catch (err) {
    logger.error(
      "Fetch verified admins error",
      {
        error: err.message,
      }
    );

    res.status(500).json({
      message:
        "Something went wrong. Please try again later.",
    });
  }
};
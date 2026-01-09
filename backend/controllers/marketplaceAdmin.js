const db = require("../config/db");

/**
 * Get all VERIFIED admins
 */
exports.getVerifiedAdmins = async () => {
  const [rows] = await db.query(`
    SELECT 
      id,
      name,
      city
    FROM users
    WHERE role = 'admin'
      AND admin_status = 'approved'
    ORDER BY name ASC
  `);

  return rows;
};


/**
 * GET /api/admins/verified
 */
exports.fetchVerifiedAdmins = async (req, res) => {
  try {
    const admins = await exports.getVerifiedAdmins();
    res.status(200).json({ admins });
  } catch (err) {
    console.error("Fetch verified admins error:", err);
    res.status(500).json({ message: "Server error" });
  }
};
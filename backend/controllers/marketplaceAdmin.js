const db = require("../config/db");

/**
 * Get all VERIFIED admins
 */
exports.getVerifiedAdmins = async () => {
  const [rows] = await db.query(
    `
    SELECT 
      id,
      name,
      address,
      average_rating
    FROM users
    WHERE role = 'admin'
      AND admin_status = 'approved'
    ORDER BY average_rating DESC
    `
  );

  return rows;
};

exports.fetchVerifiedAdmins = async (req, res) => {
  try {
    const admins = await getVerifiedAdmins();
    res.json({ admins });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};
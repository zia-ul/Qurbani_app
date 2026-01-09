const jwt = require("jsonwebtoken");
const db = require("../config/db");

module.exports = async (req, res, next) => {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) return res.status(401).json({ message: "No token provided" });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const [rows] = await db.query("SELECT id, role, admin_status FROM users WHERE id = ?", [decoded.id]);
    if (!rows[0]) return res.status(401).json({ message: "User not found" });

    req.user = rows[0]; // MUST set req.user
    next();
  } catch (err) {
    console.error("Auth error:", err);
    return res.status(401).json({ message: "Invalid token" });
  }
};

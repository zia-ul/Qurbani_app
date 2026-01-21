const express = require("express");
const bcrypt = require("bcryptjs");
const { body, validationResult } = require("express-validator");
const db = require("../config/db");
const { v4: uuidv4 } = require("uuid");
const jwt = require("jsonwebtoken");
const authMiddleware = require("../middleware/authmiddleware");
const pool = require("../config/db");
const logger = require("../middleware/logger"); // Winston logger
const { loginLimiter, registerLimiter } = require("../middleware/rate_limiter");

const router = express.Router();

/**
 * POST /api/auth/register
 */
router.post(
  "/register", registerLimiter,
  [
    body("name").notEmpty(),
    body("email").isEmail(),
    body("password").isLength({ min: 8 }),
    body("role").isIn(["user", "admin", "delivery"]),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      logger.warn("Registration failed: invalid input", { body: req.body });
      return res.status(400).json({ message: "Invalid input" });
    }

    const {
      name,
      email,
      password,
      phone,
      countryISO,
      address,
      gender,
      role,
      currency,
      city,
    } = req.body;

    try {
      logger.info("Registration attempt", { email, role });

      // Check email uniqueness
      const [existing] = await db.query(
        "SELECT id FROM users WHERE email = ?",
        [email]
      );

      if (existing.length > 0) {
        logger.warn("Registration failed: email already registered", { email });
        return res.status(409).json({ message: "Email already registered" });
      }

      // Hash password
      const passwordHash = await bcrypt.hash(password, 12);

      const adminStatus = role === "admin" ? "pending_admin" : null;
      const userId = uuidv4();
      const verificationToken = uuidv4();

      await db.query(
        `INSERT INTO users
        (id, name, email, password_hash, phone, country_iso, address, gender, role,
         admin_status, currency, city, is_verified, verification_token)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          userId,
          name,
          email,
          passwordHash,
          phone,
          countryISO,
          address,
          gender,
          role,
          adminStatus,
          currency || "USD",
          city || null,
          false,
          verificationToken,
        ]
      );

      logger.info("User registered successfully", { userId, role });

      return res.status(201).json({
        message:
          role === "admin"
            ? "Admin registered. Awaiting super admin approval."
            : "Registration successful",
      });
    } catch (err) {
      logger.error("Registration error", { email, role, error: err.message });
      res.status(500).json({ message: err.message || "Something went wrong. Please try again later." });
    }
  }
);

/**
 * POST /api/auth/login
 */
router.post("/login", loginLimiter, async (req, res) => {
  const { email, password } = req.body;

  try {
    if (!email || !password) {
      logger.warn("Login failed: missing email or password", { body: req.body });
      return res.status(400).json({ message: "Email and password are required" });
    }

    const emailNormalized = email.toLowerCase();
    logger.info("Login attempt", { email: emailNormalized });

    const [users] = await db.query(
      `SELECT 
        id, name, email, password_hash, role, admin_status,
        is_verified, is_active, city, currency
       FROM users
       WHERE email = ?`,
      [emailNormalized]
    );

    if (users.length === 0) {
      logger.warn("Login failed: unregistered email", { email: emailNormalized });
      return res.status(404).json({ message: "Unregistered Mail id" });
    }

    const user = users[0];
    const isMatch = await bcrypt.compare(password, user.password_hash);

    if (!isMatch) {
      logger.warn("Login failed: incorrect password", { userId: user.id });
      return res.status(401).json({ message: "Incorrect password" });
    }

    if (!user.is_verified) {
      logger.warn("Login blocked: email not verified", { userId: user.id });
      return res
        .status(403)
        .json({ message: "Please verify your email before logging in" });
    }

    if (!user.is_active) {
      logger.warn("Login blocked: account deactivated", { userId: user.id });
      return res
        .status(403)
        .json({ message: "Account is deactivated. Contact support." });
    }

    let adminVerificationStatus = null;
    if (user.role === "admin") {
      const [rows] = await db.query(
        `SELECT status FROM admin_verification_requests WHERE user_id = ?`,
        [user.id]
      );
      adminVerificationStatus = rows.length ? rows[0].status : "not_submitted";
    }

    const token = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, {
      expiresIn: "7d",
    });

    logger.info("Login successful", { userId: user.id, role: user.role });

    return res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        city: user.city,
        currency: user.currency,
        admin_verification_status: adminVerificationStatus,
      },
    });
  } catch (err) {
    logger.error("Login error", { email, error: err.message });
    return res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

/**
 * GET /api/auth/me
 */
router.get("/me", authMiddleware, async (req, res) => {
  try {
    const [users] = await pool.execute(
      `SELECT id, name, email, role FROM users WHERE id = ?`,
      [req.user.id]
    );

    if (users.length === 0) {
      logger.warn("Fetch current user failed: user not found", { userId: req.user.id });
      return res.status(404).json({ message: "User not found" });
    }

    let verificationStatus = null;
    if (users[0].role === "admin") {
      const [rows] = await pool.execute(
        `SELECT status FROM admin_verification_requests WHERE user_id = ?`,
        [req.user.id]
      );
      verificationStatus = rows.length ? rows[0].status : "not_submitted";
    }

    logger.debug("Fetched current user profile", { userId: req.user.id });

    res.json({
      user: {
        ...users[0],
        verification_status: verificationStatus,
      },
    });
  } catch (err) {
    logger.error("Fetch current user error", { userId: req.user.id, error: err.message });
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});


// Update profile photo
router.put("/update-profile-photo", authMiddleware, async (req, res) => {
  const userId = req.user.id;
  const { photoUrl } = req.body;

  if (!photoUrl) {
    return res.status(400).json({ message: "Photo URL is required" });
  }

  try {
    await db.query(
      "UPDATE users SET photo_url = ? WHERE id = ?",
      [photoUrl, userId]
    );

    res.json({ message: "Profile photo updated", photoUrl });
  } catch (err) {
    logger.error("Profile photo update failed", {
      userId,
      error: err.message,
    });

    res.status(500).json({ message: "Something went wrong. Please try again." });
  }
});


/**
 * PUT /api/auth/change-password
 */
router.put("/change-password", authMiddleware, async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  const userId = req.user.id;

  try {
    const [users] = await pool.execute(
      `SELECT password_hash FROM users WHERE id = ?`,
      [userId]
    );

    if (users.length === 0) {
      logger.warn("Password change failed: user not found", { userId });
      return res.status(404).json({ message: "User not found" });
    }

    const isValid = await bcrypt.compare(currentPassword, users[0].password_hash);
    if (!isValid) {
      logger.warn("Password change failed: incorrect current password", { userId });
      return res.status(400).json({ message: "Current password is incorrect" });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await pool.execute(`UPDATE users SET password_hash = ? WHERE id = ?`, [
      hashedPassword,
      userId,
    ]);

    logger.info("Password changed successfully", { userId });

    res.json({ message: "Password changed successfully" });
  } catch (err) {
    logger.error("Change password error", { userId, error: err.message });
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

module.exports = router;

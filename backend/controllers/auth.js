const express = require("express");
const bcrypt = require("bcryptjs");
const { body, validationResult } = require("express-validator");
const db = require("../config/db");
const { v4: uuidv4 } = require("uuid"); // For UUID
const crypto = require("crypto"); // Optional if you want extra token randomness
const nodemailer = require("nodemailer"); // For sending verification emails
const jwt = require("jsonwebtoken");
const authMiddleware = require("../middleware/authmiddleware");
const pool = require("../config/db");

//email verification using nodemailer
// const transporter = nodemailer.createTransport({
//   service: "Gmail",
//   auth: {
//     user: "your_email@gmail.com",
//     pass: "your_email_password",
//   },
// });

const router = express.Router();

/**
 * POST /api/auth/register
 */
router.post(
  "/register",
  [
    body("name").notEmpty(),
    body("email").isEmail(),
    body("password").isLength({ min: 8 }),
    body("role").isIn(["user", "admin", "delivery"]),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
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
      // Check email uniqueness
      const [existing] = await db.query(
        "SELECT id FROM users WHERE email = ?",
        [email]
      );

      if (existing.length > 0) {
        return res.status(409).json({ message: "Email already registered" });
      }

      // Admin city uniqueness check
      // if (role === "admin") {
      //   if (!city) {
      //     return res
      //       .status(400)
      //       .json({ message: "City is required for admin" });
      //   }

      //   const [adminExists] = await db.query(
      //     `SELECT id FROM users
      //      WHERE role = 'admin' AND admin_status = 'approved' AND city = ?`,
      //     [city]
      //   );

      //   if (adminExists.length > 0) {
      //     return res.status(409).json({
      //       message: "An admin already exists for this city",
      //     });
      //   }
      // }

      // Hash password
      const passwordHash = await bcrypt.hash(password, 12);

      // Admin approval logic
      const adminStatus = role === "admin" ? "pending_admin" : null;
      // const is_verified = role === "admin" ? 1 : 0;
      const userId = uuidv4();
      const verificationToken = uuidv4();

      // Insert user
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

      // trigger email verification / admin notification here

      return res.status(201).json({
        message:
          role === "admin"
            ? "Admin registered. Awaiting super admin approval."
            : "Registration successful",
      });
    } catch (err) {
      console.error("Registration error:", err);
      res.status(500).json({ message: err.message || "Server error" });
    }
  }
);

//login verification API
router.post("/login", async (req, res) => {
  const { email, password } = req.body;

  try {
    // Validate input
    if (!email || !password) {
      return res
        .status(400)
        .json({ message: "Email and password are required" });
    }

    const emailNormalized = email.toLowerCase();

    // Fetch user
    const [users] = await db.query(
      `SELECT 
        id, name, email, password_hash, role, admin_status,
        is_verified, is_active, city, currency
       FROM users
       WHERE email = ?`,
      [emailNormalized]
    );

    if (users.length === 0) {
      return res.status(404).json({
        message: "Unregistered Mail id",
      });
    }

    const user = users[0];

    // Check password
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({
        message: "Incorrect password",
      });
    }

    // Check email verification
    if (!user.is_verified) {
      return res.status(403).json({
        message: "Please verify your email before logging in",
      });
    }

    // Check if account is active
    if (!user.is_active) {
      return res.status(403).json({
        message: "Account is deactivated. Contact support.",
      });
    }

    let adminVerificationStatus = null;

    if (user.role === "admin") {
      const [rows] = await db.query(
        `SELECT status FROM admin_verification_requests WHERE user_id = ?`,
        [user.id]
      );

      if (rows.length === 0) {
        adminVerificationStatus = "not_submitted";
      } else {
        adminVerificationStatus = rows[0].status; // pending / approved / rejected
      }
    }

    if (!process.env.JWT_SECRET) {
      throw new Error("JWT_SECRET is not defined in environment variables");
    }

    // Admin approval check
    // if (user.role === "admin" && user.admin_status !== "approved") {
    //   return res.status(403).json({
    //     message: "Admin approval pending",
    //   });
    // }

    // Generate JWT
    const token = jwt.sign(
      {
        id: user.id,
        role: user.role,
      },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    // Send response to frontend
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
    console.error("Login error:", err);
    return res.status(500).json({ message: "Server error" });
  }
});

// // JWT middleware
// const authMiddleware = (req, res, next) => {
//   const authHeader = req.headers.authorization;

//   if (!authHeader || !authHeader.startsWith("Bearer ")) {
//     return res.status(401).json({ message: "No token provided" });
//   }

//   const token = authHeader.split(" ")[1];

//   try {
//     const decoded = jwt.verify(token, process.env.JWT_SECRET);
//     req.user = decoded;
//     next();
//   } catch (err) {
//     return res.status(401).json({ message: "Invalid token" });
//   }
// };

// GET CURRENT USER
router.get("/me", authMiddleware, async (req, res) => {
  const [users] = await pool.execute(
    `SELECT id, name, email, role FROM users WHERE id = ?`,
    [req.user.id]
  );

  if (users.length === 0) {
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

  res.json({
    user: {
      ...users[0],
      verification_status: verificationStatus,
    },
  });
});

// PUT /api/auth/change-password
router.put("/change-password", authMiddleware, async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  const userId = req.user.id;

  try {
    // Fetch user and verify current password
    const [users] = await pool.execute(
      `SELECT password_hash FROM users WHERE id = ?`,
      [userId]
    );
    if (users.length === 0)
      return res.status(404).json({ message: "User not found" });

    const isValid = await bcrypt.compare(
      currentPassword,
      users[0].password_hash
    );
    if (!isValid)
      return res.status(400).json({ message: "Current password is incorrect" });

    // Hash new password and update
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await pool.execute(`UPDATE users SET password_hash = ? WHERE id = ?`, [
      hashedPassword,
      userId,
    ]);

    res.json({ message: "Password changed successfully" });
  } catch (err) {
    console.error("Error changing password:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

module.exports = router;

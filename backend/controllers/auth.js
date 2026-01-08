const express = require("express");
const bcrypt = require("bcryptjs");
const { body, validationResult } = require("express-validator");
const db = require("../config/db");
const { v4: uuidv4 } = require("uuid"); // For UUID
const crypto = require("crypto");       // Optional if you want extra token randomness
const nodemailer = require("nodemailer"); // For sending verification emails

const transporter = nodemailer.createTransport({
  service: "Gmail",
  auth: {
    user: "your_email@gmail.com", // Replace with your email
    pass: "your_email_password",  // Or app password
  },
});


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
      // 1️⃣ Check email uniqueness
      const [existing] = await db.query(
        "SELECT id FROM users WHERE email = ?",
        [email]
      );

      if (existing.length > 0) {
        return res.status(409).json({ message: "Email already registered" });
      }

      // 2️⃣ Admin city uniqueness check
      if (role === "admin") {
        if (!city) {
          return res
            .status(400)
            .json({ message: "City is required for admin" });
        }

        const [adminExists] = await db.query(
          `SELECT id FROM users 
           WHERE role = 'admin' AND admin_status = 'approved' AND city = ?`,
          [city]
        );

        if (adminExists.length > 0) {
          return res.status(409).json({
            message: "An admin already exists for this city",
          });
        }
      }

      // 3️⃣ Hash password
      const passwordHash = await bcrypt.hash(password, 12);

      // 4️⃣ Admin approval logic
      const adminStatus = role === "admin" ? "pending" : null;
      const userId = uuidv4();
      const verificationToken = uuidv4();

      // 5️⃣ Insert user
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
          false, // is_verified default
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
    // 1️⃣ Validate input
    if (!email || !password) {
      return res.status(400).json({ message: "Email and password are required" });
    }

    // 2️⃣ Fetch user
    const [users] = await db.query(
      `SELECT 
        id, name, email, password_hash, role, admin_status,
        is_verified, is_active, city, currency
       FROM users
       WHERE email = ?`,
      [email]
    );

    if (users.length === 0) {
      return res.status(401).json({ message: "Invalid email or password" });
    }

    const user = users[0];

    // 3️⃣ Check password
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({ message: "Invalid email or password" });
    }

    // 4️⃣ Check email verification
    if (!user.is_verified) {
      return res.status(403).json({
        message: "Please verify your email before logging in",
      });
    }

    // 5️⃣ Check if account is active
    if (!user.is_active) {
      return res.status(403).json({
        message: "Account is deactivated. Contact support.",
      });
    }

    // 6️⃣ Admin approval check
    if (user.role === "admin" && user.admin_status !== "approved") {
      return res.status(403).json({
        message: "Admin approval pending",
      });
    }

    // 7️⃣ Generate JWT
    const token = jwt.sign(
      {
        id: user.id,
        role: user.role,
      },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    // 8️⃣ Send response (Flutter expects this format)
    return res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        city: user.city,
        currency: user.currency,
      },
    });
  } catch (err) {
    console.error("Login error:", err);
    return res.status(500).json({ message: "Server error" });
  }
});


module.exports = router;

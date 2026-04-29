const express = require("express");
const axios = require("axios");
const bcrypt = require("bcryptjs");
const { body, validationResult } = require("express-validator");
const db = require("../config/db");
const { v4: uuidv4 } = require("uuid");
const jwt = require("jsonwebtoken");
const authMiddleware = require("../middleware/authmiddleware");
const pool = require("../config/db");
const logger = require("../middleware/logger"); // Winston logger
const { loginLimiter, registerLimiter } = require("../middleware/rate_limiter");
const { sendVerificationEmail } = require("../src/email_service");
const router = express.Router();
let phoneVerificationColumnReady = false;
let phoneVerificationColumnPromise = null;

async function ensurePhoneVerificationColumn() {
  if (phoneVerificationColumnReady) {
    return;
  }

  if (!phoneVerificationColumnPromise) {
    phoneVerificationColumnPromise = (async () => {
      const [columns] = await db.query(
        "SHOW COLUMNS FROM users LIKE 'is_phone_verified'",
      );

      if (columns.length === 0) {
        logger.info("Adding users.is_phone_verified column");
        await db.query(
          "ALTER TABLE users ADD COLUMN is_phone_verified TINYINT(1) NOT NULL DEFAULT 0 AFTER is_verified",
        );
      }

      phoneVerificationColumnReady = true;
    })();
  }

  try {
    await phoneVerificationColumnPromise;
  } finally {
    phoneVerificationColumnPromise = null;
  }
}

function normalizePhoneNumber(phoneNumber) {
  return (phoneNumber || "").toString().replace(/\D/g, "");
}

function normalizeRole(role) {
  return (role || "")
    .toString()
    .trim()
    .replace(/([a-z0-9])([A-Z])/g, "$1_$2")
    .replace(/[\s-]+/g, "_")
    .toLowerCase();
}

function isSuperAdminRole(role) {
  return normalizeRole(role) === "super_admin";
}

async function getPhoneEmailUser({ accessToken, clientId }) {
  const response = await axios.post(
    "https://eapi.phone.email/getuser",
    new URLSearchParams({
      access_token: accessToken,
      client_id: clientId,
    }).toString(),
    {
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      timeout: 15000,
    },
  );

  const data = response.data;

  if (
    !data ||
    Number(data.status) !== 200 ||
    !data.phone_no ||
    !data.country_code
  ) {
    throw new Error("Phone.Email did not return a verified phone number.");
  }

  return data;
}

// POST /api/auth/register - User registration endpoint
// Validates input, checks for existing email, hashes password, creates user, and sends verification email
router.post(
  "/register",
  registerLimiter,
  [
    body("name").notEmpty(),
    body("email").isEmail(),
    body("password").isLength({ min: 8 }),
    body("role").isIn(["user", "admin", "delivery"]),

    body("phone").notEmpty(),
    body("country_code")
      .notEmpty()
      .matches(/^\+\d{1,4}$/),
    body("country_iso").notEmpty().isLength({ min: 2, max: 2 }),

    body("country").notEmpty(),
    body("state").optional({ nullable: true, checkFalsy: true }).isString(),
    body("city").optional({ nullable: true, checkFalsy: true }).isString(),
    body("postal_code").notEmpty().isLength({ min: 3, max: 20 }),

    body("currency").optional().isLength({ min: 3, max: 3 }),
    body("gender").optional().isIn(["Male", "Female"]),
  ],

  async (req, res) => {
    const errors = validationResult(req);

    console.log("Registration Request Body:", req.body, errors);
    if (!errors.isEmpty()) {
      logger.warn("Registration failed: invalid input", { body: req.body });
      return res.status(400).json({ message: "Invalid input" });
    }

    const {
      name,
      email,
      password,
      phone,
      country_code,
      country_iso,

      country,
      state,
      city,
      postal_code,
      address,

      gender,
      role,
      currency,
    } = req.body;

    try {
      await ensurePhoneVerificationColumn();

      logger.info("Registration attempt", { email, role });

      // Check email uniqueness
      const [existing] = await db.query(
        "SELECT id FROM users WHERE email = ?",
        [email],
      );

      console.log(existing);

      if (existing.length > 0) {
        logger.warn("Registration failed: email already registered", { email });
        return res.status(409).json({ message: "Email already registered" });
      }

      // Hash password
      const passwordHash = await bcrypt.hash(password, 12);

      // `admin_status` is a DB enum: pending | approved | rejected.
      // New admin signups should start in the pending state until reviewed.
      const adminStatus = role === "admin" ? "pending" : null;
      const userId = uuidv4();
      const verificationToken = uuidv4();

      await db.query(
        `INSERT INTO users (
          id,
          name,
          email,
          password_hash,
          phone,
          country_code,
          country_iso,
          country,
          state,
          city,
          postal_code,
          address,
          gender,
          role,
          admin_status,
          currency,
          is_verified,
          is_phone_verified,
          verification_token
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          userId,
          name,
          email,
          passwordHash,
          phone,
          country_code,
          country_iso,
          country,
          state || null,
          city,
          postal_code,
          address || null,
          gender || null,
          role,
          adminStatus,
          currency || "USD",
          false,
          false,
          verificationToken,
        ],
      );

      logger.info("User registered successfully", { userId, role });


      try {
        await sendVerificationEmail(email, verificationToken);
        logger.info(`Verification email sent to ${email}`);
      } catch (err) {
        logger.error(`Failed to send verification email to ${email}`, {
          error: err.message,
        });
      }

      return res.status(201).json({
        message:
          role === "admin"
            ? "Admin registered. Awaiting super admin approval."
            : "Registration successful",
      });
    } catch (err) {
      logger.error("Registration error", { email, role, error: err.message });
      res.status(500).json({
        message: err.message || "Something went wrong. Please try again later.",
      });
    }
  },
);

// POST /api/auth/verify-email
router.get("/verify-email", async (req, res) => {
  try {
    const { token } = req.query;

    const conn = await pool.getConnection();

    // Find user with this token
    const [users] = await conn.query(
      "SELECT * FROM users WHERE verification_token = ? AND is_verified = 0",
      [token],
    );

    if (users.length === 0) {
      conn.release();
      return res.status(400).send("Token invalid or already used");
    }

    // Update user as verified
    await conn.query(
      "UPDATE users SET is_verified = 1, verification_token = NULL WHERE id = ?",
      [users[0].id],
    );

    conn.release();
    res.send("Email verified successfully! You can now login.");
  } catch (err) {
    res.status(500).send(err.message);
  }
});

router.post("/verify-phone", async (req, res) => {
  const email = req.body?.email?.toString().trim().toLowerCase();
  const accessToken = req.body?.accessToken?.toString().trim();
  const clientId =
    process.env.PHONE_EMAIL_CLIENT_ID?.trim() ||
    req.body?.clientId?.toString().trim() ||
    "";

  if (!email || !accessToken) {
    return res.status(400).json({
      message: "Email and Phone.Email access token are required",
    });
  }

  if (!clientId) {
    return res.status(400).json({
      message: "Phone.Email client ID is missing",
    });
  }

  try {
    await ensurePhoneVerificationColumn();

    const [users] = await db.query(
      `SELECT id, phone, country_code, is_phone_verified
       FROM users
       WHERE email = ?`,
      [email],
    );

    if (users.length === 0) {
      logger.warn("Phone verification failed: user not found", { email });
      return res.status(404).json({ message: "User not found" });
    }

    const user = users[0];

    if (!user.phone || !user.country_code) {
      logger.warn("Phone verification failed: phone missing on user", {
        userId: user.id,
      });
      return res.status(400).json({
        message: "No registered phone number was found for this account",
      });
    }

    const phoneEmailUser = await getPhoneEmailUser({
      accessToken,
      clientId,
    });

    const storedPhone = normalizePhoneNumber(user.phone);
    const verifiedPhone = normalizePhoneNumber(phoneEmailUser.phone_no);
    const storedCountryCode = user.country_code.toString().trim();
    const verifiedCountryCode = phoneEmailUser.country_code.toString().trim();

    if (
      storedPhone != verifiedPhone ||
      storedCountryCode != verifiedCountryCode
    ) {
      logger.warn("Phone verification failed: phone mismatch", {
        userId: user.id,
        storedCountryCode,
        verifiedCountryCode,
      });
      return res.status(400).json({
        message:
          "The verified phone number does not match the number used during registration",
      });
    }

    if (!user.is_phone_verified) {
      await db.query("UPDATE users SET is_phone_verified = 1 WHERE id = ?", [
        user.id,
      ]);
    }

    logger.info("Phone verified successfully", { userId: user.id });

    return res.json({
      message: "Phone verified successfully",
      phone: phoneEmailUser.phone_no,
      country_code: phoneEmailUser.country_code,
    });
  } catch (err) {
    logger.error("Phone verification error", {
      email,
      error: err.message,
      response: err.response?.data,
    });

    return res.status(500).json({
      message: "Unable to verify phone right now. Please try again.",
    });
  }
});

router.post(
  "/phone-verification-context",
  loginLimiter,
  [body("email").isEmail()],
  async (req, res) => {
    const errors = validationResult(req);

    if (!errors.isEmpty()) {
      return res.status(400).json({ message: "A valid email is required" });
    }

    const email = req.body.email.toString().trim().toLowerCase();

    try {
      await ensurePhoneVerificationColumn();

      const [users] = await db.query(
        `SELECT email, phone, country_code, role, is_phone_verified
         FROM users
         WHERE email = ?`,
        [email],
      );

      if (users.length === 0) {
        logger.warn("Phone verification context lookup failed: user not found", {
          email,
        });
        return res.status(404).json({ message: "User not found" });
      }

      const user = users[0];
      const isSuperAdmin = isSuperAdminRole(user.role);

      if (isSuperAdmin) {
        return res.json({
          email: user.email,
          phone: user.phone,
          country_code: user.country_code,
          role: user.role,
          is_phone_verified: true,
          verification_not_required: true,
        });
      }

      if (!user.phone || !user.country_code) {
        logger.warn(
          "Phone verification context lookup failed: phone missing on user",
          { email },
        );
        return res.status(400).json({
          message: "No registered phone number was found for this account",
        });
      }

      return res.json({
        email: user.email,
        phone: user.phone,
        country_code: user.country_code,
        role: user.role,
        is_phone_verified: Boolean(user.is_phone_verified),
      });
    } catch (err) {
      logger.error("Phone verification context lookup error", {
        email,
        error: err.message,
      });
      return res.status(500).json({
        message: "Unable to load the registered phone number right now.",
      });
    }
  },
);

/**
 * POST /api/auth/login
 */
router.post("/login", loginLimiter, async (req, res) => {
  const { email, password } = req.body;

  try {
    await ensurePhoneVerificationColumn();

    if (!email || !password) {
      logger.warn("Login failed: missing email or password", {
        body: req.body,
      });
      return res
        .status(400)
        .json({ message: "Email and password are required" });
    }

    const emailNormalized = email.toLowerCase();
    logger.info("Login attempt", { email: emailNormalized });

    const [users] = await db.query(
      `SELECT 
        id, name, email, password_hash, role, admin_status,
        is_verified, is_phone_verified, is_active, city, currency,
        phone, country_code
       FROM users
       WHERE email = ?`,
      [emailNormalized],
    );

    if (users.length === 0) {
      logger.warn("Login failed: unregistered email", {
        email: emailNormalized,
      });
      return res.status(404).json({ message: "Unregistered Mail id" });
    }

    const user = users[0];
    const isSuperAdmin = isSuperAdminRole(user.role);
    const isMatch = await bcrypt.compare(password, user.password_hash);

    if (!isMatch) {
      logger.warn("Login failed: incorrect password", { userId: user.id });
      return res.status(401).json({ message: "Incorrect password" });
    }

    if (!isSuperAdmin && !user.is_verified) {
      logger.warn("Login blocked: email not verified", { userId: user.id });
      return res
        .status(403)
        .json({ message: "Please verify your email before logging in" });
    }

    if (!isSuperAdmin && !user.is_phone_verified) {
      logger.warn("Login blocked: phone not verified", { userId: user.id });
      return res.status(403).json({
        message: "Please verify your phone before logging in",
        email: user.email,
        phone: user.phone,
        country_code: user.country_code,
      });
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
        [user.id],
      );
      adminVerificationStatus = rows.length ? rows[0].status : "not_submitted";
    }

    const token = jwt.sign(
      { id: user.id, role: user.role },
      process.env.JWT_SECRET,
      {
        expiresIn: "7d",
      },
    );

    logger.info("Login successful", { userId: user.id, role: user.role });

    return res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        country_code: user.country_code,
        role: user.role,
        city: user.city,
        currency: user.currency,
        admin_verification_status: adminVerificationStatus,
      },
    });
  } catch (err) {
    logger.error("Login error", { email, error: err.message });
    return res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

/**
 * GET /api/auth/me
 */
router.get("/me", authMiddleware, async (req, res) => {
  try {
    const [users] = await pool.execute(
      `SELECT id, name, email, phone, country_code, role FROM users WHERE id = ?`,
      [req.user.id],
    );

    if (users.length === 0) {
      logger.warn("Fetch current user failed: user not found", {
        userId: req.user.id,
      });
      return res.status(404).json({ message: "User not found" });
    }

    let verificationStatus = null;
    if (users[0].role === "admin") {
      const [rows] = await pool.execute(
        `SELECT status FROM admin_verification_requests WHERE user_id = ?`,
        [req.user.id],
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
    logger.error("Fetch current user error", {
      userId: req.user.id,
      error: err.message,
    });
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
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
    await db.query("UPDATE users SET photo_url = ? WHERE id = ?", [
      photoUrl,
      userId,
    ]);

    res.json({ message: "Profile photo updated", photoUrl });
  } catch (err) {
    logger.error("Profile photo update failed", {
      userId,
      error: err.message,
    });

    res
      .status(500)
      .json({ message: "Something went wrong. Please try again." });
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
      [userId],
    );

    if (users.length === 0) {
      logger.warn("Password change failed: user not found", { userId });
      return res.status(404).json({ message: "User not found" });
    }

    const isValid = await bcrypt.compare(
      currentPassword,
      users[0].password_hash,
    );
    if (!isValid) {
      logger.warn("Password change failed: incorrect current password", {
        userId,
      });
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
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

module.exports = router;

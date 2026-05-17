/**
 * User Routes Module
 *
 * This module defines all user-related API routes for the Qurbani application.
 * It handles user profile management, admin verification, superadmin operations,
 * delivery management, and various user-specific functionalities.
 *
 * Routes are organized by functionality:
 * - Profile: User profile CRUD operations
 * - Admin Verification: Admin application and verification process
 * - Superadmin: Administrative user management
 * - Delivery: Delivery person operations
 * - Miscellaneous: Special requests, animal orders, etc.
 */

const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const supabase = require("../config/supabase");
const authMiddleware = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");
const bcrypt = require("bcryptjs");

const sanitizeText = (value) => (value == null ? "" : String(value).trim());

const normalizeEmail = (value) => sanitizeText(value).toLowerCase();

const isValidEmail = (value) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);

const requireCurrentPassword = async (userId, currentPassword) => {
  if (!currentPassword) {
    return "Current password is required";
  }

  const [users] = await pool.execute(
    "SELECT password_hash FROM users WHERE id = ?",
    [userId],
  );

  if (!users.length) {
    return "User not found";
  }

  const isValid = await bcrypt.compare(currentPassword, users[0].password_hash);
  return isValid ? null : "Current password is incorrect";
};


router.put("/superadmin/users/:id", authMiddleware, async (req, res) => {
  const { id: userId } = req.params;

  const {
    action,
    review_note,
  } = req.body;

  const superAdminId = req.user.id;

  try {

    /**
     * =====================================
     * VERIFY SUPER ADMIN
     * =====================================
     */
    const {
      data: superAdmin,
      error: superAdminError,
    } = await supabase
      .from("users")
      .select("role")
      .eq("id", superAdminId)
      .single();

    if (superAdminError) {
      throw new Error(superAdminError.message);
    }

    if (
      !superAdmin ||
      superAdmin.role !== "super_admin"
    ) {
      logger.warn(
        "Unauthorized superadmin access attempt",
        {
          superAdminId,
          targetUserId: userId,
          action,
        }
      );

      return res.status(403).json({
        message: "Access denied",
      });
    }

    /**
     * =====================================
     * VERIFY REQUEST EXISTS
     * =====================================
     */
    const {
      data: verificationRequest,
      error: requestError,
    } = await supabase
      .from("admin_verification_requests")
      .select("status")
      .eq("user_id", userId)
      .maybeSingle();

    if (requestError) {
      throw new Error(requestError.message);
    }

    if (!verificationRequest) {
      logger.warn(
        "Verification request not found",
        {
          superAdminId,
          targetUserId: userId,
        }
      );

      return res.status(404).json({
        message: "Verification request not found",
      });
    }

    /**
     * =====================================
     * APPROVE ADMIN
     * =====================================
     */
    if (action === "approve") {

      const {
        error: verificationUpdateError,
      } = await supabase
        .from("admin_verification_requests")
        .update({
          status: "approved",
          reviewed_by: superAdminId,
          review_note: review_note || null,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", userId);

      if (verificationUpdateError) {
        throw new Error(
          verificationUpdateError.message
        );
      }

      const {
        error: userUpdateError,
      } = await supabase
        .from("users")
        .update({
          role: "admin",
          admin_status: "approved",
        })
        .eq("id", userId);

      if (userUpdateError) {
        throw new Error(
          userUpdateError.message
        );
      }

      logger.info(
        "Admin verification approved",
        {
          superAdminId,
          targetUserId: userId,
        }
      );

      return res.json({
        message: "Admin approved successfully",
      });
    }

    /**
     * =====================================
     * REJECT ADMIN
     * =====================================
     */
    if (action === "reject") {

      const {
        error: verificationUpdateError,
      } = await supabase
        .from("admin_verification_requests")
        .update({
          status: "rejected",
          reviewed_by: superAdminId,
          review_note: review_note || null,
          updated_at: new Date().toISOString(),
        })
        .eq("user_id", userId);

      if (verificationUpdateError) {
        throw new Error(
          verificationUpdateError.message
        );
      }

      const {
        error: userUpdateError,
      } = await supabase
        .from("users")
        .update({
          admin_status: "rejected",
          role: "pending_admin",
        })
        .eq("id", userId);

      if (userUpdateError) {
        throw new Error(
          userUpdateError.message
        );
      }

      logger.info(
        "Admin verification rejected",
        {
          superAdminId,
          targetUserId: userId,
        }
      );

      return res.json({
        message: "Admin rejected successfully",
      });
    }

    /**
     * =====================================
     * INVALID ACTION
     * =====================================
     */
    return res.status(400).json({
      message: "Invalid action",
    });

  } catch (err) {

    logger.error(
      "Superadmin verification process failed",
      {
        superAdminId,
        targetUserId: userId,
        action,
        error: err.message,
        stack: err.stack,
      }
    );

    return res.status(500).json({
      message:
        "Something went wrong. Please try again later.",
    });
  }
});

/**
 * ===========================================
 * PROFILE MANAGEMENT ROUTES
 * ===========================================
 * Routes for managing user profile information including fetching and updating profile data.
 */

/**
 * @swagger
 * /api/profile:
 *   get:
 *     summary: Get authenticated user's profile
 *     tags: [Profile]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User profile data
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 profile:
 *                   type: object
 *                   properties:
 *                     name: { type: string }
 *                     email: { type: string }
 *                     phone: { type: string }
 *                     address: { type: string }
 *                     description: { type: string }
 *                     photoUrl: { type: string }
 *                     isAdmin: { type: boolean }
 *                     orderDeadline: { type: string, format: date-time }
 *       401:
 *         description: Unauthorized
 */

// GET /api/profile - Fetch authenticated user's profile
// Retrieves the current user's profile information from the database
router.get("/profile", authMiddleware, async (req, res) => {
  const userId = req.user.id;

  try {
    const { data: user, error } = await supabase
      .from("users")
      .select("*")
      .eq("id", userId)
      .single();

    if (error) {
      throw error;
    }

    if (!user) {
      logger.warn("Profile not found", { userId });

      return res.status(404).json({
        message: "User not found",
      });
    }

    logger.info("Profile fetched", { userId });

    res.json({
      profile: {
        ...user,
        isAdmin: user.role === "admin",
      },
    });
  } catch (err) {
    logger.error("Profile fetch failed", {
      userId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
});

/**
 * @swagger
 * /api/profile/currency:
 *   put:
 *     summary: Update user currency preference
 *     tags: [Profile]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [currency]
 *             properties:
 *               currency:
 *                 type: string
 *                 example: "USD"
 *     responses:
 *       200:
 *         description: Currency updated
 */

// PUT /api/profile - Update authenticated user's profile
router.put("/profile", authMiddleware, async (req, res) => {
  const userId = req.user.id;

  try {
    await pool.execute(
      "UPDATE users SET name=?, phone=?, address=?, description=?, photo_url=? WHERE id=?",
      [
        req.body.name,
        req.body.phone,
        req.body.address,
        req.body.description,
        req.body.photoUrl,
        userId,
      ],
    );

    logger.info("Profile updated", { userId });
    res.json({ message: "Profile updated successfully" });
  } catch (err) {
    logger.error("Profile update failed", {
      userId,
      error: err.message,
    });
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

router.put("/users/email", authMiddleware, async (req, res) => {
  const userId = req.user.id;
  const newEmail = normalizeEmail(req.body.newEmail || req.body.email);
  const currentPassword = req.body.currentPassword;

  try {
    if (!newEmail || !isValidEmail(newEmail)) {
      return res.status(400).json({ message: "Please enter a valid email address" });
    }

    const passwordError = await requireCurrentPassword(userId, currentPassword);
    if (passwordError) {
      const status = passwordError === "User not found" ? 404 : 400;
      return res.status(status).json({ message: passwordError });
    }

    const [currentRows] = await pool.execute(
      "SELECT email FROM users WHERE id = ?",
      [userId],
    );

    if (!currentRows.length) {
      return res.status(404).json({ message: "User not found" });
    }

    if (normalizeEmail(currentRows[0].email) === newEmail) {
      return res.status(400).json({ message: "New email must be different from current email" });
    }

    const [duplicates] = await pool.execute(
      "SELECT id FROM users WHERE email = ? AND id <> ? LIMIT 1",
      [newEmail, userId],
    );

    if (duplicates.length) {
      return res.status(409).json({ message: "This email is already registered" });
    }

    await pool.execute(
      "UPDATE users SET email = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
      [newEmail, userId],
    );

    const [updatedRows] = await pool.execute(
      "SELECT id, name, email, phone, country_code, role FROM users WHERE id = ?",
      [userId],
    );

    logger.info("Email updated", { userId });
    return res.json({
      message: "Email updated successfully",
      user: updatedRows[0],
      profile: updatedRows[0],
    });
  } catch (err) {
    logger.error("Email update failed", {
      userId,
      error: err.message,
      code: err.code,
    });

    if (err.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "This email is already registered" });
    }

    return res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

router.put("/users/phone", authMiddleware, async (req, res) => {
  const userId = req.user.id;
  const newPhone = sanitizeText(req.body.newPhone || req.body.phone);
  const countryCode = sanitizeText(req.body.countryCode || req.body.country_code);
  const currentPassword = req.body.currentPassword;

  try {
    if (!newPhone || !countryCode) {
      return res.status(400).json({ message: "Phone number and country code are required" });
    }

    const passwordError = await requireCurrentPassword(userId, currentPassword);
    if (passwordError) {
      const status = passwordError === "User not found" ? 404 : 400;
      return res.status(status).json({ message: passwordError });
    }

    const [currentRows] = await pool.execute(
      "SELECT phone, country_code FROM users WHERE id = ?",
      [userId],
    );

    if (!currentRows.length) {
      return res.status(404).json({ message: "User not found" });
    }

    if (
      sanitizeText(currentRows[0].phone) === newPhone &&
      sanitizeText(currentRows[0].country_code) === countryCode
    ) {
      return res.status(400).json({
        message: "New phone number must be different from current phone number",
      });
    }

    const [duplicates] = await pool.execute(
      "SELECT id FROM users WHERE country_code = ? AND phone = ? AND id <> ? LIMIT 1",
      [countryCode, newPhone, userId],
    );

    if (duplicates.length) {
      return res.status(409).json({ message: "This phone number is already registered" });
    }

    await pool.execute(
      "UPDATE users SET phone = ?, country_code = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
      [newPhone, countryCode, userId],
    );

    const [updatedRows] = await pool.execute(
      "SELECT id, name, email, phone, country_code, role FROM users WHERE id = ?",
      [userId],
    );

    logger.info("Phone updated", { userId });
    return res.json({
      message: "Phone number updated successfully",
      user: updatedRows[0],
      profile: updatedRows[0],
    });
  } catch (err) {
    logger.error("Phone update failed", {
      userId,
      error: err.message,
      code: err.code,
    });

    if (err.code === "ER_DUP_ENTRY") {
      return res.status(409).json({ message: "This phone number is already registered" });
    }

    return res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

/**
 * @swagger
 * /api/delivery/orders:
 *   get:
 *     summary: Fetch delivery person's orders
 *     tags: [Delivery]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Orders list
 */

// GET /api/delivery-boys - Fetch all delivery boys (users with role 'delivery')
router.get("/delivery-boys", authMiddleware, async (req, res) => {
  try {
    logger.info("Fetching delivery boys", {
      requestedBy: req.user?.id,
    });

    const { data: deliveryBoys, error } = await supabase
      .from("users")
      .select("id, name, phone, address")
      .eq("role", "delivery")
      .order("name", { ascending: true });

    if (error) {
      logger.error("Supabase fetch delivery boys error", {
        error: error.message,
      });

      return res.status(500).json({
        success: false,
        message: "Failed to fetch delivery boys",
      });
    }

    logger.info("Delivery boys fetched successfully", {
      count: deliveryBoys?.length || 0,
    });

    return res.status(200).json({
      success: true,
      count: deliveryBoys?.length || 0,
      deliveryBoys: deliveryBoys || [],
    });
  } catch (err) {
    logger.error("Unexpected error fetching delivery boys", {
      error: err.message,
      stack: err.stack,
    });

    return res.status(500).json({
      success: false,
      message: "Something went wrong. Please try again later.",
    });
  }
});


// ADMIN VERIFICATION ROUTES

/**
 * @swagger
 * /api/delivery/orders/{id}/status:
 *   put:
 *     summary: Update delivery status
 *     tags: [Delivery]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [status]
 *             properties:
 *               status:
 *                 type: string
 *                 enum: [pending, sent, delivered]
 *     responses:
 *       200:
 *         description: Status updated
 */

/**
 * @swagger
 * /api/delivery/orders/{id}/status:
 *   put:
 *     summary: Update delivery status
 *     tags: [Delivery]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [status]
 *             properties:
 *               status:
 *                 type: string
 *                 enum: [pending, sent, delivered]
 *     responses:
 *       200:
 *         description: Status updated
 */

/**
 * @swagger
 * /api/delivery/orders/{id}/verify:
 *   put:
 *     summary: Verify delivery code
 *     tags: [Delivery]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [code]
 *             properties:
 *               code:
 *                 type: string
 *                 example: "123456"
 *     responses:
 *       200:
 *         description: Order delivered
 */

/**
 * @swagger
 * /api/admin/verification:
 *   post:
 *     summary: Submit admin verification request
 *     tags: [Admin Verification]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               organization_name: { type: string }
 *               phone: { type: string }
 *               experience: { type: string }
 *               address: { type: string }
 *               govt_id_url: { type: string }
 *               business_proof_url: { type: string }
 *               bank_proof_url: { type: string }
 *               farm_photo_url: { type: string }
 *     responses:
 *       200:
 *         description: Verification submitted
 */

// POST /api/admin/verification - Submit admin verification request
// Allows users to apply for admin privileges by submitting detailed verification information
// Uses ON DUPLICATE KEY UPDATE to allow resubmissions of verification requests
const { v4: uuidv4 } = require("uuid");

router.post(
  "/admin/verification",
  authMiddleware,
  async (req, res) => {

    const userId = req.user.id;

    const verificationId =
      uuidv4();

    const {
      organization_name,
      phone,
      experience,
      address,
      govt_id_url,
      business_proof_url,
      bank_proof_url,
      farm_photo_url,
    } = req.body;

    const trimmedOrganizationName =
      organization_name?.trim();

    const trimmedPhone =
      phone?.trim();

    const trimmedExperience =
      experience?.trim();

    const trimmedAddress =
      address?.trim();

    const trimmedGovtIdUrl =
      govt_id_url?.trim();

    const trimmedBusinessProofUrl =
      business_proof_url?.trim();

    const trimmedBankProofUrl =
      bank_proof_url?.trim();

    const trimmedFarmPhotoUrl =
      farm_photo_url?.trim();

    if (
      !trimmedOrganizationName ||
      !trimmedPhone ||
      !trimmedGovtIdUrl ||
      !trimmedBusinessProofUrl ||
      !trimmedBankProofUrl ||
      !trimmedFarmPhotoUrl
    ) {

      logger.warn(
        "Admin verification blocked: missing required fields",
        {
          userId,
          hasOrganizationName:
            Boolean(
              trimmedOrganizationName
            ),

          hasPhone:
            Boolean(trimmedPhone),

          hasGovtIdUrl:
            Boolean(
              trimmedGovtIdUrl
            ),

          hasBusinessProofUrl:
            Boolean(
              trimmedBusinessProofUrl
            ),

          hasBankProofUrl:
            Boolean(
              trimmedBankProofUrl
            ),

          hasFarmPhotoUrl:
            Boolean(
              trimmedFarmPhotoUrl
            ),
        }
      );

      return res.status(400).json({
        message:
          "Please provide organization details and upload all required documents.",
      });
    }

    try {

      // Check if verification already exists
      const {
        data: existingVerification,
        error: fetchError,
      } = await supabase
        .from(
          "admin_verification_requests"
        )
        .select("id")
        .eq("user_id", userId)
        .maybeSingle();

      if (fetchError) {
        throw new Error(
          fetchError.message
        );
      }

      // UPDATE existing verification
      if (existingVerification) {

        const {
          error: updateError,
        } = await supabase
          .from(
            "admin_verification_requests"
          )
          .update({
            organization_name:
              trimmedOrganizationName,

            phone:
              trimmedPhone,

            experience:
              trimmedExperience ||
              null,

            address:
              trimmedAddress ||
              null,

            govt_id_url:
              trimmedGovtIdUrl,

            business_proof_url:
              trimmedBusinessProofUrl,

            bank_proof_url:
              trimmedBankProofUrl,

            farm_photo_url:
              trimmedFarmPhotoUrl,

            status: "pending",

            updated_at:
              new Date().toISOString(),
          })
          .eq("user_id", userId);

        if (updateError) {
          throw new Error(
            updateError.message
          );
        }

      } else {

        // INSERT new verification
        const {
          error: insertError,
        } = await supabase
          .from(
            "admin_verification_requests"
          )
          .insert([
            {
              id: verificationId,

              user_id: userId,

              organization_name:
                trimmedOrganizationName,

              phone:
                trimmedPhone,

              experience:
                trimmedExperience ||
                null,

              address:
                trimmedAddress ||
                null,

              govt_id_url:
                trimmedGovtIdUrl,

              business_proof_url:
                trimmedBusinessProofUrl,

              bank_proof_url:
                trimmedBankProofUrl,

              farm_photo_url:
                trimmedFarmPhotoUrl,

              status: "pending",
            },
          ]);

        if (insertError) {
          throw new Error(
            insertError.message
          );
        }
      }

      // Update user admin status
      const {
        error: userUpdateError,
      } = await supabase
        .from("users")
        .update({
          admin_status: "pending",
        })
        .eq("id", userId);

      if (userUpdateError) {
        throw new Error(
          userUpdateError.message
        );
      }

      logger.info(
        "Admin verification submitted",
        {
          userId,
          verificationId,
        }
      );

      return res.status(201).json({
        message:
          "Verification submitted for review",

        verification_id:
          verificationId,
      });

    } catch (err) {

      logger.error(
        "Admin verification failed",
        {
          userId,
          error: err.message,
          stack: err.stack,
        }
      );

      return res.status(500).json({
        message:
          "Something went wrong. Please try again later.",
      });
    }
  }
);

// ======================================================
// GET VERIFICATION STATUS
// ======================================================

router.get(
  "/verification/status",
  authMiddleware,
  async (req, res) => {

    const userId = req.user.id;

    try {

      const {
        data: verification,
        error,
      } = await supabase
        .from(
          "admin_verification_requests"
        )
        .select("status")
        .eq("user_id", userId)
        .maybeSingle();

      if (error) {
        throw new Error(error.message);
      }

      return res.json({
        status:
          verification?.status ||
          null,
      });

    } catch (err) {

      console.error(
        "Error fetching status:",
        err
      );

      return res.status(500).json({
        message:
          "Something went wrong. Please try again later.",
      });
    }
  }
);

// ======================================================
// SUPERADMIN - GET USERS
// ======================================================

router.get(
  "/superadmin/users",
  authMiddleware,
  async (req, res) => {

    const { role } = req.query;

    const superAdminId =
      req.user.id;

    try {

      // Verify super admin
      const {
        data: superAdmin,
        error: superAdminError,
      } = await supabase
        .from("users")
        .select("role")
        .eq("id", superAdminId)
        .maybeSingle();

      if (superAdminError) {
        throw new Error(
          superAdminError.message
        );
      }

      if (
        !superAdmin ||
        superAdmin.role !==
          "super_admin"
      ) {

        logger.warn(
          "Unauthorized superadmin access attempt",
          {
            userId:
              superAdminId,
            route:
              req.originalUrl,
          }
        );

        return res.status(403).json({
          message:
            "Access denied",
        });
      }

      // Allowed roles
      const allowedRoles = [
        "user",
        "admin",
        "delivery",
      ];

      // Fetch users
      let usersQuery =
        supabase
          .from("users")
          .select(`
            id,
            name,
            email,
            phone,
            role,
            admin_status,
            created_at
          `)
          .order("created_at", {
            ascending: false,
          });

      // Apply filtering
      if (
        role &&
        role !== "all"
      ) {

        if (
          !allowedRoles.includes(
            role
          )
        ) {

          return res.status(400).json({
            message:
              "Invalid role filter",
          });
        }

        if (role === "admin") {

          usersQuery =
            usersQuery.in(
              "role",
              [
                "admin",
                "pending_admin",
              ]
            );

        } else {

          usersQuery =
            usersQuery.eq(
              "role",
              role
            );
        }

      } else {

        usersQuery =
          usersQuery.in(
            "role",
            [
              "user",
              "admin",
              "delivery",
              "pending_admin",
            ]
          );
      }

      const {
        data: users,
        error: usersError,
      } = await usersQuery;

      if (usersError) {
        throw new Error(
          usersError.message
        );
      }

      // Fetch verification requests
      const userIds =
        users.map((u) => u.id);

      let verificationRows = [];

      if (userIds.length) {

        const {
          data,
          error,
        } = await supabase
          .from(
            "admin_verification_requests"
          )
          .select(`
            user_id,
            status
          `)
          .in("user_id", userIds);

        if (error) {
          throw new Error(
            error.message
          );
        }

        verificationRows =
          data || [];
      }

      // Create lookup map
      const verificationMap = {};

      verificationRows.forEach(
        (v) => {
          verificationMap[
            v.user_id
          ] = v.status;
        }
      );

      // Merge data
      const formattedUsers =
        users.map((user) => ({
          ...user,

          verification_status:
            verificationMap[
              user.id
            ] ||
            "not_submitted",
        }));

      return res.json({
        users:
          formattedUsers,
      });

    } catch (err) {

      console.error(
        "Error fetching users for superadmin:",
        err
      );

      return res.status(500).json({
        message:
          "Something went wrong. Please try again later.",
      });
    }
  }
);

/**
 * @swagger
 * /api/superadmin/users/{id}:
 *   put:
 *     summary: Approve or reject admin verification
 *     tags: [Super Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [action]
 *             properties:
 *               action:
 *                 type: string
 *                 enum: [approve, reject]
 *               review_note:
 *                 type: string
 *     responses:
 *       200:
 *         description: Action completed
 */

// PUT /api/superadmin/users/:id - Approve or reject admin verification requests
// This critical route allows superadmins to review and decide on admin verification applications
// Actions: 'approve' grants admin privileges, 'reject' denies the application
// Includes audit logging and status updates for both verification requests and user roles
router.post(
  "/admin/verification",
  authMiddleware,
  async (req, res) => {

    const userId = req.user.id;

    const verificationId = uuidv4();

    const {
      organization_name,
      phone,
      experience,
      address,
      govt_id_url,
      business_proof_url,
      bank_proof_url,
      farm_photo_url,
    } = req.body;

    const trimmedOrganizationName =
      organization_name?.trim();

    const trimmedPhone =
      phone?.trim();

    const trimmedExperience =
      experience?.trim();

    const trimmedAddress =
      address?.trim();

    const trimmedGovtIdUrl =
      govt_id_url?.trim();

    const trimmedBusinessProofUrl =
      business_proof_url?.trim();

    const trimmedBankProofUrl =
      bank_proof_url?.trim();

    const trimmedFarmPhotoUrl =
      farm_photo_url?.trim();

    if (
      !trimmedOrganizationName ||
      !trimmedPhone ||
      !trimmedGovtIdUrl ||
      !trimmedBusinessProofUrl ||
      !trimmedBankProofUrl ||
      !trimmedFarmPhotoUrl
    ) {

      logger.warn(
        "Admin verification blocked: missing required fields",
        {
          userId,
          hasOrganizationName:
            Boolean(trimmedOrganizationName),

          hasPhone:
            Boolean(trimmedPhone),

          hasGovtIdUrl:
            Boolean(trimmedGovtIdUrl),

          hasBusinessProofUrl:
            Boolean(trimmedBusinessProofUrl),

          hasBankProofUrl:
            Boolean(trimmedBankProofUrl),

          hasFarmPhotoUrl:
            Boolean(trimmedFarmPhotoUrl),
        }
      );

      return res.status(400).json({
        message:
          "Please provide organization details and upload all required documents.",
      });
    }

    try {

      // Check if verification already exists
      const {
        data: existingVerification,
        error: fetchError,
      } = await supabase
        .from("admin_verification_requests")
        .select("id")
        .eq("user_id", userId)
        .maybeSingle();

      if (fetchError) {
        throw new Error(fetchError.message);
      }

      // UPDATE existing verification
      if (existingVerification) {

        const {
          error: updateError,
        } = await supabase
          .from("admin_verification_requests")
          .update({
            organization_name:
              trimmedOrganizationName,

            phone:
              trimmedPhone,

            experience:
              trimmedExperience || null,

            address:
              trimmedAddress || null,

            govt_id_url:
              trimmedGovtIdUrl,

            business_proof_url:
              trimmedBusinessProofUrl,

            bank_proof_url:
              trimmedBankProofUrl,

            farm_photo_url:
              trimmedFarmPhotoUrl,

            status: "pending",

            updated_at:
              new Date().toISOString(),
          })
          .eq("user_id", userId);

        if (updateError) {
          throw new Error(updateError.message);
        }

      } else {

        // INSERT new verification
        const {
          error: insertError,
        } = await supabase
          .from("admin_verification_requests")
          .insert([
            {
              id: verificationId,

              user_id: userId,

              organization_name:
                trimmedOrganizationName,

              phone:
                trimmedPhone,

              experience:
                trimmedExperience || null,

              address:
                trimmedAddress || null,

              govt_id_url:
                trimmedGovtIdUrl,

              business_proof_url:
                trimmedBusinessProofUrl,

              bank_proof_url:
                trimmedBankProofUrl,

              farm_photo_url:
                trimmedFarmPhotoUrl,

              status: "pending",
            },
          ]);

        if (insertError) {
          throw new Error(insertError.message);
        }
      }

      // Update user admin status
      const {
        error: userUpdateError,
      } = await supabase
        .from("users")
        .update({
          admin_status: "pending",
        })
        .eq("id", userId);

      if (userUpdateError) {
        throw new Error(userUpdateError.message);
      }

      logger.info(
        "Admin verification submitted",
        {
          userId,
          verificationId,
        }
      );

      return res.status(201).json({
        message:
          "Verification submitted for review",

        verification_id:
          verificationId,
      });

    } catch (err) {

      logger.error(
        "Admin verification failed",
        {
          userId,
          error: err.message,
          stack: err.stack,
        }
      );

      return res.status(500).json({
        message:
          "Something went wrong. Please try again later.",
      });
    }
  }
);

/**
 * @swagger
 * /api/superadmin/verifications/{adminId}:
 *   get:
 *     summary: Get admin verification details
 *     tags: [Super Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: adminId
 *         required: true
 *     responses:
 *       200:
 *         description: Verification details
 */

// GET /api/superadmin/verifications/:adminId - Fetch verification details
router.get(
  "/superadmin/verifications/:adminId",
  authMiddleware,
  async (req, res) => {

    const { adminId } = req.params;

    const superAdminId =
      req.user.id;

    try {

      // Verify super admin
      const {
        data: superAdmin,
        error: superAdminError,
      } = await supabase
        .from("users")
        .select("role")
        .eq("id", superAdminId)
        .maybeSingle();

      if (superAdminError) {
        throw new Error(
          superAdminError.message
        );
      }

      if (
        !superAdmin ||
        superAdmin.role !==
          "super_admin"
      ) {

        logger.warn(
          "Unauthorized superadmin verification access",
          {
            superAdminId,
            targetAdminId:
              adminId,
          }
        );

        return res.status(403).json({
          message:
            "Access denied",
        });
      }

      logger.info(
        "Superadmin fetching verification",
        {
          superAdminId,
          targetAdminId:
            adminId,
        }
      );

      const {
        data: verification,
        error: verificationError,
      } = await supabase
        .from(
          "admin_verification_requests"
        )
        .select("*")
        .eq("user_id", adminId)
        .maybeSingle();

      if (verificationError) {
        throw new Error(
          verificationError.message
        );
      }

      if (!verification) {

        logger.warn(
          "Verification not found",
          {
            superAdminId,
            targetAdminId:
              adminId,
          }
        );

        return res.status(404).json({
          message:
            "No verification found",
        });
      }

      return res.json({
        verification,
      });

    } catch (err) {

      logger.error(
        "Failed to fetch admin verification",
        {
          superAdminId,
          targetAdminId:
            adminId,
          error:
            err.message,
          stack:
            err.stack,
        }
      );

      return res.status(500).json({
        message:
          "Something went wrong. Please try again later.",
      });
    }
  }
);

/**
 * GET /api/superadmin/users/:id
 * Fetch full user profile for super admin
 */
router.get("/superadmin/users/:id", authMiddleware, async (req, res) => {
  const { id: targetUserId } = req.params;
  const superAdminId = req.user.id;

  try {
    // if (!(await ensureSuperAdmin(superAdminId))) {
    //   return res.status(403).json({ message: "Access denied" });
    // }

    const [users] = await pool.execute(
      `
      SELECT
        id,
        name,
        email,
        phone,
        address,
        role,
        description,
        photo_url,
        created_at
      FROM users
      WHERE id = ?
      `,
      [targetUserId]
    );

    if (!users.length) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json({ user: users[0] });
  } catch (err) {
    logger.error("Superadmin user profile fetch failed", {
      targetUserId,
      error: err.message,
    });
    res.status(500).json({ message: "Something went wrong" });
  }
});

/**
 * GET /api/superadmin/users/:id/orders
 * Fetch all orders taken by a user/admin
 */
router.get(
  "/superadmin/users/:id/orders",
  authMiddleware,
  async (req, res) => {
    const { id: targetUserId } = req.params;
    const superAdminId = req.user.id;

    try {
      // if (!(await ensureSuperAdmin(superAdminId))) {
      //   return res.status(403).json({ message: "Access denied" });
      // }

      const [orders] = await pool.execute(
        `
        SELECT
          o.id,
          o.payment_status,
          o.processing_status,
          o.delivery_status,
          o.created_at,

          u.name AS customer_name,
          a.name AS admin_name,
          d.name AS delivery_person

        FROM orders o
        JOIN users u ON u.id = o.user_id
        JOIN users a ON a.id = o.admin_id
        LEFT JOIN users d ON d.id = o.delivery_person_id

        WHERE
          o.user_id = ?
          OR o.admin_id = ?
          OR o.delivery_person_id = ?

        ORDER BY o.created_at DESC
        `,
        [targetUserId, targetUserId, targetUserId]
      );

      res.json({ orders });
    } catch (err) {
      logger.error("Superadmin user orders fetch failed", {
        targetUserId,
        error: err.message,
      });
      res.status(500).json({ message: "Something went wrong" });
    }
  }
);


// GET /api/delivery/orders - Fetch orders for delivery person
router.get("/delivery/orders", authMiddleware, async (req, res) => {
  const deliveryPersonId = req.user.id;

  try {
    const [orders] = await pool.execute(
      `
      SELECT
        o.id,
        o.delivery_status,
        o.delivery_code,
        o.payment_status,
        o.processing_status,
        o.created_at,

        -- customer info
        u.name AS customer_name,
        u.phone AS customer_phone,
        u.address AS delivery_address,

        -- admin/seller info
        a.name AS admin_name,
        a.phone AS admin_contact

      FROM orders o
      JOIN users u ON u.id = o.user_id
      JOIN users a ON a.id = o.admin_id

      WHERE o.delivery_person_id = ?
      ORDER BY o.created_at DESC
      `,
      [deliveryPersonId],
    );
    logger.info("Delivery orders fetched", {
      deliveryPersonId,
      count: orders.length,
    });
    res.json({ orders });
  } catch (err) {
    logger.error("Failed to fetch delivery orders", {
      deliveryPersonId,
      error: err.message,
    });
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

// PUT /api/delivery/orders/:id/status - Update delivery status with business logic
// This route handles the complex delivery workflow with different status transitions:
// - "sent": Generates a 6-digit verification code and marks order as sent to customer
// - "delivered": Marks order as delivered and clears the verification code
// Includes security checks to ensure only assigned delivery persons can update orders
router.put("/delivery/orders/:id/status", authMiddleware, async (req, res) => {
  // Extract order ID from URL parameters and new status from request body
  const { id } = req.params;
  const { status } = req.body;
  const deliveryPersonId = req.user.id; // Authenticated delivery person's ID

  try {
    // Initialize the base update query and parameters array
    let updateQuery = `UPDATE orders SET delivery_status = ?`;
    let params = [status];

    // Handle different status transitions with specific business logic
    if (status === "sent") {
      // When marking as "sent", generate a random 6-digit verification code
      // This code will be used by the customer to confirm delivery receipt
      const code = Math.floor(100000 + Math.random() * 900000).toString();
      updateQuery += `, delivery_code = ?`;
      params.push(code);
      // TODO: Implement notification logic here (SMS/email to customer with code)
      // This would typically involve calling a notification service
    } else if (status === "delivered") {
      // When marking as "delivered", set delivery timestamp and clear verification code
      // This prevents further verification attempts and records completion time
      updateQuery += `, delivered_at = NOW(), delivery_code = NULL`;
    }

    // Add security constraints: only the assigned delivery person can update this order
    updateQuery += ` WHERE id = ? AND delivery_person_id = ?`;
    params.push(id, deliveryPersonId);

    // Execute the update query
    const [result] = await pool.execute(updateQuery, params);

    // Check if the update affected any rows (security/authorization check)
    if (result.affectedRows === 0) {
      logger.warn("Unauthorized delivery status update attempt", {
        orderId: id,
        deliveryPersonId,
        attemptedStatus: status,
      });
      return res
        .status(404)
        .json({ message: "Order not found or not assigned to you" });
    }

    // Log successful status update for audit trail
    logger.info("Delivery status updated", {
      orderId: id,
      deliveryPersonId,
      newStatus: status,
      verificationCode: status === "sent" ? params[1] : null,
    });

    // Return success response with verification code if applicable
    res.json({
      message: "Status updated successfully",
      code: status === "sent" ? params[1] : null, // Return code for "sent" status
    });
  } catch (err) {
    logger.error("Delivery status update failed", {
      orderId: id,
      deliveryPersonId,
      attemptedStatus: status,
      error: err.message,
      stack: err.stack,
    });
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

// PUT /api/delivery/orders/:id/verify - Verify delivery code and complete order
// This route allows delivery persons to confirm successful delivery by entering the verification code
// The code was previously generated when the order status was set to "sent"
// Upon successful verification, the order is marked as fully delivered
router.put("/delivery/orders/:id/verify", authMiddleware, async (req, res) => {
  // Extract order ID from URL and verification code from request body
  const { id } = req.params;
  const { code } = req.body;
  // Get the authenticated delivery person's ID
  const deliveryPersonId = req.user.id;

  try {
    // Step 1: Retrieve the stored verification code for this order
    // Security check ensures only the assigned delivery person can verify their orders
    const [orders] = await pool.execute(
      `SELECT delivery_code FROM orders WHERE id = ? AND delivery_person_id = ?`,
      [id, deliveryPersonId],
    );

    // Step 2: Validate the verification code
    // Check if order exists and if the provided code matches the stored code
    if (!orders.length || orders[0].delivery_code !== code) {
      logger.warn("Invalid delivery code verification attempt", {
        orderId: id,
        deliveryPersonId,
        providedCode: code,
      });
      return res.status(400).json({ message: "Invalid verification code" });
    }

    // Step 3: Complete the delivery process
    // Update order status to 'delivered' and clear the verification code
    // This prevents further verification attempts and marks the order as complete
    await pool.execute(
      `UPDATE orders SET delivery_status = 'delivered' WHERE id = ?`,
      [id],
    );

    // Step 4: Log successful delivery completion for audit trail
    logger.info("Delivery successfully verified and completed", {
      orderId: id,
      deliveryPersonId,
      verificationCode: code,
    });

    // Return success response
    res.json({ message: "Order delivery verified and completed successfully" });
  } catch (err) {
    // Log error with context for debugging
    logger.error("Delivery verification process failed", {
      orderId: id,
      deliveryPersonId,
      error: err.message,
      stack: err.stack,
    });
    // Return generic error to client
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

// PUT /api/profile/currency
// router.put("/profile/currency", authMiddleware, async (req, res) => {
//   const { currency } = req.body;
//   const userId = req.user.id;

//   try {
//     await pool.execute(`UPDATE users SET currency = ? WHERE id = ?`, [
//       currency,
//       userId,
//     ]);
//     logger.info("Currency updated", { userId });
//     res.json({ message: "Currency updated" });
//   } catch (err) {
//     logger.error("Currency update failed", {
//       userId,
//       error: err.message,
//     });
//     res.status(500).json({ message: "Something went wrong. Please try again later." });
//   }
// });

// GET /api/special-requests - Fetch user's special requests
router.get("/special-requests", authMiddleware, async (req, res) => {
  const userId = req.user.id;

  try {
    const [requests] = await pool.execute(
      `SELECT id, title, description, status, created_at, reply_message, replied_at FROM requests WHERE user_id = ? ORDER BY created_at DESC`,
      [userId],
    );

    logger.info("Special requests fetched", {
      userId,
      count: requests.length,
    });

    res.json({ requests });
  } catch (err) {
    logger.error("Failed to fetch special requests", {
      userId,
      error: err.message,
    });
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

// GET /api/animals/:animalId/orders - Get Orders for Animal (assuming animalId is name or id; adjust query)
router.get("/animals/:animalId/orders", authMiddleware, async (req, res) => {
  const { animalId } = req.params;

  console.log("Fetching orders for animal:", animalId);

  try {
    // Assuming animalId is the animal name; if it's ID, change to WHERE s.animal_id = ?
    const [orders] = await pool.execute(
      `SELECT o.id, o.user_id, o.admin_id, o.total_amount, o.created_at FROM orders o JOIN shareholders s ON o.id = s.order_id WHERE s.animal = ?`,
      [animalId],
    );

    logger.info("Animal orders fetched", {
      animalId,
      count: orders.length,
    });


    res.json({ orders });
  } catch (err) {
    logger.error("Failed to fetch animal orders", {
      animalId,
      error: err.message,
    });
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

const controller = require("../controllers/admin_payment_settings");

// User order page
router.get(
  "/admins/:adminId/payment-settings",
  controller.getAdminPaymentSettingsPublic,
);

module.exports = router;

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
const authMiddleware = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");

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
    const [users] = await pool.execute(
      "SELECT name, email, phone, address, description, role, order_deadline, photo_url, currency FROM users WHERE id = ?",
      [userId],
    );

    if (!users.length) {
      logger.warn("Profile not found", { userId });
      return res.status(404).json({ message: "User not found" });
    }

    logger.info("Profile fetched", { userId });

    res.json({ profile: { ...users[0], isAdmin: users[0].role === "admin" } });
  } catch (err) {
    logger.error("Profile fetch failed", {
      userId,
      error: err.message,
      stack: err.stack,
    });
    res.status(500).json({ message: "Something went wrong. Please try again later." });
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
      "UPDATE users SET name=?, phone=?, address=?, description=?, order_deadline=?, photo_url=? WHERE id=?",
      [
        req.body.name,
        req.body.phone,
        req.body.address,
        req.body.description,
        req.body.orderDeadline,
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
    const [deliveryBoys] = await pool.execute(
      `SELECT id, name, phone, address FROM users WHERE role = 'delivery'`,
      [],
    );
    res.json({ deliveryBoys });
  } catch (err) {
    console.error("Error fetching delivery boys:", err);
    res.status(500).json({ message: "Something went wrong. Please try again later." });
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

router.post("/admin/verification", authMiddleware, async (req, res) => {
  // Extract the authenticated user's ID from the JWT token
  const userId = req.user.id;

  // Generate a unique verification request ID using UUID v4
  const verificationId = uuidv4();

  // Destructure verification details from request body
  // These include organization info, contact details, and document URLs
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

  const trimmedOrganizationName = organization_name?.trim();
  const trimmedPhone = phone?.trim();
  const trimmedExperience = experience?.trim();
  const trimmedAddress = address?.trim();
  const trimmedGovtIdUrl = govt_id_url?.trim();
  const trimmedBusinessProofUrl = business_proof_url?.trim();
  const trimmedBankProofUrl = bank_proof_url?.trim();
  const trimmedFarmPhotoUrl = farm_photo_url?.trim();

  if (
    !trimmedOrganizationName ||
    !trimmedPhone ||
    !trimmedGovtIdUrl ||
    !trimmedBusinessProofUrl ||
    !trimmedBankProofUrl ||
    !trimmedFarmPhotoUrl
  ) {
    logger.warn("Admin verification blocked: missing required fields", {
      userId,
      hasOrganizationName: Boolean(trimmedOrganizationName),
      hasPhone: Boolean(trimmedPhone),
      hasGovtIdUrl: Boolean(trimmedGovtIdUrl),
      hasBusinessProofUrl: Boolean(trimmedBusinessProofUrl),
      hasBankProofUrl: Boolean(trimmedBankProofUrl),
      hasFarmPhotoUrl: Boolean(trimmedFarmPhotoUrl),
    });

    return res.status(400).json({
      message:
        "Please provide organization details and upload all required documents.",
    });
  }

  try {
    // Insert or update admin verification request in database
    // ON DUPLICATE KEY UPDATE allows users to resubmit their application
    // This is useful if they need to correct information or reapply
    await pool.execute(
      `
      INSERT INTO admin_verification_requests
      (
        id,
        user_id,
        organization_name,
        phone,
        experience,
        address,
        govt_id_url,
        business_proof_url,
        bank_proof_url,
        farm_photo_url,
        status
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
      ON DUPLICATE KEY UPDATE
        organization_name = VALUES(organization_name),
        phone = VALUES(phone),
        experience = VALUES(experience),
        address = VALUES(address),
        govt_id_url = VALUES(govt_id_url),
        business_proof_url = VALUES(business_proof_url),
        bank_proof_url = VALUES(bank_proof_url),
        farm_photo_url = VALUES(farm_photo_url),
        status = 'pending',
        updated_at = NOW()
      `,
      [
        verificationId,
        userId,
        trimmedOrganizationName,
        trimmedPhone,
        trimmedExperience || null,
        trimmedAddress || null,
        trimmedGovtIdUrl,
        trimmedBusinessProofUrl,
        trimmedBankProofUrl,
        trimmedFarmPhotoUrl,
      ]
    );

    await pool.execute("UPDATE users SET admin_status = 'pending' WHERE id = ?", [
      userId,
    ]);

    logger.info("Admin verification submitted", {
      userId,
      verificationId,
    });

    res.status(201).json({
      message: "Verification submitted for review",
      verification_id: verificationId,
    });
  } catch (err) {
    logger.error("Admin verification failed", {
      userId,
      error: err.message,
      stack: err.stack,
    });

    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});


/**
 * @swagger
 * /api/verification/status:
 *   get:
 *     summary: Get admin verification status
 *     tags: [Admin Verification]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Verification status
 */

// GET /api/admin/verification/status - Check verification status
router.get("/verification/status", authMiddleware, async (req, res) => {
  const userId = req.user.id;

  try {
    const [verifications] = await pool.execute(
      `SELECT status FROM admin_verification_requests WHERE user_id = ?`,
      [userId],
    );
    if (verifications.length === 0) {
      return res.json({ status: null });
    }
    res.json({ status: verifications[0].status });
  } catch (err) {
    console.error("Error fetching status:", err);
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

// SUPERADMIN ROUTES

/**
 * @swagger
 * /api/superadmin/users:
 *   get:
 *     summary: List users by role
 *     tags: [Super Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: role
 *         schema:
 *           type: string
 *           enum: [all, user, admin, delivery]
 *     responses:
 *       200:
 *         description: Users list
 */

// GET /api/superadmin/users - List users by role (for super admin)
// This endpoint provides superadmins with a comprehensive view of all users in the system
// Supports filtering by user roles and includes verification status information
// Used for administrative oversight and user management purposes
router.get("/superadmin/users", authMiddleware, async (req, res) => {
  // Extract role filter from query parameters (optional)
  // Valid values: 'all', 'user', 'admin', 'delivery'
  const { role } = req.query;
  // Get the authenticated superadmin's ID for authorization
  const superAdminId = req.user.id;

  try {
    // Step 1: Verify superadmin privileges
    // This is a critical security check to ensure only superadmins can access user lists
    const [superAdmins] = await pool.execute(
      `SELECT role FROM users WHERE id = ?`,
      [superAdminId],
    );

    // Deny access if user doesn't exist or isn't a superadmin
    if (!superAdmins.length || superAdmins[0].role !== "super_admin") {
      logger.warn("Unauthorized superadmin access attempt", {
        userId: superAdminId,
        route: req.originalUrl,
      });
      return res.status(403).json({ message: "Access denied" });
    }

    // Step 2: Build dynamic query with optional role filtering
    // Base query joins users table with admin_verification_requests to show verification status
    // Uses LEFT JOIN to include users who haven't submitted verification requests
    let query = `
      SELECT
        u.id,
        u.name,
        u.email,
        u.phone,
        u.role,
        u.admin_status,
        u.created_at,
        COALESCE(avr.status, 'not_submitted') AS verification_status
      FROM users u
      LEFT JOIN admin_verification_requests avr
        ON avr.user_id = u.id
      WHERE 1 = 1
    `;

    // Initialize parameters array for prepared statement
    const params = [];

    // Step 3: Apply role-based filtering if specified
    // Only allow filtering by the three main user roles
    if (role && role !== "all") {
      const allowedRoles = ["user", "admin", "delivery"];
      // Validate that the requested role is allowed
      if (!allowedRoles.includes(role)) {
        return res.status(400).json({ message: "Invalid role filter" });
      }

      if (role === "admin") {
        query += ` AND (u.role = 'admin' OR u.role = 'pending_admin')`;
      } else {
        query += ` AND u.role = ?`;
        params.push(role);
      }
    } else {
      query += ` AND (
        u.role IN ('user', 'admin', 'delivery')
        OR u.role = 'pending_admin'
      )`;
    }

    // Order results by creation date (newest first) for better UX
    query += ` ORDER BY u.created_at DESC`;

    // Execute the query with prepared parameters for security
    const [users] = await pool.execute(query, params);

    // Return the filtered user list
    res.json({ users });
  } catch (err) {
    // Log the error with context for debugging
    console.error("Error fetching users for superadmin:", err);
    // Return generic error message to client
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

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
router.put("/superadmin/users/:id", authMiddleware, async (req, res) => {
  // Extract target user ID from URL parameters and action details from request body
  const { id: userId } = req.params;
  const { action, review_note } = req.body; // action can be 'approve' or 'reject'
  const superAdminId = req.user.id; // ID of the superadmin performing the action

  try {
    // Step 1: Verify that the requester is indeed a superadmin
    // This is a critical security check to prevent unauthorized access
    const [superAdmins] = await pool.execute(
      `SELECT role FROM users WHERE id = ?`,
      [superAdminId],
    );

    // If user doesn't exist or doesn't have super_admin role, deny access
    if (!superAdmins.length || superAdmins[0].role !== "super_admin") {
      logger.warn("Unauthorized superadmin access attempt", {
        superAdminId,
        targetUserId: userId,
        action,
      });
      return res.status(403).json({ message: "Access denied" });
    }

    // Step 2: Verify that a verification request exists for the target user
    // This prevents processing actions on users who haven't applied for admin status
    const [requests] = await pool.execute(
      `SELECT status FROM admin_verification_requests WHERE user_id = ?`,
      [userId],
    );

    // If no verification request found, return error
    if (!requests.length) {
      logger.warn("Verification request not found", {
        superAdminId,
        targetUserId: userId,
      });

      return res
        .status(404)
        .json({ message: "Verification request not found" });
    }

    // APPROVE
    if (action === "approve") {
      await pool.execute(
        `UPDATE admin_verification_requests
         SET status = 'approved',
             reviewed_by = ?,
             review_note = ?,
             updated_at = NOW()
         WHERE user_id = ?`,
        [superAdminId, review_note || null, userId],
      );

      await pool.execute(
        `UPDATE users
         SET role = 'admin',
             admin_status = 'approved'
         WHERE id = ?`,
        [userId],
      );

      logger.info("Admin verification approved", {
        superAdminId,
        targetUserId: userId,
      });

      return res.json({ message: "Admin approved successfully" });
    }

    // REJECT
    if (action === "reject") {
      console.log("rejecting process begins");
      await pool.execute(
        `UPDATE admin_verification_requests
         SET status = 'rejected',
             reviewed_by = ?,
             review_note = ?,
             updated_at = NOW()
         WHERE user_id = ?`,
        [superAdminId, review_note || null, userId],
      );

      await pool.execute(
        `UPDATE users
         SET admin_status = 'rejected',
             role = 'pending_admin'
         WHERE id = ?`,
        [userId],
      );

      logger.info("Admin verification rejected", {
        superAdminId,
        targetUserId: userId,
      });

      return res.json({ message: "Admin rejected successfully" });
    }

    return res.status(400).json({ message: "Invalid action" });
  } catch (err) {
    logger.error("Superadmin verification process failed", {
      superAdminId,
      targetUserId: userId,
      action,
      error: err.message,
      stack: err.stack,
    });
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

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
    const superAdminId = req.user.id;

    try {
      const [superAdmins] = await pool.execute(
        `SELECT role FROM users WHERE id = ?`,
        [superAdminId],
      );

      if (!superAdmins.length || superAdmins[0].role !== "super_admin") {
        logger.warn("Unauthorized superadmin verification access", {
          superAdminId,
          targetAdminId: adminId,
        });
        return res.status(403).json({ message: "Access denied" });
      }

      logger.info("Superadmin fetching verification", {
        superAdminId,
        targetAdminId: adminId,
      });

      const [verifications] = await pool.execute(
        `SELECT * FROM admin_verification_requests WHERE user_id = ?`,
        [adminId],
      );

      if (!verifications.length) {
        logger.warn("Verification not found", {
          superAdminId,
          targetAdminId: adminId,
        });
        return res.status(404).json({ message: "No verification found" });
      }

      res.json({ verification: verifications[0] });
    } catch (err) {
      logger.error("Failed to fetch admin verification", {
        superAdminId,
        targetAdminId: adminId,
        error: err.message,
        stack: err.stack,
      });
      res.status(500).json({ message: "Something went wrong. Please try again later." });
    }
  },
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

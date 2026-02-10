const express = require("express");
const { fetchVerifiedAdmins } = require("../controllers/marketplaceAdmin");
const authMiddleware = require("../middleware/authmiddleware");
const pool = require("../config/db");
const logger = require("../middleware/logger");
const { saveVendorShareSetup } = require("../controllers/admin_share_setup");
const router = express.Router();

router.post("/share-setup", authMiddleware, saveVendorShareSetup);

/**
 * GET admin share pricing & payment settings
 * GET /admins/:adminId/share-pricing
 */
router.get("/:adminId/share-pricing", authMiddleware, async (req, res) => {
  const { adminId } = req.params;
  console.log("Fetching share pricing for admin:", adminId);
  try {
    const [[pricing]] = await pool.query(
      `
      SELECT
        s.total_shares,
        s.price_per_share,
        s.late_booking_fee,
        s.last_booking_date,
        s.delivery_type,
        s.delivery_fee,
        s.free_delivery_threshold,
        s.currency,
        s.is_active,

        p.allow_cod,
        p.allow_online,
        p.cod_deadline
      FROM admin_share_setups s
      LEFT JOIN admin_payment_settings p
        ON p.admin_id = s.admin_id
      WHERE s.admin_id = ?
        AND s.is_active = 1
      LIMIT 1
      `,
      [adminId],
    );

    if (!pricing) {
      return res.status(404).json({
        message: "Share pricing not configured for this admin",
      });
    }

    return res.json(pricing);
  } catch (err) {
    console.error("Failed to fetch admin pricing:", err);
    return res.status(500).json({
      message: "Failed to load pricing",
    });
  }
});

router.get("/:adminId/order-config", authMiddleware, async (req, res) => {
  try {
    const { adminId } = req.params;

    const [rows] = await pool.query(
      `
  SELECT
    s.admin_id,
    s.total_shares,
    s.price_per_share,
    s.late_booking_fee,
    s.last_booking_date,
    s.delivery_type,
    s.delivery_fee,
    s.free_delivery_threshold,
    s.currency,
    IFNULL(SUM(o.total_shares), 0) AS used_shares,
    (s.total_shares - IFNULL(SUM(o.total_shares), 0)) AS remaining_shares
  FROM admin_share_setups s
  LEFT JOIN orders o
    ON o.admin_id = s.admin_id
    AND o.status IN ('confirmed', 'paid')
  WHERE s.admin_id = ?
    AND s.is_active = 1
  GROUP BY
    s.admin_id,
    s.total_shares,
    s.price_per_share,
    s.late_booking_fee,
    s.last_booking_date,
    s.delivery_type,
    s.delivery_fee,
    s.free_delivery_threshold,
    s.currency
  `,
      [adminId],
    );
    console.log("👀 ORDER CONFIG:", rows);

    if (!rows.length) {
      return res.status(404).json({ message: "Order config not found" });
    }

    res.json(rows[0]);
  } catch (err) {
    console.error("[ORDER CONFIG]", err);
    res.status(500).json({ message: "Server error" });
  }
});

router.post("/sync-delivery-requests", authMiddleware, async (req, res) => {
  const adminId = req.user.id;

  try {
    // Get admin location
    const [[admin]] = await pool.query(
      `
      SELECT country, state, city
      FROM users
      WHERE id = ? AND role = 'admin'
      `,
      [adminId],
    );

    console.log("🧑 ADMIN FROM DB:", admin);
    console.log("🧑 ADMIN ID:", adminId);

    if (!admin || !admin.country) {
      return res.status(200).json({ message: "Admin has no location" });
    }

    const { country, state, city } = admin;

    console.log("📍 SYNC PARAMS:", {
      country,
      state,
      city,
      adminId,
    });

    const [matches] = await pool.query(
      `
  SELECT
    d.id AS delivery_id,
    d.country,
    d.state,
    d.city
  FROM users d
  WHERE d.role = 'delivery'
    AND d.country = ?
    AND d.state <=> ?
    AND d.city <=> ?
    AND NOT EXISTS (
      SELECT 1
      FROM delivery_requests dr
      WHERE dr.delivery_user_id = d.id
        AND dr.admin_user_id = ?
    )
  `,
      [country, state, city, adminId],
    );

    console.log("🚚 MATCHING DELIVERY USERS:", matches);

    // Insert missing delivery requests
    await pool.query(
      `
      INSERT INTO delivery_requests (
        id,
        delivery_user_id,
        admin_user_id,
        country,
        state,
        city
      )
      SELECT
        UUID(),
        d.id,
        ?,
        d.country,
        d.state,
        d.city
      FROM users d
      WHERE d.role = 'delivery'
        AND d.country = ?
        AND d.state <=> ?
        AND d.city <=> ?
        AND NOT EXISTS (
          SELECT 1
          FROM delivery_requests dr
          WHERE dr.delivery_user_id = d.id
            AND dr.admin_user_id = ?
        )
      `,
      [adminId, country, state, city, adminId],
    );

    return res.json({ message: "Delivery requests synced" });
  } catch (err) {
    console.error("Sync failed", err);
    return res.status(500).json({ message: "Sync failed" });
  }
});

/**
 * @swagger
 * /api/admin/verified:
 *   get:
 *     summary: Fetch verified admins for marketplace
 *     description: Public endpoint to list all verified admins available in marketplace.
 *     tags: [Marketplace]
 *     responses:
 *       200:
 *         description: List of verified admins
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   id:
 *                     type: string
 *                   name:
 *                     type: string
 *                   email:
 *                     type: string
 *                   phone:
 *                     type: string
 *                   city:
 *                     type: string
 *       500:
 *         description: Something went wrong. Please try again later.
 */

/**
 * PUBLIC – Fetch verified admins
 */
router.get("/verified", fetchVerifiedAdmins);

/**
 * @swagger
 * /api/admin/dashboard-stats:
 *   get:
 *     summary: Get admin dashboard statistics
 *     description: Returns quick statistics for admin dashboard including animals, orders, and requests.
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Dashboard statistics fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 animals:
 *                   type: integer
 *                   example: 12
 *                 orders:
 *                   type: integer
 *                   example: 45
 *                 requests:
 *                   type: integer
 *                   example: 7
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Something went wrong. Please try again later.
 */

// GET /api/admin/dashboard-stats - Fetch quick stats for admin dashboard
router.get("/dashboard-stats", authMiddleware, async (req, res) => {
  const adminId = req.user.id;

  logger.info("Fetching admin dashboard stats", { adminId });

  try {
    const [animalResult] = await pool.execute(
      "SELECT COUNT(*) AS count FROM animals WHERE admin_id = ?",
      [adminId],
    );

    const [orderResult] = await pool.execute(
      "SELECT COUNT(*) AS count FROM orders WHERE admin_id = ?",
      [adminId],
    );

    const [requestResult] = await pool.execute(
      `SELECT COUNT(*) AS count 
       FROM requests r 
       JOIN orders o ON r.order_id = o.id 
       WHERE o.admin_id = ?`,
      [adminId],
    );

    const stats = {
      animals: animalResult[0].count,
      orders: orderResult[0].count,
      requests: requestResult[0].count,
    };

    logger.info("Admin dashboard stats fetched", {
      adminId,
      ...stats,
    });

    res.json(stats);
  } catch (err) {
    logger.error("Error fetching admin dashboard stats", {
      adminId,
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
 * /api/admin/{adminId}/animals:
 *   get:
 *     summary: Get animals for a specific admin
 *     description: Fetch all animals listed by a specific admin.
 *     tags: [Marketplace]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: adminId
 *         required: true
 *         schema:
 *           type: string
 *         description: Admin ID
 *     responses:
 *       200:
 *         description: Animals fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 animals:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       id:
 *                         type: string
 *                       animal_type:
 *                         type: string
 *                         example: Sheep
 *                       breed:
 *                         type: string
 *                         example: Kajli
 *                       price:
 *                         type: number
 *                         example: 35000
 *                       delivery_type:
 *                         type: string
 *                         enum: [Free, Paid]
 *                       delivery_fee:
 *                         type: number
 *                         example: 500
 *                       delivery_threshold:
 *                         type: number
 *                         example: 10000
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Something went wrong. Please try again later.
 */

// GET /api/admins/:adminId/animals - Get Animals for Admin
router.get("/:adminId/animals", authMiddleware, async (req, res) => {
  const { adminId } = req.params;

  try {
    const [[admin]] = await pool.execute(
      `SELECT currency FROM users WHERE id = ? AND role = 'admin'`,
      [adminId],
    );

    if (!admin) {
      return res.status(404).json({ message: "Admin not found" });
    }

    const [animals] = await pool.execute(
      `
      SELECT 
        id,
        animal_type,
        price,
        delivery_type,
        delivery_fee,
        delivery_threshold
      FROM animals
      WHERE admin_id = ?
      `,
      [adminId],
    );

    //find Cash last payment date

    res.json({
      admin_currency: admin.currency,
      animals,
    });
  } catch (err) {
    res.status(500).json({ message: "Something went wrong" });
  }
});

router.get("/delivery-requests", authMiddleware, async (req, res) => {
  const adminId = req.user.id;

  try {
    // 1Fetch admin location
    const [[admin]] = await pool.execute(
      `SELECT country, state, city FROM admins WHERE id = ?`,
      [adminId],
    );

    if (!admin || !admin.city) {
      return res.status(400).json({
        message: "Admin location not set",
      });
    }

    // Fetch matching delivery requests
    const [requests] = await pool.execute(
      `
      SELECT
        dr.id,
        dr.user_id,
        dr.country,
        dr.state,
        dr.city,
        dr.status,
        dr.created_at,
        u.name,
        u.phone
      FROM delivery_requests dr
      JOIN users u ON u.id = dr.user_id
      WHERE dr.status = 'PENDING'
        AND dr.country = ?
        AND dr.state = ?
        AND dr.city = ?
      ORDER BY dr.created_at DESC
      `,
      [admin.country, admin.state, admin.city],
    );

    res.json({ requests });
  } catch (err) {
    console.error("Fetch delivery requests error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

/**
 * ======================================================
 * APPROVE or REJECT delivery request
 * ======================================================
 * PUT /api/admin/delivery-requests/:id
 * body: { status: "APPROVED" | "REJECTED" }
 */
router.put("/delivery-requests/:id", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  if (!["APPROVED", "REJECTED"].includes(status)) {
    return res.status(400).json({
      message: "Invalid status value",
    });
  }

  try {
    // 1️⃣ Update request status
    const [result] = await pool.execute(
      `UPDATE delivery_requests SET status = ? WHERE id = ?`,
      [status, id],
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Request not found" });
    }

    // 2️⃣ If approved → add to delivery_persons table
    if (status === "APPROVED") {
      const [[request]] = await pool.execute(
        `SELECT user_id, country, state, city FROM delivery_requests WHERE id = ?`,
        [id],
      );

      await pool.execute(
        `
        INSERT INTO delivery_persons (
          id,
          user_id,
          country,
          state,
          city,
          created_at
        ) VALUES (?, ?, ?, ?, ?, NOW())
        `,
        [
          uuidv4(),
          request.user_id,
          request.country,
          request.state,
          request.city,
        ],
      );
    }

    res.json({
      message: `Delivery request ${status.toLowerCase()} successfully`,
    });
  } catch (err) {
    console.error("Update delivery request error:", err);
    res.status(500).json({ message: "Server error" });
  }
});

module.exports = router;

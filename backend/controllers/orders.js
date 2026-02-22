/**
 * Orders Controller
 *
 * This module handles all order-related API endpoints for the application.
 * It includes routes for users to view, create, and manage their orders,
 * as well as admin-specific routes for managing orders.
 *
 * Key Features:
 * - User order management (view, create, cancel)
 * - Admin order management (view, update, mark as paid)
 * - Order scheduling and delivery assignment
 * - Ratings and feedback system
 * - Special requests handling
 *
 * Dependencies:
 * - express: Web framework for routing
 * - uuid: For generating unique order IDs
 * - mysql2/promise: Database connection pool
 * - authMiddleware: Authentication middleware
 * - logger: Logging utility for audit trails
 */

const express = require("express");
const router = express.Router();
const { v4: uuidv4 } = require("uuid");
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");

router.get("/my", authMiddleware, async (req, res) => {
  const userId = req.user.id;

  try {
    const [orders] = await pool.execute(
      `SELECT 
          o.id,
          o.user_id,
          o.admin_id,
          o.payment_method,
          o.total_shares,
          o.status,
          o.created_at,

          u.name AS admin_name,
          u.email AS admin_email,

          aps.cod_deadline
       FROM orders o
       JOIN users u 
         ON o.admin_id = u.id
       LEFT JOIN admin_payment_settings aps
         ON aps.admin_id = o.admin_id
       WHERE o.user_id = ?
       ORDER BY o.created_at DESC`,
      [userId],
    );

    // 🔥 For each order, fetch shareholders and compute overall statuses
    for (const order of orders) {
      const [shareholders] = await pool.execute(
        `SELECT processing_status, delivery_status, payment_status
   FROM shareholder_details
   WHERE order_id = ?`,
        [order.id],
      );

      order.shareholders = shareholders;

      if (!shareholders.length) {
        order.delivery_status = "Pending";
        order.processing_status = "Pending";
        order.payment_status = "Pending";
        continue;
      }

      const deliveryStatuses = shareholders.map((s) =>
        (s.delivery_status || "").toLowerCase(),
      );

      const processingStatuses = shareholders.map((s) =>
        (s.processing_status || "").toLowerCase(),
      );

      const paymentStatuses = shareholders.map((s) =>
        (s.payment_status || "").toLowerCase(),
      );

      // Delivery Logic
      if (deliveryStatuses.every((s) => s === "delivered")) {
        order.delivery_status = "Delivered";
      } else if (deliveryStatuses.includes("assigned")) {
        order.delivery_status = "Assigned";
      } else {
        order.delivery_status = "Pending";
      }

      // Processing Logic
      if (processingStatuses.every((s) => s === "completed")) {
        order.processing_status = "Completed";
      } else if (processingStatuses.includes("confirmed")) {
        order.processing_status = "Confirmed";
      } else {
        order.processing_status = "Pending";
      }

      // Payment Logic
      if (paymentStatuses.every((s) => s === "paid")) {
        order.payment_status = "Paid";
      } else if (paymentStatuses.includes("partial")) {
        order.payment_status = "Partial";
      } else {
        order.payment_status = "Pending";
      }
    }

    logger.info("Fetched user orders with computed statuses", {
      userId,
      count: orders.length,
    });

    res.json({ orders });
  } catch (err) {
    logger.error("Failed to fetch user orders", {
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
 * GET /api/orders/:orderId/delivery-boy/:deliveryBoyId
 * Retrieves delivery boy details for a specific order.
 * Validates order existence and delivery boy assignment.
 */
router.get(
  "/:orderId/delivery-boy/:deliveryBoyId",
  authMiddleware,
  async (req, res) => {
    try {
      const { orderId, deliveryBoyId } = req.params;

      // Check if order exists
      const order = await pool.query(
        "SELECT id, delivery_person_id FROM orders WHERE id = ?",
        [orderId],
      );

      if (order.rowCount === 0) {
        return res.status(404).json({ message: "Order not found" });
      }

      // Note: Delivery boy validation commented out for now
      // if (order[0].delivery_person_id !== deliveryBoyId) {
      //   return res
      //     .status(403)
      //     .json({ message: "Delivery boy not assigned to this order" });
      // }

      // Fetch delivery boy details
      const deliveryBoy = await pool.query(
        `
      SELECT
        id,
        name,
        phone
      FROM users
      WHERE id = ? AND role = 'delivery'
      `,
        [deliveryBoyId],
      );

      if (deliveryBoy.rowCount === 0) {
        return res.status(404).json({ message: "Delivery boy not found" });
      }

      res.json({
        deliveryBoy: deliveryBoy[0],
      });
    } catch (err) {
      logger.error("Failed to fetch delivery boy details", {
        orderId,
        deliveryBoyId,
        error: err.message,
        stack: err.stack,
      });
      res.status(500).json({ message: "Server error" });
    }
  },
);

router.post("/:orderId/assign-animal", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { animalId } = req.body;

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    // Update animal_details with order_id
    await connection.query(
      `UPDATE animal_details 
       SET order_id = ?
       WHERE animal_id = ? AND order_id IS NULL
       LIMIT 1`,
      [orderId, animalId],
    );

    // Update order with animal_id
    // await connection.query(
    //   `UPDATE orders
    //    SET animal_id = ?
    //    WHERE id = ?`,
    //   [animalId, orderId]
    // );

    // Count assigned shares
    const [assignedRows] = await connection.query(
      `SELECT COUNT(*) as totalAssigned
       FROM animal_details
       WHERE animal_id = ? AND order_id IS NOT NULL`,
      [animalId],
    );

    const totalAssigned = assignedRows[0].totalAssigned;

    // Get total shares of animal
    const [animalRows] = await connection.query(
      `SELECT shares FROM animals WHERE id = ?`,
      [animalId],
    );

    const totalShares = animalRows[0].shares;

    // If fully booked → mark as sold
    if (totalAssigned >= totalShares) {
      await connection.query(
        `UPDATE animals 
         SET status = 'sold'
         WHERE id = ?`,
        [animalId],
      );
    }

    await connection.commit();

    res.json({ message: "Animal assigned successfully" });
  } catch (error) {
    await connection.rollback();
    logger.error("Animal assignment failed", {
      orderId,
      animalId,
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ message: "Failed to assign animal" });
  } finally {
    connection.release();
  }
});

router.put("/:orderId/mark-paid", authMiddleware, async (req, res) => {
  const adminId = req.user.id;
  const { orderId } = req.params;

  logger.info("Admin marking COD order as paid", {
    adminId,
    orderId,
  });

  try {
    // Fetch order & validate
    const [rows] = await pool.execute(
      `
      SELECT id, payment_method, payment_status, processing_status
      FROM orders
      WHERE id = ? AND admin_id = ?
      `,
      [orderId, adminId],
    );

    if (rows.length === 0) {
      return res.status(404).json({
        message: "Order not found or unauthorized",
      });
    }

    const order = rows[0];

    if (order.payment_method !== "Cash") {
      return res.status(400).json({
        message: "Only Cash on Delivery orders can be marked as paid",
      });
    }

    if (order.payment_status === "paid") {
      return res.status(400).json({
        message: "Order already marked as paid",
      });
    }

    // Update order
    // await pool.execute(
    //   `
    //   UPDATE orders
    //   SET payment_status = 'paid',
    //       processing_status = 'completed'
    //   WHERE id = ?
    //   `,
    //   [orderId],
    // );

    await pool.execute(
      `
      UPDATE orders
      SET payment_status = 'paid',
      processing_status = 'pending'
      WHERE id = ?
      `,
      [orderId],
    );

    logger.info("COD order marked as paid", { orderId });

    res.json({
      message: "Order marked as paid successfully",
    });
  } catch (err) {
    logger.error("Failed to mark COD order as paid", {
      adminId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({
      message: "Failed to mark order as paid",
    });
  }
});

router.post("/", authMiddleware, async (req, res) => {
  const userId = req.user.id;
  const { adminId, paymentMethod, shareholders, totalAmount, paymentStatus } =
    req.body;

  if (
    !adminId ||
    !paymentMethod ||
    !Array.isArray(shareholders) ||
    shareholders.length === 0
  ) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  console.log("Creating order with data", req.body);

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    const orderId = uuidv4();

    // ✅ Create order
    await connection.execute(
      `
      INSERT INTO orders
        (id, user_id, admin_id, payment_method, total_shares, total_amt)
      VALUES (?, ?, ?, ?, ?, ?)
      `,
      [
        orderId,
        userId,
        adminId,
        paymentMethod,
        shareholders.length,
        totalAmount,
      ],
    );

    // ✅ Insert shareholders WITH ADDRESS (NO animal_id)
    await connection.query(
      `
      INSERT INTO shareholder_details
        (
          id,
          order_id,
          shareholder_name,
          guardian_name,
          qurbani_day,
          price,
          address,
          payment_status
        )
      VALUES ?
      `,
      [
        shareholders.map((s) => {
          if (!s.address || !s.address.address_line) {
            throw new Error("Address is required for each shareholder");
          }

          return [
            uuidv4(),
            orderId,
            s.name,
            s.guardianName,
            s.qurbaniDay || "Day 1",
            s.price,
            JSON.stringify(s.address),
            paymentStatus,
          ];
        }),
      ],
    );

    await connection.commit();

    // SEND PUSH HERE (after successful commit)

    try {
      const [devices] = await pool.query(
        `SELECT subscription_id 
     FROM user_devices 
     WHERE user_id = ? 
     AND role IN ('admin', 'super_admin')`,
        [adminId],
      );

      const subscriptionIds = devices.map((d) => d.subscription_id);

      if (subscriptionIds.length > 0) {
        await sendPushNotification(
          subscriptionIds,
          "🩸 New Qurbani Order",
          `New order #${orderId} has been placed.`,
        );
      }
    } catch (pushErr) {
      logger.error("Push notification failed", {
        orderId,
        error: pushErr.message,
      });
    }

    res.status(201).json({
      message: "Order placed successfully",
      orderId,
    });
  } catch (err) {
    await connection.rollback();
    logger.error("Order creation failed", {
      userId,
      adminId,
      error: err.message,
      stack: err.stack,
    });
    res.status(500).json({ message: err.message || "Something went wrong" });
  } finally {
    connection.release();
  }
});

router.get("/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    const [orders] = await pool.execute(
      `
      SELECT o.*, 
             u.name AS admin_name, 
             u.address AS admin_address, 
             u.phone AS admin_phone
      FROM orders o
      JOIN users u ON o.admin_id = u.id
      WHERE o.id = ? AND o.user_id = ?
      `,
      [orderId, userId],
    );

    if (!orders.length) {
      return res.status(404).json({ message: "Order not found" });
    }

    const order = orders[0];

    const [shareholders] = await pool.execute(
      `
        SELECT 
          s.*,
          a.animal_type,
          a.price AS animal_price,
          ad.breed,
          ad.age,
          ad.weight,
          ad.photo_urls
        FROM shareholder_details s
        LEFT JOIN animals a ON s.animal_id = a.id
        LEFT JOIN animal_details ad ON ad.animal_id = a.id
        WHERE s.order_id = ?
        `,
      [orderId],
    );

    res.json({
      order: {
        ...order,
        shareholders,
      },
    });
  } catch (err) {
    logger.error("Failed to fetch order details", {
      orderId,
      userId,
      error: err.message,
      stack: err.stack,
    });
    res.status(500).json({ message: "Something went wrong." });
  }
});

router.put("/:orderId/schedule", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { qurbani_time } = req.body;

  if (!qurbani_time) {
    return res.status(400).json({ message: "Qurbani time required" });
  }

  const conn = await pool.getConnection();

  try {
    await conn.beginTransaction();

    // Update animal_details
    const [animalResult] = await conn.execute(
      `UPDATE animal_details
         SET qurbani_datetime = ?
         WHERE order_id = ?`,
      [qurbani_time, orderId],
    );

    if (animalResult.affectedRows === 0) {
      await conn.rollback();
      return res.status(404).json({
        message: "Animal details not found for this order",
      });
    }

    //  Update order status
    const [orderResult] = await conn.execute(
      `UPDATE orders
   SET processing_status = 'confirmed'
   WHERE id = ?`,
      [orderId],
    );

    if (orderResult.affectedRows === 0) {
      await conn.rollback();
      return res.status(404).json({
        message: "Order not found",
      });
    }

    await conn.commit();

    res.json({
      message: "Qurbani scheduled successfully",
      processing_status: "confirmed",
    });
  } catch (err) {
    await conn.rollback();
    logger.error("Schedule update failed", err);
    res.status(500).json({ message: "Failed to update schedule" });
  } finally {
    conn.release();
  }
});

router.put("/animal-details/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { meat_weight, body_parts_description } = req.body;

  try {
    // Fetch all shareholders for this order
    const [shareholders] = await pool.query(
      `SELECT id FROM order_shareholders WHERE order_id = ?`,
      [orderId],
    );

    if (!shareholders.length) {
      return res.status(404).json({
        message: "No shareholders found for this order",
      });
    }

    // Update animal_details for EACH shareholder
    for (const s of shareholders) {
      await pool.execute(
        `UPDATE animal_details
         SET meat_weight = ?, body_parts_description = ?
         WHERE order_id = ? AND shareholder_id = ?`,
        [meat_weight, body_parts_description, orderId, s.id],
      );
    }

    // Mark order completed
    await pool.execute(
      `UPDATE orders SET processing_status = 'completed' WHERE id = ?`,
      [orderId],
    );

    res.json({ message: "Meat details saved successfully" });
  } catch (err) {
    logger.error("Meat details update failed", err);
    res.status(500).json({ message: "Failed to save meat details" });
  }
});

router.put("/:orderId/delivery", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { delivery_person_id } = req.body;

  if (!delivery_person_id) {
    return res.status(400).json({ message: "Delivery person required" });
  }

  try {
    const [result] = await pool.execute(
      `UPDATE orders
         SET delivery_person_id = ?
         WHERE id = ?`,
      [delivery_person_id, orderId],
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Order not found" });
    }

    res.json({ message: "Delivery assigned successfully" });
  } catch (err) {
    logger.error("Delivery assignment failed", err);
    res.status(500).json({ message: "Failed to assign delivery" });
  }
});

router.get("/admin/my", authMiddleware, async (req, res) => {
  const adminId = req.user.id;

  logger.info("Admin fetching own orders", { adminId });

  try {
    const [rows] = await pool.execute(
      `
      SELECT
        o.id AS order_id,
        o.user_id,
        o.admin_id,
        o.payment_method,
        o.total_shares,
        o.status,
        o.payment_status,
        o.created_at,

        aps.cod_deadline,

        s.id AS shareholder_id,
        s.shareholder_name,
        s.guardian_name,
        s.qurbani_day,
        s.processing_status,
        s.delivery_status,
        s.payment_status AS shareholder_payment_status

      FROM orders o
      LEFT JOIN admin_payment_settings aps
        ON aps.admin_id = o.admin_id
      LEFT JOIN shareholder_details s
        ON s.order_id = o.id

      WHERE o.admin_id = ?
      ORDER BY o.created_at DESC
      `,
      [adminId],
    );

    // Group orders
    const ordersMap = {};

    rows.forEach((row) => {
      if (!ordersMap[row.order_id]) {
        ordersMap[row.order_id] = {
          orderId: row.order_id,
          userId: row.user_id,
          adminId: row.admin_id,
          paymentMethod: row.payment_method,
          totalShares: row.total_shares,
          orderStatus: row.status,
          orderPaymentStatus: row.payment_status,
          createdAt: row.created_at,
          cod_deadline: row.cod_deadline,
          shareholders: [],
        };
      }

      if (row.shareholder_id) {
        ordersMap[row.order_id].shareholders.push({
          id: row.shareholder_id,
          shareholder_name: row.shareholder_name,
          guardian_name: row.guardian_name,
          qurbani_day: row.qurbani_day,
          processing_status: row.processing_status,
          delivery_status: row.delivery_status,
          payment_status: row.shareholder_payment_status,
        });
      }
    });

    const formattedOrders = Object.values(ordersMap);

    logger.info("Admin orders fetched", {
      adminId,
      orderCount: formattedOrders.length,
    });

    res.json({ orders: formattedOrders });
  } catch (err) {
    logger.error("Failed to fetch admin orders", {
      adminId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
});

router.get("/ratings/:orderId/:userId", authMiddleware, async (req, res) => {
  const { orderId, userId } = req.params;
  const authUserId = req.user.id; // Ensure user can only fetch their own ratings

  if (authUserId !== userId) {
    return res.status(403).json({ message: "Unauthorized" });
  }

  try {
    // Fetch order details (admins involved)
    const [orders] = await pool.execute(
      `SELECT o.id, o.admin_id, u.name as admin_name, 
              COALESCE(d.name, 'Delivery') as delivery_person_name
       FROM orders o
       JOIN users u ON o.admin_id = u.id
       LEFT JOIN users d ON o.delivery_person_id = d.id
       WHERE o.id = ? AND o.user_id = ?`,
      [orderId, userId],
    );

    if (orders.length === 0) {
      return res.status(404).json({ message: "Order not found" });
    }

    // Fetch existing ratings
    const [ratings] = await pool.execute(
      `SELECT admin_id, admin_rating, delivery_rating, feedback
       FROM ratings
       WHERE order_id = ? AND user_id = ?`,
      [orderId, userId],
    );

    // Map ratings by adminId
    const ratingsMap = {};
    ratings.forEach((rating) => {
      ratingsMap[rating.admin_id] = {
        adminRating: rating.admin_rating,
        deliveryRating: rating.delivery_rating,
        feedback: rating.feedback,
      };
    });

    res.json({
      orders: orders, // List of admins/deliveries for the order
      ratings: ratingsMap, // Existing ratings
      submitted: ratings.length > 0, // True if any ratings exist
    });
  } catch (err) {
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

router.post("/ratings", authMiddleware, async (req, res) => {
  const { orderId, userId, ratings } = req.body; // ratings: [{adminId, adminRating, deliveryRating, feedback}]
  const authUserId = req.user.id;

  if (authUserId !== userId) {
    return res.status(403).json({ message: "Unauthorized" });
  }

  if (!Array.isArray(ratings) || ratings.length === 0) {
    return res.status(400).json({ message: "Invalid ratings data" });
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    for (const rating of ratings) {
      const { adminId, adminRating, deliveryRating, feedback } = rating;

      if (
        !adminId ||
        adminRating < 1 ||
        adminRating > 5 ||
        deliveryRating < 1 ||
        deliveryRating > 5
      ) {
        throw new Error("Invalid rating data");
      }

      // Insert or update (ON DUPLICATE KEY)
      await connection.execute(
        `INSERT INTO ratings (order_id, user_id, admin_id, admin_rating, delivery_rating, feedback)
         VALUES (?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE admin_rating = VALUES(admin_rating), delivery_rating = VALUES(delivery_rating), feedback = VALUES(feedback)`,
        [
          orderId,
          userId,
          adminId,
          adminRating,
          deliveryRating,
          feedback || null,
        ],
      );
    }

    await connection.commit();
    res.json({ message: "Ratings submitted successfully" });
  } catch (err) {
    await connection.rollback();
    logger.error("Failed to submit ratings", {
      orderId,
      userId,
      error: err.message,
      stack: err.stack,
    });
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  } finally {
    connection.release();
  }
});

router.post("/requests", authMiddleware, async (req, res) => {
  const { orderId, userId, title, description } = req.body;
  const authUserId = req.user.id; // Ensure user can only submit their own requests

  if (authUserId !== userId) {
    return res.status(403).json({ message: "Unauthorized" });
  }

  if (!orderId || !title || !description) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    await pool.execute(
      `INSERT INTO requests (order_id, user_id, title, description, status)
       VALUES (?, ?, ?, ?, 'Pending')`,
      [orderId, userId, title, description],
    );

    res.status(201).json({ message: "Request submitted successfully" });
  } catch (err) {
    logger.error("Failed to submit request", {
      orderId,
      userId,
      error: err.message,
      stack: err.stack,
    });
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

router.get("/requests/:orderId/:userId", authMiddleware, async (req, res) => {
  const { orderId, userId } = req.params;
  const authUserId = req.user.id;

  if (authUserId !== userId) {
    return res.status(403).json({ message: "Unauthorized" });
  }

  try {
    const [requests] = await pool.execute(
      `SELECT id, title, description, status, created_at
       FROM requests
       WHERE order_id = ? AND user_id = ?`,
      [orderId, userId],
    );

    res.json({ requests });
  } catch (err) {
    logger.error("Failed to fetch user requests", {
      orderId,
      userId,
      error: err.message,
      stack: err.stack,
    });
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

// orders/admin/:orderId
router.get("/admin/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const adminId = req.user.id;

  try {
    // Fetch Order (WITHOUT old processing fields)
    const [orders] = await pool.execute(
      `SELECT 
          o.id,
          o.user_id,
          o.admin_id,
          o.payment_method,
          o.total_shares,
          o.payment_status,
          o.created_at,
          u.name AS user_name,
          u.email AS user_email,
          u.phone AS contact_no,
          u.address,
          a.name AS admin_name
       FROM orders o
       JOIN users u ON o.user_id = u.id
       JOIN users a ON o.admin_id = a.id
       WHERE o.id = ? AND o.admin_id = ?`,
      [orderId, adminId],
    );

    if (!orders.length) {
      return res
        .status(404)
        .json({ message: "Order not found or not authorized" });
    }

    const order = orders[0];

    // Fetch Shareholders WITH management fields
    const [shareholders] = await pool.execute(
      `SELECT 
      s.id,
      s.shareholder_name,
      s.guardian_name,
      s.animal_id,
      s.share_number,
      s.qurbani_datetime,
      s.address,
      s.processing_status,
      s.payment_status,
      s.delivery_status,
      s.delivery_person_id,
      an.animal_type
   FROM shareholder_details s
   LEFT JOIN animals an ON s.animal_id = an.id
   WHERE s.order_id = ?`,
      [order.id],
    );

    // Structure Clean Response
    const orderWithDetails = {
      orderId: order.id,
      user_name: order.user_name,
      email: order.user_email,
      contact_no: order.contact_no,
      address: order.address,
      total_shares: order.total_shares,
      payment_status: order.payment_status,
      payment_method: order.payment_method,
      created_at: order.created_at,
      shareholders: shareholders, // FULL detailed shareholder objects
    };

    res.json({ order: orderWithDetails });
  } catch (err) {
    logger.error("Failed to fetch admin order details", {
      adminId,
      orderId,
      error: err.message,
      stack: err.stack,
    });
    res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
});

router.put("/admin/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { processingStatus, deliveryStatus, deliveryPersonId } = req.body;
  const adminId = req.user.id;

  if (!processingStatus || !deliveryStatus) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    // Check if order belongs to admin
    const [orders] = await pool.execute(
      `SELECT id FROM orders WHERE id = ? AND admin_id = ?`,
      [orderId, adminId],
    );
    if (orders.length === 0) {
      return res
        .status(404)
        .json({ message: "Order not found or not authorized" });
    }

    // Update order
    await pool.execute(
      `UPDATE orders SET status = ?, delivery_status = ?, delivery_person_id = ? WHERE id = ?`,
      [processingStatus, deliveryStatus, deliveryPersonId || null, orderId],
    );

    res.json({ message: "Order updated successfully" });
  } catch (err) {
    logger.error("Failed to update admin order", {
      adminId,
      orderId,
      error: err.message,
      stack: err.stack,
    });
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

router.put("/:orderId/cancel", authMiddleware, async (req, res) => {
  // Extract order ID from URL parameters and get authenticated user's ID
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    // Step 1: Verify order exists and belongs to user
    // Fetch current order status and creation time for cancellation validation
    const [orders] = await pool.execute(
      `SELECT delivery_status, created_at FROM orders WHERE id = ? AND user_id = ?`,
      [orderId, userId],
    );

    // If order doesn't exist or doesn't belong to user, return error
    if (!orders.length) {
      logger.warn(
        "Order cancellation attempt on non-existent or non-owned order",
        {
          userId,
          orderId,
          reason: "Order not found or doesn't belong to user",
        },
      );
      return res.status(404).json({ message: "Order not found" });
    }

    const order = orders[0];

    // Step 2: Evaluate cancellation eligibility based on business rules
    const isDelivered = order.delivery_status === "delivered";
    const isCancelled = order.delivery_status === "cancelled";

    // Cancellation allowed within 24 hours AND order not delivered/cancelled
    // Time calculation: current time minus order creation time
    const timeSinceOrder = Date.now() - new Date(order.created_at).getTime();
    const within24Hours = timeSinceOrder < 24 * 60 * 60 * 1000; // 24 hours in milliseconds

    const canCancel = within24Hours && !isDelivered && !isCancelled;

    // If cancellation not allowed, return appropriate error
    if (!canCancel) {
      logger.warn(
        "Invalid order cancellation attempt - business rules violation",
        {
          userId,
          orderId,
          orderStatus: order.delivery_status,
          timeSinceOrder: Math.floor(timeSinceOrder / (1000 * 60 * 60)), // hours
          within24Hours,
          isDelivered,
          isCancelled,
          reason: !within24Hours
            ? "Outside 24-hour window"
            : isDelivered
              ? "Order already delivered"
              : "Order already cancelled",
        },
      );
      return res.status(400).json({ message: "Cannot cancel this order" });
    }

    // Step 3: Execute cancellation by updating all order statuses
    // Sets all statuses to 'cancelled' and records cancellation timestamp
    await pool.execute(
      `UPDATE orders
       SET delivery_status='pending',
           payment_status='pending',
           processing_status='pending',
           status='cancelled',
       WHERE id=?`,
      [orderId],
    );

    // Step 4: Log successful cancellation for audit trail
    logger.info("Order successfully cancelled by user", {
      userId,
      orderId,
      orderAge: Math.floor(timeSinceOrder / (1000 * 60)), // minutes since order
      cancellationType: "user_initiated",
      previousStatus: order.delivery_status,
    });

    // Return success response
    res.json({ message: "Order cancelled successfully" });
  } catch (err) {
    // Log error with comprehensive context for debugging
    logger.error("Error processing order cancellation", {
      userId,
      orderId,
      error: err.message,
      stack: err.stack,
    });
    // Return generic error message to client
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

module.exports = router;

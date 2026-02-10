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
          o.delivery_status,
          o.payment_status,

          u.name AS admin_name,
          u.email AS admin_email,

          aps.cod_deadline   -- ✅ added
       FROM orders o
       JOIN users u 
         ON o.admin_id = u.id
       LEFT JOIN admin_payment_settings aps
         ON aps.admin_id = o.admin_id
       WHERE o.user_id = ?
       ORDER BY o.created_at DESC`,
      [userId],
    );

    logger.info("Fetched user orders", {
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

      console.log(order);

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

      console.log(deliveryBoy);

      if (deliveryBoy.rowCount === 0) {
        return res.status(404).json({ message: "Delivery boy not found" });
      }

      res.json({
        deliveryBoy: deliveryBoy[0],
      });
    } catch (err) {
      console.error(err);
      res.status(500).json({ message: "Server error" });
    }
  },
);

router.put("/:orderId/mark-paid", authMiddleware, async (req, res) => {
  const adminId = req.user.id;
  const { orderId } = req.params;

  logger.info("Admin marking COD order as paid", {
    adminId,
    orderId,
  });

  try {
    // 1️⃣ Fetch order & validate
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

    // 2️⃣ Update order
    await pool.execute(
      `
      UPDATE orders
      SET payment_status = 'paid',
          processing_status = 'completed'
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
}

);

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

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    const orderId = uuidv4();

    // ✅ Create order
    await connection.execute(
      `
      INSERT INTO orders
        (id, user_id, admin_id, payment_method, total_shares, payment_status, total_amt)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      `,
      [
        orderId,
        userId,
        adminId,
        paymentMethod,
        shareholders.length,
        paymentStatus,
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
          address
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
            JSON.stringify(s.address), // 🔥 IMPORTANT
          ];
        }),
      ],
    );

    await connection.commit();

    res.status(201).json({
      message: "Order placed successfully",
      orderId,
    });
  } catch (err) {
    await connection.rollback();
    console.error("❌ Order creation failed:", err);
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
      `SELECT o.*, u.name as admin_name, u.address as admin_address, u.phone as admin_phone
       FROM orders o
       JOIN users u ON o.admin_id = u.id
       WHERE o.id = ? AND o.user_id = ?`,
      [orderId, userId],
    );

    if (orders.length === 0) {
      return res.status(404).json({ message: "Order not found" });
    }

    const order = orders[0];

    // Fetch animals linked to this order
    const [animals] = await pool.execute(
      `SELECT ad.*, a.animal_type, a.price
       FROM animal_details ad
       JOIN animals a ON ad.animal_id = a.id
       WHERE ad.order_id = ?`,
      [orderId],
    );

    // Respond with order + animals
    res.json({ order: { ...order, animals } });
  } catch (err) {
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

    // 1️⃣ Update animal_details
    const [animalResult] = await conn.execute(
      `UPDATE animal_details
         SET qurbani_datetime = ?
         WHERE order_id = ?`,
      [qurbani_time, orderId],
    );

    console.log("schedule check", animalResult);

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

    console.log("order update result", orderResult);

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
    // 1️⃣ Fetch all shareholders for this order
    const [shareholders] = await pool.query(
      `SELECT id FROM order_shareholders WHERE order_id = ?`,
      [orderId],
    );

    if (!shareholders.length) {
      return res.status(404).json({
        message: "No shareholders found for this order",
      });
    }

    // 2️⃣ Update animal_details for EACH shareholder
    for (const s of shareholders) {
      await pool.execute(
        `UPDATE animal_details
         SET meat_weight = ?, body_parts_description = ?
         WHERE order_id = ? AND shareholder_id = ?`,
        [meat_weight, body_parts_description, orderId, s.id],
      );
    }

    // 3️⃣ Mark order completed
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
  console.log("coming here....");

  try {
    const [orders] = await pool.execute(
      `
      SELECT
        o.id,
        o.user_id,
        o.admin_id,
        o.payment_method,
        o.total_shares,
        o.processing_status,
        o.payment_status,
        o.delivery_status,
        o.created_at,
        a.photo_urls,
        aps.cod_deadline
      FROM orders o
      LEFT JOIN animal_details a 
        ON a.order_id = o.id
      LEFT JOIN admin_payment_settings aps
        ON aps.admin_id = o.admin_id
      WHERE o.admin_id = ?
      ORDER BY o.created_at DESC
      `,
      [adminId],
    );

    logger.info("Admin orders raw", { orders });

    const ordersWithDetails = await Promise.all(
      orders.map(async (order) => {
        const [shareholders] = await pool.execute(
          `
          SELECT id, shareholder_name, guardian_name, qurbani_day
          FROM order_shareholders
          WHERE order_id = ?
          `,
          [order.id],
        );

        return {
          orderId: order.id,
          adminId: order.admin_id,
          paymentMethod: order.payment_method,
          processingStatus: order.processing_status,
          paymentStatus: order.payment_status,
          deliveryStatus: order.delivery_status,
          isCompleted: order.processing_status === "completed",
          createdAt: order.created_at,

          cod_deadline: order.cod_deadline,

          photoUrls: order.photo_urls,
          shareholders,
        };
      }),
    );

    logger.info("Admin orders fetched", {
      adminId,
      orderCount: ordersWithDetails.length,
    });

    res.json({ orders: ordersWithDetails });
  } catch (err) {
    logger.error("Failed to fetch admin orders", {
      adminId,
      error: err.message,
      stack: err.stack,
    });

    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
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
    console.error("Error fetching ratings:", err);
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

router.post("/ratings", authMiddleware, async (req, res) => {
  const { orderId, userId, ratings } = req.body; // ratings: [{adminId, adminRating, deliveryRating, feedback}]
  const authUserId = req.user.id;
  // console.log();
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
      console.log("ratings geting started");
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
    console.error("Error submitting ratings:", err);
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
    console.error("Error submitting request:", err);
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
    console.error("Error fetching requests:", err);
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

router.get("/admin/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const adminId = req.user.id; // Admin's user ID from JWT

  console.log("Fetching order for admin:", adminId, "orderId:", orderId);

  try {
    const [orders] = await pool.execute(
      `SELECT o.id, o.user_id, o.admin_id, o.payment_method, o.total_shares, o.processing_status, o.delivery_status, o.delivery_person_id, o.created_at,
              u.name as user_name, u.email as user_email, u.phone as contact_no,
              a.name as admin_name, o.payment_status, u.address
       FROM orders o
       JOIN users u ON o.user_id = u.id
       JOIN users a ON o.admin_id = a.id
       WHERE o.id = ? AND o.admin_id = ?`, // Restrict to admin's own orders
      [orderId, adminId],
    );

    console.log(orders);

    if (orders.length === 0) {
      return res
        .status(404)
        .json({ message: "Order not found or not authorized" });
    }

    const order = orders[0];

    // Fetch shareholders for the order
    const [shareholders] = await pool.execute(
      `SELECT id, shareholder_name, guardian_name, qurbani_day FROM order_shareholders WHERE order_id = ?`,
      [order.id],
    );

    // Structure the response to match admin frontend expectations
    const orderWithDetails = {
      orderId: order.id,
      user_name: order.user_name,
      address: order.address,
      animal_type: "Sheep", // Dummy, as per schema
      parts: shareholders.map((s) => s.name).join(", "), // Map to parts
      total_amount: 100 * order.total_shares, // Dummy calculation
      payment_status: order.payment_status, // Default
      delivery_address: "N/A", // Default; add to schema if needed
      contact_no: order.contact_no || "N/A",
      processing_status: order.processing_status,
      delivery_status: order.delivery_status || "pending",
      delivery_person_id: order.delivery_person_id,
      shareholders, // Include for reference
      paymentMethod: order.payment_method,
    };

    res.json({ order: orderWithDetails });
  } catch (err) {
    console.error("Error fetching admin order:", err);
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

router.put("/admin/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { processingStatus, deliveryStatus, deliveryPersonId } = req.body;
  const adminId = req.user.id;

  console.log("Updating order for admin:", processingStatus);

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
    console.error("Error updating order:", err);
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

    console.log(order);

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

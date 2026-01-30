// routes/orders.js
const express = require("express");
const router = express.Router();
const { v4: uuidv4 } = require("uuid");
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");

// GET /api/orders/my - Get all orders for the authenticated user
router.get("/my", authMiddleware, async (req, res) => {
  const userId = req.user.id;

  try {
    const [orders] = await pool.execute(
      `SELECT o.id, o.user_id, o.admin_id, o.payment_method, o.total_shares, o.status, o.created_at,
              u.name as admin_name, u.email as admin_email, o.delivery_status
       FROM orders o
       JOIN users u ON o.admin_id = u.id
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
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

// POST /api/orders
router.post("/", authMiddleware, async (req, res) => {
  const userId = req.user.id;
  const { adminId, paymentMethod, shareholders, totalAmount, paymentStatus } = req.body;

  console.log("Print pay status", paymentStatus);


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

    // Create order
    await connection.execute(
      `INSERT INTO orders (id, user_id, admin_id, payment_method, total_shares, payment_status, total_amt)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [orderId, userId, adminId, paymentMethod, shareholders.length, paymentStatus, totalAmount],
    );

    // Insert order_shareholders (WITH animal_id)
    await connection.query(
      `INSERT INTO order_shareholders
       (id, order_id, animal_id, shareholder_name, guardian_name, qurbani_day, price)
       VALUES ?`,
      [
        shareholders.map((s) => [
          uuidv4(),
          orderId,
          s.animalId,
          s.name,
          s.guardianName,
          s.qurbaniDay || "Day 1",
          s.price,
        ]),
      ],
    );

    await connection.commit();

    res.status(201).json({
      message: "Order placed successfully",
      orderId,
    });
  } catch (err) {
    await connection.rollback();
    res.status(500).json({ message: "Something went wrong" });
  } finally {
    connection.release();
  }
});

// GET /api/orders/:orderId - Get a single order by ID for the authenticated user
router.get("/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    const [orders] = await pool.execute(
      `SELECT o.*, u.name as admin_name, u.address as admin_address, u.phone as admin_phone
       FROM orders o
       JOIN users u ON o.admin_id = u.id
       WHERE o.id = ? AND o.user_id = ?`,
      [orderId, userId]
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
      [orderId]
    );

    // Respond with order + animals
    res.json({ order: { ...order, animals } });
  } catch (err) {
    res.status(500).json({ message: "Something went wrong." });
  }
});


//api/orders/:id
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

//   if (
//   meat_weight === undefined ||
//   body_parts_description === undefined ||
//   String(body_parts_description).trim() === ""
// ) {
//   return res.status(400).json({ message: "Incomplete meat details" });
// }

  console.log("Meat check");
  try {
    // UPSERT animal details
    await pool.execute(
      `INSERT INTO animal_details (order_id, meat_weight, body_parts_description)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE
           meat_weight = VALUES(meat_weight),
           body_parts_description = VALUES(body_parts_description)`,
      [orderId, meat_weight, body_parts_description],
    );

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

// GET /api/orders/admin/my - Get all orders for the authenticated admin
router.get("/admin/my", authMiddleware, async (req, res) => {
  const adminId = req.user.id; // Assuming JWT provides admin's user ID
  console.log("coming here");
  try {
    const [orders] = await pool.execute(
      `SELECT o.id, o.user_id, o.admin_id, o.payment_method, o.total_shares, o.processing_status, o.created_at,
              u.name as admin_name, u.email as admin_email
       FROM orders o
       JOIN users u ON o.admin_id = u.id
       WHERE o.admin_id = ?
       ORDER BY o.created_at DESC`,
      [adminId],
    );

    console.log(orders);

    // For each order, fetch shareholders and map to expected structure
    const ordersWithDetails = await Promise.all(
      orders.map(async (order) => {
        const [shareholders] = await pool.execute(
          `SELECT id, shareholder_name, guardian_name, qurbani_day FROM order_shareholders WHERE order_id = ?`,
          [order.id],
        );

        // Map to Flutter-expected structure (add defaults for missing fields)
        return {
          orderId: order.id,
          adminId: order.admin_id,
          deliveryStatus: "pending", // Default; add column to orders table if needed
          processingStatus: order.processing_status, // Maps to status (pending, confirmed, etc.)
          isCompleted: order.processing_status === "completed", // For filtering
          createdAt: order.created_at,
          contact: { primary: "" }, // Placeholder; join users table for phone if available
          shareholders, // Include for details if needed
          // Add other fields as needed (e.g., totalShares: order.total_shares)
        };
      }),
    );

    res.json({ orders: ordersWithDetails });
  } catch (err) {
    console.error("Error fetching admin orders:", err);
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

// GET /api/ratings/:orderId/:userId - Fetch ratings and order details for the user
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

// POST /api/ratings - Submit ratings
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

// POST /api/requests - Submit a special request
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

// Optional: GET /api/requests/:orderId/:userId - Fetch requests for the user (if needed for viewing)
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

// GET /api/orders/admin/:orderId - Get a single order by ID for the authenticated admin
router.get("/admin/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const adminId = req.user.id; // Admin's user ID from JWT

  console.log("Fetching order for admin:", adminId, "orderId:", orderId);

  try {
    const [orders] = await pool.execute(
      `SELECT o.id, o.user_id, o.admin_id, o.payment_method, o.total_shares, o.processing_status, o.delivery_status, o.delivery_person_id, o.created_at,
              u.name as user_name, u.email as user_email, u.phone as contact_no,
              a.name as admin_name
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
      animal_type: "Sheep", // Dummy, as per schema
      parts: shareholders.map((s) => s.name).join(", "), // Map to parts
      total_amount: 100 * order.total_shares, // Dummy calculation
      payment_status: "Paid", // Default
      delivery_address: "N/A", // Default; add to schema if needed
      contact_no: order.contact_no || "N/A",
      processing_status: order.processing_status,
      delivery_status: order.delivery_status || "pending",
      delivery_person_id: order.delivery_person_id,
      shareholders, // Include for reference
    };

    res.json({ order: orderWithDetails });
  } catch (err) {
    console.error("Error fetching admin order:", err);
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

// PUT /api/orders/admin/:orderId - Update order details (for admin)
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

module.exports = router;

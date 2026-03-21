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
const { sendPushNotification } = require("../utils/notification_service");


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
          o.payment_status AS order_payment_status,
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
      [userId]
    );



    for (const order of orders) {
      const [shareholders] = await pool.execute(
        `SELECT status, payment_status
         FROM shareholder_details
         WHERE order_id = ?`,
        [order.id]
      );

      order.shareholders = shareholders;

      if (!shareholders.length) {
        order.processing_status = "Not started";
        order.delivery_status = "Pending";
        order.payment_status = 2;
        order.payment_status_label = "Pending";
        continue;
      }

      const statuses = shareholders.map((s) => Number(s.status));
      const paymentStatuses = shareholders.map((s) => Number(s.payment_status));

      const maxStatus = Math.max(...statuses);

      if (maxStatus === 6) {
        order.processing_status = "Cancelled";
        order.delivery_status = "Cancelled";
      } else if (maxStatus === 5) {
        order.processing_status = "Delivered";
        order.delivery_status = "Delivered";
      } else if (maxStatus === 4) {
        order.processing_status = "Sent for delivery";
        order.delivery_status = "Sent for delivery";
      } else if (maxStatus === 3) {
        order.processing_status = "Meat Packaged";
        order.delivery_status = "Pending";
      } else if (maxStatus === 2) {
        order.processing_status = "Processing";
        order.delivery_status = "Pending";
      } else if (maxStatus === 1) {
        order.processing_status = "Qurbani Started";
        order.delivery_status = "Pending";
      } else {
        order.processing_status = "Not started";
        order.delivery_status = "Pending";
      }

      if (paymentStatuses.every((s) => s === 1)) {
        order.payment_status = 0; // paid
        order.payment_status_label = "Paid";
      } else if (paymentStatuses.every((s) => s === 2)) {
        order.payment_status = 1; // unpaid
        order.payment_status_label = "Unpaid";
      } else {
        order.payment_status = 2; // pending
        order.payment_status_label = "Pending";
      }
    }

    console.log(orders);

    res.json({ orders });
  } catch (err) {
    res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
});


// /**
//  * GET /api/orders/:orderId/delivery-boy/:deliveryBoyId
//  * Retrieves delivery boy details for a specific order.
//  * Validates order existence and delivery boy assignment.
//  */
// router.get(
//   "/:orderId/delivery-boy/:deliveryBoyId",
//   authMiddleware,
//   async (req, res) => {
//     try {
//       const { orderId, deliveryBoyId } = req.params;

//       // Check if order exists
//       const order = await pool.query(
//         "SELECT id, delivery_person_id FROM orders WHERE id = ?",
//         [orderId],
//       );

//       if (order.rowCount === 0) {
//         return res.status(404).json({ message: "Order not found" });
//       }

//       // Note: Delivery boy validation commented out for now
//       // if (order[0].delivery_person_id !== deliveryBoyId) {
//       //   return res
//       //     .status(403)
//       //     .json({ message: "Delivery boy not assigned to this order" });
//       // }

//       // Fetch delivery boy details
//       const deliveryBoy = await pool.query(
//         `
//       SELECT
//         id,
//         name,
//         phone
//       FROM users
//       WHERE id = ? AND role = 'delivery'
//       `,
//         [deliveryBoyId],
//       );

//       if (deliveryBoy.rowCount === 0) {
//         return res.status(404).json({ message: "Delivery boy not found" });
//       }

//       res.json({
//         deliveryBoy: deliveryBoy[0],
//       });
//     } catch (err) {
//       logger.error("Failed to fetch delivery boy details", {
//         orderId,
//         deliveryBoyId,
//         error: err.message,
//         stack: err.stack,
//       });
//       res.status(500).json({ message: "Server error" });
//     }
//   },
// );

// router.post("/:orderId/assign-animal", authMiddleware, async (req, res) => {
//   const { orderId } = req.params;
//   const { animalId } = req.body;

//   const connection = await pool.getConnection();

//   try {
//     await connection.beginTransaction();

//     // 🔍 Get order to fetch user_id
//     const [orderRows] = await connection.query(
//       `SELECT user_id FROM orders WHERE id = ?`,
//       [orderId],
//     );

//     if (orderRows.length === 0) {
//       await connection.rollback();
//       return res.status(404).json({ message: "Order not found" });
//     }

//     const userId = orderRows[0].user_id;

//     // ✅ Assign share (animal_details)
//     await connection.query(
//       `UPDATE animal_details 
//        SET order_id = ?
//        WHERE animal_id = ? AND order_id IS NULL
//        LIMIT 1`,
//       [orderId, animalId],
//     );

//     // ✅ Count assigned shares
//     const [assignedRows] = await connection.query(
//       `SELECT COUNT(*) as totalAssigned
//        FROM animal_details
//        WHERE animal_id = ? AND order_id IS NOT NULL`,
//       [animalId],
//     );

//     const totalAssigned = assignedRows[0].totalAssigned;

//     // ✅ Get total shares
//     const [animalRows] = await connection.query(
//       `SELECT shares FROM animals WHERE id = ?`,
//       [animalId],
//     );

//     const totalShares = animalRows[0].shares;

//     // ✅ If fully booked → mark sold
//     if (totalAssigned >= totalShares) {
//       await connection.query(
//         `UPDATE animals 
//          SET status = 'sold'
//          WHERE id = ?`,
//         [animalId],
//       );
//     }

//     await connection.commit();

//     // 🔔 SEND PUSH TO USER (after commit)
//     try {
//       const [devices] = await connection.query(
//         `SELECT subscription_id
//          FROM user_devices
//          WHERE user_id = ?`,
//         [userId],
//       );

//       const subscriptionIds = devices.map((d) => d.subscription_id);

//       if (subscriptionIds.length > 0) {
//         await sendPushNotification(
//           subscriptionIds,
//           "🐄 Animal Assigned",
//           "Your Qurbani animal has been successfully assigned.",
//           {
//             type: "ANIMAL_ASSIGNED",
//             orderId: orderId,
//           },
//         );
//       }
//     } catch (pushErr) {
//       logger.error("Animal assignment push failed", {
//         orderId,
//         error: pushErr.message,
//       });
//     }

//     res.json({ message: "Animal assigned successfully" });
//   } catch (error) {
//     await connection.rollback();

//     logger.error("Animal assignment failed", {
//       orderId,
//       animalId,
//       error: error.message,
//       stack: error.stack,
//     });

//     res.status(500).json({ message: "Failed to assign animal" });
//   } finally {
//     connection.release();
//   }
// });

// router.put("/:orderId/mark-paid", authMiddleware, async (req, res) => {
//   const adminId = req.user.id;
//   const { orderId } = req.params;

//   logger.info("Admin marking COD order as paid", {
//     adminId,
//     orderId,
//   });

//   try {
//     // Fetch order & validate
//     const [rows] = await pool.execute(
//       `
//       SELECT id, user_id, payment_method, payment_status, processing_status
//       FROM orders
//       WHERE id = ? AND admin_id = ?
//       `,
//       [orderId, adminId],
//     );

//     console.log("Order fetch result for marking paid:", rows);

//     if (rows.length === 0) {
//       return res.status(404).json({
//         message: "Order not found or unauthorized",
//       });
//     }

//     const order = rows[0];

//     if (order.payment_method !== "Cash") {
//       return res.status(400).json({
//         message: "Only Cash on Delivery orders can be marked as paid",
//       });
//     }

//     if (order.payment_status === "paid") {
//       return res.status(400).json({
//         message: "Order already marked as paid",
//       });
//     }

//     // ✅ Update order
//     await pool.execute(
//       `
//       UPDATE orders
//       SET payment_status = 'paid',
//           processing_status = 'pending'
//       WHERE id = ?
//       `,
//       [orderId],
//     );

//     logger.info("COD order marked as paid", { orderId });

//     // 🔔 SEND PUSH TO USER (do not block API)
//     try {
//       const [devices] = await pool.execute(
//         `
//         SELECT subscription_id
//         FROM user_devices
//         WHERE user_id = ?
//         `,
//         [order.user_id],
//       );

//       const subscriptionIds = devices.map((d) => d.subscription_id);
//       console.log(
//         "Payment confirmation - user subscription IDs:",
//         subscriptionIds,
//       );
//       if (subscriptionIds.length > 0) {
//         await sendPushNotification(
//           subscriptionIds,
//           "💳 Payment Confirmed",
//           "Your Qurbani order payment has been confirmed.",
//           {
//             type: "PAYMENT_CONFIRMED",
//             orderId: orderId,
//           },
//         );
//       }
//     } catch (pushErr) {
//       logger.error("Payment push failed", {
//         orderId,
//         error: pushErr.message,
//       });
//     }

//     res.json({
//       message: "Order marked as paid successfully",
//     });
//   } catch (err) {
//     logger.error("Failed to mark COD order as paid", {
//       adminId,
//       orderId,
//       error: err.message,
//       stack: err.stack,
//     });

//     res.status(500).json({
//       message: "Failed to mark order as paid",
//     });
//   }
// });



router.post("/", authMiddleware, async (req, res) => {
  const userId = req.user.id;
  const { adminId, paymentMethod, shareholders, totalAmount, paymentStatus } =
    req.body;

  if (
    !adminId ||
    paymentMethod === undefined ||
    !Array.isArray(shareholders) ||
    shareholders.length === 0
  ) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    // Create order
    const [orderResult] = await connection.execute(
      `
      INSERT INTO orders
        (user_id, admin_id, payment_method, total_shares, total_amt, payment_status)
      VALUES (?, ?, ?, ?, ?, ?)
      `,
      [
        userId,
        adminId,
        paymentMethod,
        shareholders.length,
        totalAmount,
        paymentStatus ?? 2, // default pending
      ]
    );

    console.log(orderResult);
    const orderId = orderResult.insertId;

    // Insert shareholders
    await connection.query(
      `
      INSERT INTO shareholder_details
        (
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
            orderId,
            s.name,
            s.guardianName,
            s.qurbaniDay || "Day 1",
            s.price,
            JSON.stringify(s.address),
            paymentStatus ?? 0, // 0=pending
          ];
        }),
      ]
    );

    await connection.commit();

    // Send push AFTER commit
    try {
      const [devices] = await connection.query(
        `
        SELECT subscription_id
        FROM user_devices
        WHERE user_id = ?
        `,
        [adminId]
      );

      const subscriptionIds = devices.map((d) => d.subscription_id);
      // const shortOrderId = orderId.toString().padStart(6, "0");

      if (subscriptionIds.length > 0) {
        await sendPushNotification(
          subscriptionIds,
          "New Qurbani Order",
          `New order #${orderId} has been placed.`,
          { type: "NEW_ORDER", orderId }
        );
      }
    } catch (pushErr) {
      logger.error("Push notification failed", {
        orderId,
        status: pushErr.response?.status,
        data: pushErr.response?.data,
        message: pushErr.message,
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
      SELECT 
        o.*,
        u.name AS admin_name,
        u.address AS admin_address,
        u.phone AS admin_phone
      FROM orders o
      JOIN users u ON o.admin_id = u.id
      WHERE o.id = ? AND o.user_id = ?
      `,
      [orderId, userId]
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
        a.qurbani_day,
        a.qurbani_datetime,
        ad.photo_urls
      FROM shareholder_details s
      LEFT JOIN animals a ON s.animal_id = a.id
      LEFT JOIN animal_details ad ON ad.animal_id = a.id
      WHERE s.order_id = ?
      `,
      [orderId]
    );

    console.log(shareholders);

    order.shareholders = shareholders;

    if (!shareholders.length) {
      order.processing_status = "Not started";
      order.delivery_status = "Pending";
      order.payment_status = 2; // 0=paid, 1=unpaid, 2=pending
      order.payment_status_label = "Pending";
    } else {
      const statuses = shareholders.map((s) => Number(s.status));
      const paymentStatuses = shareholders.map((s) => Number(s.payment_status));

      const maxStatus = Math.max(...statuses);

      if (maxStatus === 6) {
        order.processing_status = "Cancelled";
        order.delivery_status = "Cancelled";
      } else if (maxStatus === 5) {
        order.processing_status = "Delivered";
        order.delivery_status = "Delivered";
      } else if (maxStatus === 4) {
        order.processing_status = "Sent for delivery";
        order.delivery_status = "Sent for delivery";
      } else if (maxStatus === 3) {
        order.processing_status = "Meat Packaged";
        order.delivery_status = "Pending";
      } else if (maxStatus === 2) {
        order.processing_status = "Processing";
        order.delivery_status = "Pending";
      } else if (maxStatus === 1) {
        order.processing_status = "Qurbani Started";
        order.delivery_status = "Pending";
      } else {
        order.processing_status = "Not started";
        order.delivery_status = "Pending";
      }

      // Use this ONLY if shareholder_details has been migrated to:
      // 0=paid, 1=unpaid, 2=pending
      if (paymentStatuses.every((s) => s === 0)) {
        order.payment_status = 0;
        order.payment_status_label = "Paid";
      } else if (paymentStatuses.every((s) => s === 1)) {
        order.payment_status = 1;
        order.payment_status_label = "Unpaid";
      } else {
        order.payment_status = 2;
        order.payment_status_label = "Pending";
      }
    }

    console.log();


    res.json({
      order,
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

    // 🔍 Get order to fetch user_id
    const [orderRows] = await conn.execute(
      `SELECT user_id FROM orders WHERE id = ?`,
      [orderId],
    );

    if (orderRows.length === 0) {
      await conn.rollback();
      return res.status(404).json({ message: "Order not found" });
    }

    const userId = orderRows[0].user_id;

    // ✅ Update animal_details
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

    // ✅ Update order status
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

    // 🔔 SEND PUSH TO USER (after commit)
    try {
      const [devices] = await pool.execute(
        `SELECT subscription_id
         FROM user_devices
         WHERE user_id = ?`,
        [userId],
      );

      const subscriptionIds = devices.map((d) => d.subscription_id);

      if (subscriptionIds.length > 0) {
        await sendPushNotification(
          subscriptionIds,
          "Qurbani Scheduled",
          "Your Qurbani has been successfully scheduled.",
          {
            type: "QURBANI_SCHEDULED",
            orderId: orderId,
            qurbani_time,
          },
        );
      }
    } catch (pushErr) {
      logger.error("Schedule push failed", {
        orderId,
        error: pushErr.message,
      });
    }

    res.json({
      message: "Qurbani scheduled successfully",
      processing_status: "confirmed",
    });
  } catch (err) {
    await conn.rollback();
    logger.error("Schedule update failed", {
      orderId,
      error: err.message,
      stack: err.stack,
    });

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
    // 🔍 Get order to fetch user_id
    const [orderRows] = await pool.execute(
      `SELECT user_id FROM orders WHERE id = ?`,
      [orderId],
    );

    if (orderRows.length === 0) {
      return res.status(404).json({ message: "Order not found" });
    }

    const userId = orderRows[0].user_id;

    // ✅ Assign delivery person
    const [result] = await pool.execute(
      `UPDATE orders
         SET delivery_person_id = ?
         WHERE id = ?`,
      [delivery_person_id, orderId],
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Order not found" });
    }

    // 🔔 Notify Delivery Person
    try {
      const [deliveryDevices] = await pool.execute(
        `SELECT subscription_id
         FROM user_devices
         WHERE user_id = ?`,
        [delivery_person_id],
      );

      const deliverySubs = deliveryDevices.map((d) => d.subscription_id);

      if (deliverySubs.length > 0) {
        await sendPushNotification(
          deliverySubs,
          "🚚 New Delivery Assigned",
          "A new Qurbani order has been assigned to you.",
          {
            type: "DELIVERY_ASSIGNED",
            orderId,
          },
        );
      }
    } catch (pushErr) {
      logger.error("Delivery person push failed", {
        orderId,
        error: pushErr.message,
      });
    }

    // 🔔 (Optional) Notify User
    try {
      const [userDevices] = await pool.execute(
        `SELECT subscription_id
         FROM user_devices
         WHERE user_id = ?`,
        [userId],
      );

      const userSubs = userDevices.map((d) => d.subscription_id);

      if (userSubs.length > 0) {
        await sendPushNotification(
          userSubs,
          "📦 Delivery Assigned",
          "Your Qurbani order is out for delivery.",
          {
            type: "DELIVERY_STARTED",
            orderId,
          },
        );
      }
    } catch (pushErr) {
      logger.error("User delivery push failed", {
        orderId,
        error: pushErr.message,
      });
    }

    res.json({ message: "Delivery assigned successfully" });
  } catch (err) {
    logger.error("Delivery assignment failed", {
      orderId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Failed to assign delivery" });
  }
});

function mapShareholderStatus(status) {
  switch (Number(status)) {
    case 0:
      return "Not started";
    case 1:
      return "Qurbani Started";
    case 2:
      return "Processing";
    case 3:
      return "Meat Packaged";
    case 4:
      return "Sent for delivery";
    case 5:
      return "Delivered";
    case 6:
      return "Cancelled";
    default:
      return "Unknown";
  }
}

function mapPaymentStatus(status) {
  switch (Number(status)) {
    case 0:
      return "Pending";
    case 1:
      return "Paid";
    case 2:
      return "Unpaid";
    default:
      return "Unknown";
  }
}

function mapOrderStatus(status) {
  switch (Number(status)) {
    case 0:
      return "Active";
    case 1:
      return "Completed";
    case 2:
      return "Cancelled";
    default:
      return "Unknown";
  }
}

function mapPaymentMethod(method) {
  switch (Number(method)) {
    case 0:
      return "Cash";
    case 1:
      return "Online";
    default:
      return "Unknown";
  }
}



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
        o.status AS order_status,
        o.payment_status AS order_payment_status,
        o.created_at,

        aps.cod_deadline,

        s.id AS shareholder_id,
        s.shareholder_name,
        s.guardian_name,
        s.qurbani_day,
        s.status AS shareholder_status,
        s.payment_status AS shareholder_payment_status,
        s.animal_id,
        s.share_number,
        s.qurbani_datetime

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

    const ordersMap = {};

    rows.forEach((row) => {
      if (!ordersMap[row.order_id]) {
        ordersMap[row.order_id] = {
          orderId: row.order_id,
          userId: row.user_id,
          adminId: row.admin_id,
          paymentMethod: row.payment_method,
          paymentMethodLabel: mapPaymentMethod(row.payment_method),
          totalShares: row.total_shares,
          orderStatus: row.order_status,
          orderStatusLabel: mapOrderStatus(row.order_status),
          orderPaymentStatus: row.order_payment_status,
          orderPaymentStatusLabel: mapPaymentStatus(row.order_payment_status),
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
          status: row.shareholder_status,
          status_label: mapShareholderStatus(row.shareholder_status),
          payment_status: row.shareholder_payment_status,
          payment_status_label: mapPaymentStatus(
            row.shareholder_payment_status,
          ),
          animal_id: row.animal_id,
          share_number: row.share_number,
          qurbani_datetime: row.qurbani_datetime,
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
  const authUserId = req.user.id;

  if (authUserId !== userId) {
    return res.status(403).json({ message: "Unauthorized" });
  }

  if (!orderId || !title || !description) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    // Insert request
    await pool.execute(
      `INSERT INTO requests (order_id, user_id, title, description, status)
       VALUES (?, ?, ?, ?, 'Pending')`,
      [orderId, userId, title, description],
    );

    // 🔔 ============================
    // 🔔 SEND PUSH TO ADMIN
    // 🔔 ============================
    try {
      // Get admin_id from order
      const [orderRows] = await pool.execute(
        `SELECT admin_id FROM orders WHERE id = ?`,
        [orderId],
      );

      if (orderRows.length) {
        const adminId = orderRows[0].admin_id;

        // Get admin devices
        const [devices] = await pool.execute(
          `SELECT subscription_id FROM user_devices WHERE user_id = ?`,
          [adminId],
        );

        const subscriptionIds = devices.map((d) => d.subscription_id);
        const shortOrderId = orderId.toString().substring(0, 6);
        if (subscriptionIds.length > 0) {
          await sendPushNotification(
            subscriptionIds,
            "📩 New Special Request",
            `A new request has been submitted for Order #${shortOrderId}.`,
            {
              type: "NEW_SPECIAL_REQUEST",
              orderId,
              userId,
              title,
            },
          );
        }
      }
    } catch (pushErr) {
      logger.error("Admin notification failed", {
        orderId,
        error: pushErr.message,
      });
    }

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

function mapShareholderStatus(status) {
  switch (Number(status)) {
    case 0:
      return "Not started";
    case 1:
      return "Qurbani Started";
    case 2:
      return "Processing";
    case 3:
      return "Meat Packaged";
    case 4:
      return "Sent for delivery";
    case 5:
      return "Delivered";
    case 6:
      return "Cancelled";
    default:
      return "Unknown";
  }
}

function mapPaymentStatus(status) {
  switch (Number(status)) {
    case 0:
      return "Pending";
    case 1:
      return "Paid";
    case 2:
      return "Unpaid";
    default:
      return "Unknown";
  }
}

function mapPaymentMethod(method) {
  switch (Number(method)) {
    case 0:
      return "Cash";
    case 1:
      return "Online";
    default:
      return "Unknown";
  }
}

// orders/admin/:orderId
router.get("/admin/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const adminId = req.user.id;

  try {
    const [orders] = await pool.execute(
      `
      SELECT 
        o.id,
        o.user_id,
        o.admin_id,
        o.payment_method,
        o.total_shares,
        o.total_amt,
        o.payment_status,
        o.status AS order_status,
        o.created_at,
        u.name AS user_name,
        u.email AS user_email,
        u.phone AS contact_no,
        u.address,
        a.name AS admin_name
      FROM orders o
      JOIN users u ON o.user_id = u.id
      JOIN users a ON o.admin_id = a.id
      WHERE o.id = ? AND o.admin_id = ?
      `,
      [orderId, adminId],
    );

    if (!orders.length) {
      return res
        .status(404)
        .json({ message: "Order not found or not authorized" });
    }

    const order = orders[0];

    const [shareholders] = await pool.execute(
      `
      SELECT 
        s.id,
        s.shareholder_name,
        s.guardian_name,
        s.animal_id,
        s.share_number,
        s.qurbani_datetime,
        s.address,
        s.status,
        s.payment_status,
        an.animal_type
      FROM shareholder_details s
      LEFT JOIN animals an ON s.animal_id = an.id
      WHERE s.order_id = ?
      `,
      [order.id],
    );

    const formattedShareholders = shareholders.map((s) => ({
      id: s.id,
      shareholder_name: s.shareholder_name,
      guardian_name: s.guardian_name,
      animal_id: s.animal_id,
      animal_type: s.animal_type,
      share_number: s.share_number,
      qurbani_datetime: s.qurbani_datetime,
      address: s.address,
      status: s.status,
      status_label: mapShareholderStatus(s.status),
      payment_status: s.payment_status,
      payment_status_label: mapPaymentStatus(s.payment_status),
    }));

    const orderWithDetails = {
      orderId: order.id,
      user_name: order.user_name,
      email: order.user_email,
      total_amt: order.total_amt,
      contact_no: order.contact_no,
      address: order.address,
      total_shares: order.total_shares,
      payment_status: order.payment_status,
      payment_status_label: mapPaymentStatus(order.payment_status),
      payment_method: order.payment_method,
      payment_method_label: mapPaymentMethod(order.payment_method),
      order_status: order.order_status,
      created_at: order.created_at,
      shareholders: formattedShareholders,
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
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    // 1) Verify order exists and belongs to logged-in user
    const [orders] = await pool.execute(
      `SELECT id, user_id, created_at, status
       FROM orders
       WHERE id = ? AND user_id = ?`,
      [orderId, userId]
    );

    if (!orders.length) {
      logger.warn("Order cancellation attempt on missing or unauthorized order", {
        userId,
        orderId,
        reason: "Order not found or does not belong to user",
      });

      return res.status(404).json({ message: "Order not found" });
    }

    const order = orders[0];

    // 2) Get shareholder statuses for this order
    const [shareholders] = await pool.execute(
      `SELECT status
       FROM shareholder_details
       WHERE order_id = ?`,
      [orderId]
    );

    const statuses = shareholders.map((s) => Number(s.status));
    const isDelivered = statuses.some((s) => s === 5); // 5 = Delivered
    const isCancelled = statuses.some((s) => s === 6) || Number(order.status) === 2; // 6 = Cancelled, order.status 2 = cancelled

    // 3) Check 24-hour cancellation rule
    const timeSinceOrder = Date.now() - new Date(order.created_at).getTime();
    const within24Hours = timeSinceOrder < 24 * 60 * 60 * 1000;
    const orderAgeHours = Math.floor(timeSinceOrder / (1000 * 60 * 60));
    const orderAgeMinutes = Math.floor(timeSinceOrder / (1000 * 60));

    const canCancel = within24Hours && !isDelivered && !isCancelled;

    if (!canCancel) {
      logger.warn("Invalid order cancellation attempt - business rules violation", {
        userId,
        orderId,
        orderStatus: order.status,
        shareholderStatuses: statuses,
        within24Hours,
        orderAgeHours,
        isDelivered,
        isCancelled,
        reason: !within24Hours
          ? "Outside 24-hour window"
          : isDelivered
            ? "Order already delivered"
            : "Order already cancelled",
      });

      return res.status(400).json({ message: "Cannot cancel this order" });
    }

    // 4) Cancel order and all associated shareholders
    await pool.execute(
      `UPDATE orders
       SET status = 2
       WHERE id = ? AND user_id = ?`,
      [orderId, userId]
    );

    await pool.execute(
      `UPDATE shareholder_details
       SET status = 6
       WHERE order_id = ?`,
      [orderId]
    );

    logger.info("Order successfully cancelled by user", {
      userId,
      orderId,
      orderAgeMinutes,
      cancellationType: "user_initiated",
      previousOrderStatus: order.status,
      previousShareholderStatuses: statuses,
    });

    // 5) Send push notification to user's registered devices
    try {
      const [devices] = await pool.execute(
        `SELECT subscription_id
         FROM user_devices
         WHERE user_id = ? AND subscription_id IS NOT NULL`,
        [userId]
      );

      const subscriptionIds = devices
        .map((d) => d.subscription_id)
        .filter(Boolean);

      if (subscriptionIds.length > 0) {
        const title = `Order #${orderId} Cancelled`;
        const message = `Your Qurbani order #${orderId} has been cancelled successfully.`;

        await sendPushNotification(subscriptionIds, title, message, {
          type: "ORDER_CANCELLED",
          orderId: Number(orderId),
          status: 2,
        });

        logger.info("Order cancellation notification sent", {
          userId,
          orderId,
          devicesCount: subscriptionIds.length,
        });
      } else {
        logger.warn("No device subscriptions found for cancellation notification", {
          userId,
          orderId,
        });
      }
    } catch (pushErr) {
      logger.error("Failed to send order cancellation notification", {
        userId,
        orderId,
        error: pushErr.message,
        stack: pushErr.stack,
      });
    }

    return res.json({ message: "Order cancelled successfully" });
  } catch (err) {
    logger.error("Error processing order cancellation", {
      userId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    return res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

// PUT /api/orders/:orderId/payment-success - Update order payment status after online payment completion
// Called by payment gateway webhook or frontend after successful payment processing
// Marks order as paid and stores payment gateway reference ID for reconciliation
// Critical for order fulfillment workflow and financial tracking
router.put("/:orderId/payment-success", authMiddleware, async (req, res) => {
  // Extract order ID from URL parameters
  const { orderId } = req.params;
  // Extract payment gateway ID from request body
  const { paymentId } = req.body;
  // Get authenticated user's ID for security validation
  const userId = req.user.id;

  console.log("payment starting", { orderId, paymentId, userId });

  try {
    // Step 1: Update order payment status in database
    // Sets payment_status to 'paid' and stores payment gateway reference
    // Security: WHERE clause ensures users can only update their own orders
    await pool.execute(
      `UPDATE orders
       SET payment_status='paid', payment_id=?
       WHERE id=? AND user_id=?`,
      [paymentId, orderId, userId],
    );

    // Step 2: Log successful payment update for audit trail and financial tracking
    logger.info("Order payment status updated to paid successfully", {
      userId,
      orderId,
      paymentId,
      paymentMethod: "online_payment",
      updateType: "payment_success_callback",
      previousStatus: "pending/unpaid", // Assumed based on context
      newStatus: "paid",
    });
    console.log("payment done");

    // Return success response to payment gateway or frontend
    res.json({ message: "Payment status updated successfully" });
  } catch (err) {
    // Log error with comprehensive context for payment reconciliation debugging
    logger.error("Error updating order payment status", {
      userId,
      orderId,
      paymentId,
      error: err.message,
      stack: err.stack,
      impact:
        "Payment may not be properly recorded - manual reconciliation required",
    });
    // Return generic error message to client
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

module.exports = router;

const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const auth = require("../middleware/authmiddleware");

const adminOnly = (req, res, next) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({ message: "Admin access required" });
  }
  next();
};

// GET /api/orders/admin/my
router.get("/my", auth, adminOnly, async (req, res) => {
  const adminId = req.user.id;

  logger.info("Admin fetching own orders", { adminId });

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



// GET /api/orders/admin/:orderId
router.get("/:orderId", auth, adminOnly, async (req, res) => {
  const { orderId } = req.params;
  const adminId = req.user.id;

  logger.info("Admin fetching order details", {
    adminId,
    orderId,
  });

  try {
    const [orders] = await pool.execute(
      `SELECT o.id, o.user_id, o.admin_id, o.total_shares, o.processing_status, o.delivery_status, o.delivery_person_id, o.payment_status
       FROM orders o
       WHERE o.id = ? AND o.admin_id = ?`,
      [orderId, adminId],
    );

    if (!orders.length) {
      logger.warn("Admin tried to access unauthorized order", {
        adminId,
        orderId,
      });
      return res
        .status(404)
        .json({ message: "Order not found or not authorized" });
    }

    const [shareholders] = await pool.execute(
      `SELECT id, shareholder_name, guardian_name, qurbani_day FROM order_shareholders WHERE order_id = ?`,
      [orderId],
    );

    logger.info("Admin order details fetched", {
      adminId,
      orderId,
      shareholderCount: shareholders.length,
    });

    res.json({
      order: {
        orderId,
        processing_status: orders[0].processing_status,
        delivery_status: orders[0].delivery_status || "pending",
        delivery_person_id: orders[0].delivery_person_id,
        shareholders,
      },
    });
  } catch (err) {
    logger.error("Failed to fetch admin order", {
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

router.put("/:orderId", auth, adminOnly, async (req, res) => {
  const { orderId } = req.params;

  const {
    delivery_person_id,
    qurbani_time,
  } = req.body;

  // console.log(delivery_status);

  const adminId = req.user.id;

  try {
    const [[order]] = await pool.execute(
      `SELECT processing_status, qurbani_time
       FROM orders
       WHERE id = ? AND admin_id = ?`,
      [orderId, adminId],
    );

    if (!order) {
      return res.status(404).json({
        message: "Order not found or unauthorized",
      });
    }

    let nextProcessingStatus = order.processing_status;

    /**
     * 🧱 RULE 1:
     * pending → confirmed ONLY if qurbani_time provided
     */
    if (order.processing_status === "pending") {
      if (!qurbani_time) {
        return res.status(400).json({
          message: "Qurbani date & time is required",
        });
      }

      nextProcessingStatus = "confirmed";
    }

    /**
     * 🧱 RULE 2:
     * Cannot assign delivery person unless confirmed
     */
    if (delivery_person_id && nextProcessingStatus !== "confirmed") {
      return res.status(400).json({
        message: "Delivery person can only be assigned after confirmation",
      });
    }

    await pool.execute(
      `UPDATE orders SET
     processing_status = ?,
     qurbani_time = COALESCE(?, qurbani_time),
     delivery_person_id = COALESCE(?, delivery_person_id),
     delivery_notified = 0
   WHERE id = ?`,
      [
        nextProcessingStatus,
        qurbani_time ?? null,
        delivery_person_id ?? null,
        orderId,
      ],
    );

    res.json({
      message: "Order updated successfully",
      processing_status: nextProcessingStatus,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({
      message: "Internal server error",
    });
  }
});

module.exports = router;

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
      `SELECT o.id, o.user_id, o.admin_id, o.payment_method, o.total_shares, o.status, o.created_at
       FROM orders o
       WHERE o.admin_id = ?
       ORDER BY o.created_at DESC`,
      [adminId]
    );

    const ordersWithDetails = await Promise.all(
      orders.map(async (order) => {
        const [shareholders] = await pool.execute(
          `SELECT id, name, guardian_name, qurbani_day FROM shareholders WHERE order_id = ?`,
          [order.id]
        );

        return {
          orderId: order.id,
          adminId: order.admin_id,
          deliveryStatus: "pending",
          processingStatus: order.status,
          isCompleted: order.status === "completed",
          createdAt: order.created_at,
          shareholders,
        };
      })
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

    res.status(500).json({ message: "Something went wrong. Please try again later." });
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
      `SELECT o.id, o.user_id, o.admin_id, o.total_shares, o.status, o.delivery_status, o.delivery_person_id
       FROM orders o
       WHERE o.id = ? AND o.admin_id = ?`,
      [orderId, adminId]
    );

    if (!orders.length) {
      logger.warn("Admin tried to access unauthorized order", {
        adminId,
        orderId,
      });
      return res.status(404).json({ message: "Order not found or not authorized" });
    }

    const [shareholders] = await pool.execute(
      `SELECT id, name, guardian_name, qurbani_day FROM shareholders WHERE order_id = ?`,
      [orderId]
    );

    logger.info("Admin order details fetched", {
      adminId,
      orderId,
      shareholderCount: shareholders.length,
    });

    res.json({
      order: {
        orderId,
        processing_status: orders[0].status,
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

    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});




router.put("/:orderId", auth, adminOnly, async (req, res) => {
  const { orderId } = req.params;
  const { processingStatus, deliveryStatus, deliveryPersonId } = req.body;
  const adminId = req.user.id;

  logger.info("Admin updating order status", {
    adminId,
    orderId,
    processingStatus,
    deliveryStatus,
  });

  try {
    const [orders] = await pool.execute(
      `SELECT id FROM orders WHERE id = ? AND admin_id = ?`,
      [orderId, adminId]
    );

    if (!orders.length) {
      logger.warn("Admin attempted unauthorized order update", {
        adminId,
        orderId,
      });
      return res.status(404).json({ message: "Order not found or not authorized" });
    }

    await pool.execute(
      `UPDATE orders 
       SET status = ?, delivery_status = ?, delivery_person_id = ?, delivery_notified = 0
       WHERE id = ?`,
      [processingStatus, deliveryStatus, deliveryPersonId || null, orderId]
    );

    logger.info("Order updated successfully", {
      adminId,
      orderId,
    });

    res.json({ message: "Order updated successfully" });
  } catch (err) {
    logger.error("Failed to update order", {
      adminId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});



module.exports = router;

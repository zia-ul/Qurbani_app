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
    const adminId = req.user.id; // Assuming JWT provides admin's user ID

  try {
    const [orders] = await pool.execute(
      `SELECT o.id, o.user_id, o.admin_id, o.payment_method, o.total_shares, o.status, o.created_at,
              u.name as admin_name, u.email as admin_email
       FROM orders o
       JOIN users u ON o.admin_id = u.id
       WHERE o.admin_id = ?
       ORDER BY o.created_at DESC`,
      [adminId]
    );

    // For each order, fetch shareholders and map to expected structure
    const ordersWithDetails = await Promise.all(
      orders.map(async (order) => {
        const [shareholders] = await pool.execute(
          `SELECT id, name, guardian_name, qurbani_day FROM shareholders WHERE order_id = ?`,
          [order.id]
        );

        // Map to Flutter-expected structure (add defaults for missing fields)
        return {
          orderId: order.id,
          adminId: order.admin_id,
          deliveryStatus: 'pending', // Default; add column to orders table if needed
          processingStatus: order.status, // Maps to status (pending, confirmed, etc.)
          isCompleted: order.status === 'completed', // For filtering
          createdAt: order.created_at,
          contact: { primary: '' }, // Placeholder; join users table for phone if available
          shareholders, // Include for details if needed
          // Add other fields as needed (e.g., totalShares: order.total_shares)
        };
      })
    );

    res.json({ orders: ordersWithDetails });
  } catch (err) {
    console.error("Error fetching admin orders:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// GET /api/orders/admin/:orderId
router.get("/:orderId", auth, adminOnly, async (req, res) => {
  const { orderId } = req.params;
  const adminId = req.user.id; // Admin's user ID from JWT

  console.log("Fetching order for admin:", adminId, "orderId:", orderId);

  try {
    const [orders] = await pool.execute(
      `SELECT o.id, o.user_id, o.admin_id, o.payment_method, o.total_shares, o.status, o.delivery_status, o.delivery_person_id, o.created_at,
              u.name as user_name, u.email as user_email, u.phone as contact_no,
              a.name as admin_name
       FROM orders o
       JOIN users u ON o.user_id = u.id
       JOIN users a ON o.admin_id = a.id
       WHERE o.id = ? AND o.admin_id = ?`,  // Restrict to admin's own orders
      [orderId, adminId]
    );

    console.log(orders);

    if (orders.length === 0) {
      return res.status(404).json({ message: "Order not found or not authorized" });
    }

    const order = orders[0];

    // Fetch shareholders for the order
    const [shareholders] = await pool.execute(
      `SELECT id, name, guardian_name, qurbani_day FROM shareholders WHERE order_id = ?`,
      [order.id]
    );

    // Structure the response to match admin frontend expectations
    const orderWithDetails = {
      orderId: order.id,
      user_name: order.user_name,
      animal_type: 'Sheep',  // Dummy, as per schema
      parts: shareholders.map(s => s.name).join(', '),  // Map to parts
      total_amount: 100 * order.total_shares,  // Dummy calculation
      payment_status: 'Paid',  // Default
      delivery_address: 'N/A',  // Default; add to schema if needed
      contact_no: order.contact_no || 'N/A',
      processing_status: order.status,
      delivery_status: order.delivery_status || 'pending',
      delivery_person_id: order.delivery_person_id,
      shareholders,  // Include for reference
    };

    res.json({ order: orderWithDetails });
  } catch (err) {
    console.error("Error fetching admin order:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

router.put("/:orderId", auth, adminOnly, async (req, res) => {
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
      [orderId, adminId]
    );
    if (orders.length === 0) {
      return res.status(404).json({ message: "Order not found or not authorized" });
    }

    // Update order
    await pool.execute(
      `UPDATE orders SET status = ?, delivery_status = ?, delivery_person_id = ? WHERE id = ?`,
      [processingStatus, deliveryStatus, deliveryPersonId || null, orderId]
    );

    res.json({ message: "Order updated successfully" });
  } catch (err) {
    console.error("Error updating order:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});


module.exports = router;

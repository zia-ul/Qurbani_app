const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");

// GET /api/profile - Fetch authenticated user's profile
router.get("/profile", authMiddleware, async (req, res) => {
  const userId = req.user.id;
  try {
    const [users] = await pool.execute(
      "SELECT name, email, phone, address, description, role, order_deadline FROM users WHERE id = ?",
      [userId]
    );
    if (users.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }
    const user = users[0];
    res.json({
      profile: {
        name: user.name,
        email: user.email,
        phone: user.phone,
        address: user.address,
        description: user.description,
        photoUrl: user.photo_url,
        isAdmin: user.role === "admin",
        orderDeadline: user.order_deadline,
      },
    });
  } catch (err) {
    console.error("Error fetching profile:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// PUT /api/profile - Update authenticated user's profile
router.put("/profile", authMiddleware, async (req, res) => {
  const userId = req.user.id;
  const { name, phone, address, description, photoUrl, orderDeadline } =
    req.body;

  if (!name || name.trim().length < 3) {
    return res
      .status(400)
      .json({ message: "Name must be at least 3 characters" });
  }

  try {
    await pool.execute(
      "UPDATE users SET name = ?, phone = ?, address = ?, description = ?, order_deadline = ? WHERE id = ?",
      [
        name.trim(),
        phone?.trim(),
        address?.trim(),
        description?.trim(),
        orderDeadline,
        userId,
      ]
    );
    res.json({ message: "Profile updated successfully" });
  } catch (err) {
    console.error("Error updating profile:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// GET /api/delivery-boys - Fetch all delivery boys (users with role 'delivery')
router.get("/delivery-boys", authMiddleware, async (req, res) => {
  try {
    const [deliveryBoys] = await pool.execute(
      `SELECT id, name, phone, address FROM users WHERE role = 'delivery'`,
      []
    );
    res.json({ deliveryBoys });
  } catch (err) {
    console.error("Error fetching delivery boys:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// ADMIN VERIFICATION ROUTES

// POST /api/admin/verification - Submit admin verification
router.post("/verification", authMiddleware, async (req, res) => {
  const userId = req.user.id;
  const { name, email, phone, governmentId, address, documentUrls } = req.body;

  try {
    const verificationId = uuidv4();
    await pool.execute(
      `INSERT INTO admin_verifications (id, admin_id, documents, status) VALUES (?, ?, ?, 'pending')`,
      [
        verificationId,
        userId,
        JSON.stringify({
          name,
          email,
          phone,
          governmentId,
          address,
          documentUrls,
        }),
      ]
    );
    res.status(201).json({ message: "Verification submitted" });
  } catch (err) {
    console.error("Error submitting verification:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// GET /api/admin/verification/status - Check verification status
router.get("/verification/status", authMiddleware, async (req, res) => {
  const userId = req.user.id;

  try {
    const [verifications] = await pool.execute(
      `SELECT status FROM admin_verifications WHERE admin_id = ?`,
      [userId]
    );
    if (verifications.length === 0) {
      return res.json({ status: null });
    }
    res.json({ status: verifications[0].status });
  } catch (err) {
    console.error("Error fetching status:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// SUPERADMIN ROUTES

// GET /api/superadmin/users - List users by role (for super admin)
router.get("/superadmin/users", authMiddleware, async (req, res) => {
  const { role } = req.query; // 'all', 'user', 'admin', 'pending', 'delivery'
  const superAdminId = req.user.id;

  // Check if user is superadmin
  const [superAdmins] = await pool.execute(
    `SELECT role FROM users WHERE id = ?`,
    [superAdminId]
  );
  if (superAdmins.length === 0 || superAdmins[0].role !== "super_admin") {
    return res.status(403).json({ message: "Access denied" });
  }

  let query = `SELECT id, name, email, phone, role, created_at FROM users WHERE role != 'superadmin'`;
  let params = [];

  if (role && role !== "all") {
    if (role === "pending") {
      query += ` AND role = 'pending'`;
    } else {
      query += ` AND role = ?`;
      params = [role];
    }
  }

  query += ` ORDER BY created_at DESC`;

  try {
    const [users] = await pool.execute(query, params);
    res.json({ users });
  } catch (err) {
    console.error("Error fetching users:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// PUT /api/superadmin/users/:id - Update user role or delete (for super admin)
router.put("/superadmin/users/:id", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { action } = req.body; // 'approve', 'reject', 'revoke'
  const superAdminId = req.user.id;

  // Check superadmin
  const [superAdmins] = await pool.execute(
    `SELECT role FROM users WHERE id = ?`,
    [superAdminId]
  );
  if (superAdmins.length === 0 || superAdmins[0].role !== "super_admin") {
    return res.status(403).json({ message: "Access denied" });
  }

  try {
    if (action === "approve") {
      await pool.execute(`UPDATE users SET role = 'admin' WHERE id = ?`, [id]);
      await pool.execute(
        `UPDATE admin_verifications SET status = 'verified' WHERE admin_id = ?`,
        [id]
      );
    } else if (action === "reject" || action === "revoke") {
      await pool.execute(`DELETE FROM users WHERE id = ?`, [id]);
      await pool.execute(`DELETE FROM admin_verifications WHERE admin_id = ?`, [
        id,
      ]);
    }
    res.json({ message: "Action completed" });
  } catch (err) {
    console.error("Error updating user:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// GET /api/superadmin/verifications/:adminId - Fetch verification details
router.get(
  "/superadmin/verifications/:adminId",
  authMiddleware,
  async (req, res) => {
    const { adminId } = req.params;
    const superAdminId = req.user.id;

    // Check superadmin
    const [superAdmins] = await pool.execute(
      `SELECT role FROM users WHERE id = ?`,
      [superAdminId]
    );
    if (superAdmins.length === 0 || superAdmins[0].role !== "super_admin") {
      return res.status(403).json({ message: "Access denied" });
    }

    try {
      const [verifications] = await pool.execute(
        `SELECT documents, status FROM admin_verifications WHERE admin_id = ?`,
        [adminId]
      );
      if (verifications.length === 0) {
        return res.status(404).json({ message: "No verification found" });
      }
      res.json({ verification: verifications[0] });
    } catch (err) {
      console.error("Error fetching verification:", err);
      res.status(500).json({ message: "Internal server error" });
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
      [deliveryPersonId]
    );

    res.json({ orders });
  } catch (err) {
    console.error("Error fetching delivery orders:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});



// PUT /api/delivery/orders/:id/status - Update delivery status
router.put("/delivery/orders/:id/status", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  const deliveryPersonId = req.user.id;

  try {
    let updateQuery = `UPDATE orders SET delivery_status = ?`;
    let params = [status];

    if (status === "sent") {
      const code = Math.floor(100000 + Math.random() * 900000).toString();
      updateQuery += `, delivery_code = ?`;
      params.push(code);
      // Notify user (e.g., send SMS/email with code)
      // Implement notification logic here
    } else if (status === "delivered") {
      updateQuery += `, delivered_at = NOW(), delivery_code = NULL`;
    }

    updateQuery += ` WHERE id = ? AND delivery_person_id = ?`;
    params.push(id, deliveryPersonId);

    const [result] = await pool.execute(updateQuery, params);
    if (result.affectedRows === 0) {
      return res
        .status(404)
        .json({ message: "Order not found or not assigned" });
    }

    res.json({
      message: "Status updated",
      code: status === "sent" ? params[1] : null,
    });
  } catch (err) {
    console.error("Error updating status:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// PUT /api/delivery/orders/:id/verify - Verify delivery code
router.put("/delivery/orders/:id/verify", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { code } = req.body;
  const deliveryPersonId = req.user.id;

  try {
    const [orders] = await pool.execute(
      `SELECT delivery_code FROM orders WHERE id = ? AND delivery_person_id = ?`,
      [id, deliveryPersonId]
    );
    if (orders.length === 0 || orders[0].delivery_code !== code) {
      return res.status(400).json({ message: "Invalid code" });
    }

    await pool.execute(
      `UPDATE orders SET delivery_status = 'delivered', delivered_at = NOW(), delivery_code = NULL WHERE id = ?`,
      [id]
    );
    res.json({ message: "Order delivered" });
  } catch (err) {
    console.error("Error verifying code:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// PUT /api/profile/currency
router.put("/profile/currency", authMiddleware, async (req, res) => {
  const { currency } = req.body;
  const userId = req.user.id;

  try {
    await pool.execute(`UPDATE users SET currency = ? WHERE id = ?`, [
      currency,
      userId,
    ]);
    res.json({ message: "Currency updated" });
  } catch (err) {
    console.error("Error updating currency:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// GET /api/special-requests - Fetch user's special requests
router.get("/special-requests", authMiddleware, async (req, res) => {
  const userId = req.user.id;

  try {
    const [requests] = await pool.execute(
      `SELECT id, title, description, status, created_at, reply_message, replied_at FROM requests WHERE user_id = ? ORDER BY created_at DESC`,
      [userId]
    );
    res.json({ requests });
  } catch (err) {
    console.error("Error fetching special requests:", err);
    res.status(500).json({ message: "Internal server error" });
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
      [animalId]
    );
    res.json({ orders });
  } catch (err) {
    console.error("Error fetching orders for animal:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

const controller = require("../controllers/admin_payment_settings");

// User order page 
router.get(
  "/admins/:adminId/payment-settings",
  controller.getAdminPaymentSettingsPublic
);


module.exports = router;

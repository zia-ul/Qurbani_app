// // routes/users.js
// const express = require('express');
// const router = express.Router();
// const pool = require('../config/db');
// const authMiddleware = require('../middleware/authmiddleware');

// // GET /api/profile - Fetch authenticated user's profile
// router.get('/profile', authMiddleware, async (req, res) => {
//   const userId = req.user.id;
//   try {
//     const [users] = await pool.execute(
//       'SELECT name, email, phone, address, description FROM users WHERE id = ?',
//       [userId]
//     );
//     if (users.length === 0) {
//       return res.status(404).json({ message: 'User not found' });
//     }
//     res.json({ profile: users[0] });
//   } catch (err) {
//     console.error('Error fetching profile:', err);
//     res.status(500).json({ message: 'Internal server error' });
//   }
// });

// // PUT /api/profile - Update authenticated user's profile
// router.put('/profile', authMiddleware, async (req, res) => {
//   const userId = req.user.id;
//   const { name, phone, address, description } = req.body;

//   if (!name || name.trim().length < 3) {
//     return res.status(400).json({ message: 'Name must be at least 3 characters' });
//   }

//   try {
//     await pool.execute(
//       'UPDATE users SET name = ?, phone = ?, address = ?, description = ? WHERE id = ?',
//       [name.trim(), phone?.trim(), address?.trim(), description?.trim(), userId]
//     );
//     res.json({ message: 'Profile updated successfully' });
//   } catch (err) {
//     console.error('Error updating profile:', err);
//     res.status(500).json({ message: 'Internal server error' });
//   }
// });

// // GET /api/delivery-boys - Fetch all delivery boys (users with role 'delivery')
// router.get("/delivery-boys", authMiddleware, async (req, res) => {
//   try {
//     const [deliveryBoys] = await pool.execute(
//       `SELECT id, name, phone, address FROM users WHERE role = 'delivery'`,
//       []
//     );
//     res.json({ deliveryBoys });
//   } catch (err) {
//     console.error("Error fetching delivery boys:", err);
//     res.status(500).json({ message: "Internal server error" });
//   }
// });

// module.exports = router;

const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const authMiddleware = require('../middleware/authmiddleware');

// GET /api/profile - Fetch authenticated user's profile
router.get('/profile', authMiddleware, async (req, res) => {
  const userId = req.user.id;
  try {
    const [users] = await pool.execute(
      'SELECT name, email, phone, address, description, photo_url, role, order_deadline FROM users WHERE id = ?',
      [userId]
    );
    if (users.length === 0) {
      return res.status(404).json({ message: 'User not found' });
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
        isAdmin: user.role === 'admin',
        orderDeadline: user.order_deadline,
      }
    });
  } catch (err) {
    console.error('Error fetching profile:', err);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// PUT /api/profile - Update authenticated user's profile
router.put('/profile', authMiddleware, async (req, res) => {
  const userId = req.user.id;
  const { name, phone, address, description, photoUrl, orderDeadline } = req.body;

  if (!name || name.trim().length < 3) {
    return res.status(400).json({ message: 'Name must be at least 3 characters' });
  }

  try {
    await pool.execute(
      'UPDATE users SET name = ?, phone = ?, address = ?, description = ?, photo_url = ?, order_deadline = ? WHERE id = ?',
      [name.trim(), phone?.trim(), address?.trim(), description?.trim(), photoUrl, orderDeadline, userId]
    );
    res.json({ message: 'Profile updated successfully' });
  } catch (err) {
    console.error('Error updating profile:', err);
    res.status(500).json({ message: 'Internal server error' });
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
      [verificationId, userId, JSON.stringify({ name, email, phone, governmentId, address, documentUrls })]
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
  const [superAdmins] = await pool.execute(`SELECT role FROM users WHERE id = ?`, [superAdminId]);
  if (superAdmins.length === 0 || superAdmins[0].role !== 'superadmin') {
    return res.status(403).json({ message: "Access denied" });
  }

  let query = `SELECT id, name, email, phone, role, created_at FROM users WHERE role != 'superadmin'`;
  let params = [];

  if (role && role !== 'all') {
    if (role === 'pending') {
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
  const [superAdmins] = await pool.execute(`SELECT role FROM users WHERE id = ?`, [superAdminId]);
  if (superAdmins.length === 0 || superAdmins[0].role !== 'superadmin') {
    return res.status(403).json({ message: "Access denied" });
  }

  try {
    if (action === 'approve') {
      await pool.execute(`UPDATE users SET role = 'admin' WHERE id = ?`, [id]);
      await pool.execute(`UPDATE admin_verifications SET status = 'verified' WHERE admin_id = ?`, [id]);
    } else if (action === 'reject' || action === 'revoke') {
      await pool.execute(`DELETE FROM users WHERE id = ?`, [id]);
      await pool.execute(`DELETE FROM admin_verifications WHERE admin_id = ?`, [id]);
    }
    res.json({ message: "Action completed" });
  } catch (err) {
    console.error("Error updating user:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

// GET /api/superadmin/verifications/:adminId - Fetch verification details
router.get("/superadmin/verifications/:adminId", authMiddleware, async (req, res) => {
  const { adminId } = req.params;
  const superAdminId = req.user.id;

  // Check superadmin
  const [superAdmins] = await pool.execute(`SELECT role FROM users WHERE id = ?`, [superAdminId]);
  if (superAdmins.length === 0 || superAdmins[0].role !== 'superadmin') {
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
});

module.exports = router;
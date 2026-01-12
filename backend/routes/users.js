// routes/users.js
const express = require('express');
const router = express.Router();
const pool = require('../config/db');
const authMiddleware = require('../middleware/authmiddleware');

// GET /api/profile - Fetch authenticated user's profile
router.get('/profile', authMiddleware, async (req, res) => {
  const userId = req.user.id;
  try {
    const [users] = await pool.execute(
      'SELECT name, email, phone, address, description FROM users WHERE id = ?',
      [userId]
    );
    if (users.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.json({ profile: users[0] });
  } catch (err) {
    console.error('Error fetching profile:', err);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// PUT /api/profile - Update authenticated user's profile
router.put('/profile', authMiddleware, async (req, res) => {
  const userId = req.user.id;
  const { name, phone, address, description } = req.body;

  if (!name || name.trim().length < 3) {
    return res.status(400).json({ message: 'Name must be at least 3 characters' });
  }

  try {
    await pool.execute(
      'UPDATE users SET name = ?, phone = ?, address = ?, description = ? WHERE id = ?',
      [name.trim(), phone?.trim(), address?.trim(), description?.trim(), userId]
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

module.exports = router;
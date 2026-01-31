const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");
/**
 * GET /api/users/currencies
 */
router.get("/currencies", async (req, res) => {
  try {
    const [[meta]] = await pool.execute(
      `SELECT base_currency, last_updated FROM currency_meta WHERE id = 1`,
    );

    const [rows] = await pool.execute(
      `SELECT currency_code, rate FROM currency_rates`,
    );

    const rates = {};
    rows.forEach((r) => {
      rates[r.currency_code] = Number(r.rate);
    });

    console.log("Currency endpoint hit");

    res.json({
      base: meta.base_currency,
      lastUpdated: meta.last_updated,
      rates,
    });
  } catch (err) {
    console.error("Currency fetch failed:", err);
    res.status(500).json({ message: "Failed to fetch currencies" });
  }
});

/**
 * GET /users/me/currency
 * Returns the logged-in user's currency
 */
router.get('/:userId/currency', async (req, res) => {
  try {
    const userId = req.params.userId;

    const [user] = await db.query(
      'SELECT currency FROM users WHERE id = ? LIMIT 1',
      [userId]
    );

    if (!user || user.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }

    return res.json({
      currency: user[0].currency || 'USD', // default USD if null
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: 'Server error' });
  }
});


router.put("/profile/currency", authMiddleware, async (req, res) => {
  const { currency } = req.body;
  const userId = req.user.id;

  try {
    await pool.execute(`UPDATE users SET currency = ? WHERE id = ?`, [
      currency,
      userId,
    ]);
    logger.info("Currency updated", { userId });
    res.json({ message: "Currency updated" });
  } catch (err) {
    logger.error("Currency update failed", {
      userId,
      error: err.message,
    });
    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
});

module.exports = router;

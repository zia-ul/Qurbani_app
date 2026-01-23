const express = require("express");
const router = express.Router();
const pool = require("../config/db");

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

module.exports = router;

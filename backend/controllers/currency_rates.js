const axios = require("axios");
const pool = require("../config/db");
require("dotenv").config();

const API_KEY = process.env.OPENEXCHANGE_API_KEY;
const API_URL = `https://openexchangerates.org/api/latest.json?app_id=${API_KEY}`;

async function fetchAndStoreRates() {
  if (!API_KEY) {
    console.error("[CURRENCY] Missing API_KEY. Cannot fetch rates.");
    return;
  }
  const conn = await pool.getConnection();
  try {
    const res = await axios.get(API_URL);
    const { rates, base } = res.data;
    const now = new Date();

    await conn.beginTransaction();

    await conn.execute(
      "UPDATE currency_meta SET base_currency=?, last_updated=? WHERE id=1",
      [base, now],
    );

    for (const [code, rate] of Object.entries(rates)) {
      await conn.execute(
        `
          INSERT INTO currency_rates (currency_code, rate, updated_at)
          VALUES (?, ?, ?)
          ON DUPLICATE KEY UPDATE rate=VALUES(rate), updated_at=VALUES(updated_at)
        `,
        [code, rate, now],
      );
    }

    await conn.commit();
    console.log(`[CURRENCY] Rates updated`);
  } catch (err) {
    await conn.rollback();
    console.error("[CURRENCY] Update failed:", err.message);
  } finally {
    conn.release();
  }
}

const setUserCurrency = async (req, res) => {
  try {
    const userId = req.user.id;
    const { currency } = req.body;

    if (!currency || currency.length !== 3) {
      return res.status(400).json({ message: "Invalid currency code" });
    }

    const [result] = await pool.execute(
      "UPDATE users SET currency=? WHERE id=?",
      [currency.toUpperCase(), userId],
    );

    res.json({ message: "Currency updated", currency: currency.toUpperCase() });
  } catch (err) {
    res.status(500).json({ message: "Server error" });
  }
};

module.exports = { fetchAndStoreRates, setUserCurrency };

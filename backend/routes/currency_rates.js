// const express = require("express");
// const router = express.Router();
// const pool = require("../config/db");
// const authMiddleware = require("../middleware/authmiddleware");
// const logger = require("../middleware/logger");
// /**
//  * GET /api/users/currencies
//  */


// /**
//  * @swagger
//  * /api/users/currencies:
//  *   get:
//  *     summary: Get supported currencies and exchange rates
//  *     description: >
//  *       Returns the system base currency, last updated timestamp,
//  *       and a list of supported currencies with their exchange rates.
//  *       This endpoint is public and does not require authentication.
//  *     tags:
//  *       - Currency
//  *     responses:
//  *       200:
//  *         description: Currency rates fetched successfully
//  *         content:
//  *           application/json:
//  *             schema:
//  *               type: object
//  *               properties:
//  *                 base:
//  *                   type: string
//  *                   example: USD
//  *                 lastUpdated:
//  *                   type: string
//  *                   example: "2026-01-31T18:45:00Z"
//  *                 rates:
//  *                   type: object
//  *                   additionalProperties:
//  *                     type: number
//  *                   example:
//  *                     USD: 1
//  *                     PKR: 278.5
//  *                     EUR: 0.92
//  *       500:
//  *         description: Failed to fetch currencies
//  */

// router.get("/currencies", async (req, res) => {
//   try {
//     const [[meta]] = await pool.execute(
//       `SELECT base_currency, last_updated FROM currency_meta WHERE id = 1`,
//     );

//     const [rows] = await pool.execute(
//       `SELECT currency_code, rate FROM currency_rates`,
//     );

//     const rates = {};
//     rows.forEach((r) => {
//       rates[r.currency_code] = Number(r.rate);
//     });

//     console.log("Currency endpoint hit");

//     res.json({
//       base: meta.base_currency,
//       lastUpdated: meta.last_updated,
//       rates,
//     });
//   } catch (err) {
//     console.error("Currency fetch failed:", err);
//     res.status(500).json({ message: "Failed to fetch currencies" });
//   }
// });

// /**
//  * GET /users/me/currency
//  * Returns the logged-in user's currency
//  */

// /**
//  * @swagger
//  * /api/users/{userId}/currency:
//  *   get:
//  *     summary: Get a user's preferred currency
//  *     description: >
//  *       Returns the preferred currency of a specific user.
//  *       If no currency is set, the default value `USD` is returned.
//  *     tags:
//  *       - Currency
//  *     parameters:
//  *       - in: path
//  *         name: userId
//  *         required: true
//  *         schema:
//  *           type: string
//  *           format: uuid
//  *         description: User ID
//  *     responses:
//  *       200:
//  *         description: User currency fetched successfully
//  *         content:
//  *           application/json:
//  *             schema:
//  *               type: object
//  *               properties:
//  *                 currency:
//  *                   type: string
//  *                   example: USD
//  *       404:
//  *         description: User not found
//  *       500:
//  *         description: Server error
//  */

// router.get('/:userId/currency', async (req, res) => {
//   try {
//     const userId = req.params.userId;

//     const [user] = await db.query(
//       'SELECT currency FROM users WHERE id = ? LIMIT 1',
//       [userId]
//     );

//     if (!user || user.length === 0) {
//       return res.status(404).json({ message: 'User not found' });
//     }

//     return res.json({
//       currency: user[0].currency || 'USD', // default USD if null
//     });
//   } catch (err) {
//     console.error(err);
//     return res.status(500).json({ message: 'Server error' });
//   }
// });

// /**
//  * @swagger
//  * /api/users/profile/currency:
//  *   put:
//  *     summary: Update logged-in user's currency
//  *     description: >
//  *       Updates the preferred currency of the currently authenticated user.
//  *       Requires a valid JWT token in the Authorization header.
//  *     tags:
//  *       - Currency
//  *     security:
//  *       - bearerAuth: []
//  *     requestBody:
//  *       required: true
//  *       content:
//  *         application/json:
//  *           schema:
//  *             type: object
//  *             required:
//  *               - currency
//  *             properties:
//  *               currency:
//  *                 type: string
//  *                 example: PKR
//  *     responses:
//  *       200:
//  *         description: Currency updated successfully
//  *         content:
//  *           application/json:
//  *             schema:
//  *               type: object
//  *               properties:
//  *                 message:
//  *                   type: string
//  *                   example: Currency updated
//  *       401:
//  *         description: Unauthorized (missing or invalid JWT)
//  *       500:
//  *         description: Something went wrong. Please try again later.
//  */

// router.put("/profile/currency", authMiddleware, async (req, res) => {
//   const { currency } = req.body;
//   const userId = req.user.id;

//   try {
//     await pool.execute(`UPDATE users SET currency = ? WHERE id = ?`, [
//       currency,
//       userId,
//     ]);
//     logger.info("Currency updated", { userId });
//     res.json({ message: "Currency updated" });
//   } catch (err) {
//     logger.error("Currency update failed", {
//       userId,
//       error: err.message,
//     });
//     res.status(500).json({ message: "Something went wrong. Please try again later." });
//   }
// });


// router.get('/profile/address', authMiddleware, async (req, res) => {
//   try {
//     const userId = req.user.id;

//     const [rows] = await pool.query(
//       `
//       SELECT
//         country,
//         country_iso,
//         state,
//         city,
//         postal_code,
//         address,
//         order_deadline
//       FROM users
//       WHERE id = ?
//       LIMIT 1
//       `,
//       [userId]
//     );

//     if (!rows || rows.length === 0) {
//       return res.status(404).json({ message: 'User not found' });
//     }

//     const user = rows[0];

//     // ✅ If no address saved at all
//     if (
//       !user.country &&
//       !user.state &&
//       !user.city &&
//       !user.address
//     ) {
//       return res.json(null);
//     }

//     // ✅ Match Flutter expectations exactly
//     return res.json({
//       country: user.country,
//       country_iso: user.country_iso,
//       state: user.state,
//       city: user.city,
//       postal_code: user.postal_code,
//       address: user.address,
//     });
//   } catch (err) {
//     console.error('[PROFILE ADDRESS]', err);
//     return res.status(500).json({ message: 'Server error' });
//   }
// });

// module.exports = router;

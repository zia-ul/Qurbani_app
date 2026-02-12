const express = require("express");
const router = express.Router();
const auth = require("../middleware/authmiddleware");
const controller = require("../controllers/admin_payment_settings");

// Admin dashboard
router.get("/payment-settings", auth, controller.getMyPaymentSettings);
router.put("/payment-settings", auth, controller.updateMyPaymentSettings);

const QRCode = require("qrcode");

router.post('/animals/:id/qrcode', auth, async (req, res) => {
  const { id } = req.params;

  const qrData = `animal:${id}`;
  const qrCode = await QRCode.toDataURL(qrData);

  await pool.execute(
    `UPDATE animals SET qr_code = ? WHERE id = ?`,
    [qrCode, id]
  );

  res.json({ qr_code: qrCode });
});


router.get('/animals/:animalId/orders', auth, async (req, res) => {
  const { animalId } = req.params;

  try {
    const [rows] = await pool.execute(
      `
      SELECT 
        s.id AS shareholder_id,
        s.order_id,
        s.shareholder_name,
        s.guardian_name,
        s.qurbani_day,
        s.processing_status,
        s.delivery_status,
        s.payment_status,
        s.created_at,

        o.payment_method,
        o.created_at AS order_created_at,

        u.name AS user_name

      FROM shareholder_details s
      JOIN orders o ON o.id = s.order_id
      JOIN users u ON u.id = o.user_id

      WHERE s.animal_id = ?
      ORDER BY s.created_at DESC
      `,
      [animalId]
    );

    console.log("Fetched orders for animal", { animalId, rows });

    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Failed to fetch animal shareholders' });
  }
});



module.exports = router;

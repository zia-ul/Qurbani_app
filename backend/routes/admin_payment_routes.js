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

  const [rows] = await pool.execute(`
    SELECT o.id, u.name AS user_name,
           o.processing_status, o.payment_status,
           o.delivery_person, o.qurbani_time,
           o.created_at
    FROM orders o
    JOIN users u ON u.id = o.user_id
    JOIN order_animals oa ON oa.order_id = o.id
    WHERE oa.animal_id = ?
    ORDER BY o.created_at DESC
  `, [animalId]);

  res.json(rows);
});


module.exports = router;

// controllers/vendorShareSetup.controller.js
const db = require("../config/db.js");

const saveVendorShareSetup = async (req, res) => {
  try {
    const vendorId = req.user.id;

    const {
      totalShares,
      pricePerShare,
      lateBookingFee = 0,
      lastBookingDate,
      deliveryType,
      deliveryFee = 0,
      deliveryThreshold = null,
    } = req.body;

    if (!totalShares || !pricePerShare || !lastBookingDate || !deliveryType) {
      return res.status(400).json({
        message: "Missing required fields",
      });
    }

    const query = `
      INSERT INTO admin_share_setups (
        admin_id,
        total_shares,
        price_per_share,
        late_booking_fee,
        last_booking_date,
        delivery_type,
        delivery_fee,
        free_delivery_threshold
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        total_shares = VALUES(total_shares),
        price_per_share = VALUES(price_per_share),
        late_booking_fee = VALUES(late_booking_fee),
        last_booking_date = VALUES(last_booking_date),
        delivery_type = VALUES(delivery_type),
        delivery_fee = VALUES(delivery_fee),
        free_delivery_threshold = VALUES(free_delivery_threshold),
        updated_at = CURRENT_TIMESTAMP
    `;

    await db.query(query, [
      vendorId,
      totalShares,
      pricePerShare,
      lateBookingFee,
      lastBookingDate,
      deliveryType,
      deliveryFee,
      deliveryThreshold,
    ]);

    res.status(200).json({
      message: "Share setup saved successfully",
    });
  } catch (err) {
    console.error("Vendor share setup error:", err);
    res.status(500).json({
      message: "Failed to save share setup",
    });
  }
};

module.exports = {
  saveVendorShareSetup,
};

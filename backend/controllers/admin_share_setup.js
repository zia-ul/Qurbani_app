// controllers/vendorShareSetup.controller.js
const db = require("../config/db.js");

const saveVendorShareSetup = async (req, res) => {
  try {
    const vendorId = req.user.id;

    console.log(req.body);

    const {
      totalShares,
      pricePerShare,
      lateBookingFee = 0,
      lastBookingDate,
      deliveryType,
      deliveryFee = 0,
      deliveryThreshold = null,
      dayOneLimit,
      dayTwoLimit,
      dayThreeLimit
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
        free_delivery_threshold,
        day1,
        day2,
        day3
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        total_shares = VALUES(total_shares),
        price_per_share = VALUES(price_per_share),
        late_booking_fee = VALUES(late_booking_fee),
        last_booking_date = VALUES(last_booking_date),
        delivery_type = VALUES(delivery_type),
        delivery_fee = VALUES(delivery_fee),
        free_delivery_threshold = VALUES(free_delivery_threshold),
        day1 = VALUES(day1),
        day2 = VALUES(day2),
        day3 = VALUES(day3),
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
      dayOneLimit,
      dayTwoLimit,
      dayThreeLimit
    ]);

    // Update order_deadline in users table
    const updateUserDeadlineQuery = `
      UPDATE users
      SET order_deadline = ?
      WHERE id = ?
    `;

    await db.query(updateUserDeadlineQuery, [lastBookingDate, vendorId]);

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

/**
 * GET Logged-in Admin Share Setup
 */
const getVendorShareSetup = async (req, res) => {
  try {
    const vendorId = req.user.id;

    const [rows] = await db.query(
      `
      SELECT
        total_shares,
        price_per_share,
        late_booking_fee,
        last_booking_date,
        delivery_type,
        delivery_fee,
        free_delivery_threshold,
        day1,
        day2,
        day3
      FROM admin_share_setups
      WHERE admin_id = ?
        AND is_active = 1
      LIMIT 1
      `,
      [vendorId],
    );

    console.log("Fetched share setup from DB:", rows);

    if (!rows.length) {
      return res.status(404).json({
        message: "Share setup not found",
      });
    }

    const setup = rows[0];

    res.status(200).json({
      totalShares: setup.total_shares,
      pricePerShare: setup.price_per_share,
      lateBookingFee: setup.late_booking_fee,
      lastBookingDate: setup.last_booking_date,
      deliveryType: setup.delivery_type,
      deliveryFee: setup.delivery_fee,
      deliveryThreshold: setup.free_delivery_threshold,
      dayOneLimit: setup.day1,
      dayTwoLimit: setup.day2,
      dayThreeLimit: setup.day3
    });
  } catch (err) {
    console.error("Fetch vendor share setup error:", err);
    res.status(500).json({
      message: "Failed to fetch share setup",
    });
  }
};

module.exports = {
  saveVendorShareSetup,
  getVendorShareSetup,
};

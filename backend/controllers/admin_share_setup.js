const db = require("../config/db.js");
const { v4: uuidv4 } = require("uuid");

const normalizeDate = (value) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }

  return date.toISOString().split("T")[0];
};

const saveVendorShareSetup = async (req, res) => {
  try {
    const vendorId = req.user.id;
    const {
      lateBookingFee = 0,
      lastBookingDate,
      orderDeadline,
      deliveryType,
      deliveryFee = 0,
      deliveryThreshold = null,
      dayOneLimit,
      dayTwoLimit,
      dayThreeLimit,
    } = req.body;
    const deadlineValue = orderDeadline || lastBookingDate;

    if (!deadlineValue || !deliveryType) {
      return res.status(400).json({
        message: "Missing required fields",
      });
    }

    const normalizedLateBookingFee = Number(lateBookingFee ?? 0);
    const normalizedDeliveryFee = Number(deliveryFee ?? 0);
    const normalizedDeliveryThreshold =
      deliveryThreshold == null || deliveryThreshold === ""
        ? null
        : Number(deliveryThreshold);
    const normalizedDayOneLimit = Number(dayOneLimit ?? 0);
    const normalizedDayTwoLimit = Number(dayTwoLimit ?? 0);
    const normalizedDayThreeLimit = Number(dayThreeLimit ?? 0);
    const normalizedLastBookingDate = normalizeDate(deadlineValue);

    if (!["free", "paid"].includes(deliveryType)) {
      return res.status(400).json({
        message: "Please choose a valid delivery type.",
      });
    }

    const invalidNumberField = [
      normalizedLateBookingFee,
      normalizedDeliveryFee,
      normalizedDayOneLimit,
      normalizedDayTwoLimit,
      normalizedDayThreeLimit,
      ...(normalizedDeliveryThreshold == null
        ? []
        : [normalizedDeliveryThreshold]),
    ].some((value) => Number.isNaN(value));

    if (invalidNumberField) {
      return res.status(400).json({
        message: "Please enter valid numeric values for the share setup.",
      });
    }

    if (!normalizedLastBookingDate) {
      return res.status(400).json({
        message: "Please select a valid order deadline.",
      });
    }

    const [existingRows] = await db.query(
      `
      SELECT id
      FROM admin_share_setups
      WHERE admin_id = ?
        AND is_active = 1
      LIMIT 1
      `,
      [vendorId]
    );

    if (existingRows.length) {
      await db.query(
        `
        UPDATE admin_share_setups
        SET
          late_booking_fee = ?,
          last_booking_date = ?,
          delivery_type = ?,
          delivery_fee = ?,
          free_delivery_threshold = ?,
          day1 = ?,
          day2 = ?,
          day3 = ?,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
        `,
        [
          normalizedLateBookingFee,
          normalizedLastBookingDate,
          deliveryType,
          normalizedDeliveryFee,
          normalizedDeliveryThreshold,
          normalizedDayOneLimit,
          normalizedDayTwoLimit,
          normalizedDayThreeLimit,
          existingRows[0].id,
        ]
      );
    } else {
      await db.query(
        `
        INSERT INTO admin_share_setups (
          id,
          admin_id,
          late_booking_fee,
          last_booking_date,
          delivery_type,
          delivery_fee,
          free_delivery_threshold,
          day1,
          day2,
          day3
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `,
        [
          uuidv4(),
          vendorId,
          normalizedLateBookingFee,
          normalizedLastBookingDate,
          deliveryType,
          normalizedDeliveryFee,
          normalizedDeliveryThreshold,
          normalizedDayOneLimit,
          normalizedDayTwoLimit,
          normalizedDayThreeLimit,
        ]
      );
    }

    await db.query(
      `
      UPDATE users
      SET order_deadline = ?
      WHERE id = ?
      `,
      [normalizedLastBookingDate, vendorId]
    );

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

const getVendorShareSetup = async (req, res) => {
  try {
    const vendorId = req.user.id;

    const [rows] = await db.query(
      `
      SELECT
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
      ORDER BY updated_at DESC
      LIMIT 1
      `,
      [vendorId]
    );

    if (!rows.length) {
      return res.status(404).json({
        message: "Share setup not found",
      });
    }

    const setup = rows[0];

    res.status(200).json({
      lateBookingFee: setup.late_booking_fee,
      lastBookingDate: setup.last_booking_date,
      orderDeadline: setup.last_booking_date,
      deliveryType: setup.delivery_type,
      deliveryFee: setup.delivery_fee,
      deliveryThreshold: setup.free_delivery_threshold,
      dayOneLimit: setup.day1,
      dayTwoLimit: setup.day2,
      dayThreeLimit: setup.day3,
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

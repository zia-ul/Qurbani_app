const { v4: uuidv4 } = require("uuid");
const db = require("../config/db");
const logger = require("../middleware/logger");

exports.addAnimal = async (adminId, data) => {
  const id = uuidv4();

  const lastBookedDate = data.lastBookedDate
    ? new Date(data.lastBookedDate).toISOString().split("T")[0]
    : null;

  logger.info("Adding animal to database", {
    adminId,
    animalId: id,
    animalType: data.animalType,
    price: data.price,
    shares: data.shares,
    deliveryType: data.deliveryType,
  });

  try {
    await db.query(
      `
      INSERT INTO animals (
        id,
        admin_id,
        animal_type,
        price,
        shares,
        delivery_type,
        delivery_fee,
        delivery_threshold,
        last_booked_date
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      [
        id,
        adminId,
        data.animalType,
        data.price,
        data.shares || 1,
        data.deliveryType || "Free",
        data.deliveryFee || 0,
        data.deliveryThreshold || 0,
        lastBookedDate,
      ]
    );

    logger.info("Animal inserted successfully", {
      adminId,
      animalId: id,
    });

    return id;
  } catch (err) {
    logger.error("Failed to insert animal", {
      adminId,
      animalId: id,
      error: err.message,
      stack: err.stack,
    });

    throw err;
  }
};

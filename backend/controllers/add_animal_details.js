const { v4: uuidv4 } = require("uuid");
const db = require("../config/db");

exports.addAnimal = async (adminId, data) => {
  const id = uuidv4();

  const lastBookedDate = data.lastBookedDate
    ? new Date(data.lastBookedDate).toISOString().split("T")[0]
    : null;

  logger.info("Adding animal to database", {
    adminId,
    animalId: id,
    animalType: data.animalType,
    breed: data.breed,
    shares: data.shares || 1,
    deliveryType: data.deliveryType || "Free",
  });

  try {
    await db.query(
      `INSERT INTO animals (
        id, admin_id,
        animal_type, breed, price,
        description, age, height, weight, shares,
        photo_urls,
        delivery_type, delivery_fee, delivery_threshold, last_booked_date
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        adminId,

        data.animalType,
        data.breed,
        data.price,

        data.description || null,
        data.age || null,
        data.height || null,
        data.weight || null,
        data.shares || 1,

        JSON.stringify(data.photoUrls || []),

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

    throw err; // important — let controller handle response
  }
};

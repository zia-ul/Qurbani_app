const { v4: uuidv4 } = require("uuid");
const db = require("../config/db");

exports.addAnimal = async (adminId, data) => {
  const id = uuidv4();

  await db.query(
    `INSERT INTO animals (
      id, admin_id,
      animal_type, breed, price,
      description, age, height, weight, shares,
      photo_urls, payment_methods,
      delivery_type, delivery_fee, delivery_threshold
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
      JSON.stringify(data.paymentMethods),

      data.deliveryType || "Free",
      data.deliveryFee || 0,
      data.deliveryThreshold || 0,
    ]
  );

  return id;
};

const db = require("../config/db");
const logger = require("../middleware/logger");

/**
 * GET /api
 * List all animals added by the logged-in admin
 */
exports.getAnimals = async (req, res) => {
  const adminId = req.user?.id;

  if (!adminId) {
    logger.warn("Unauthorized attempt to fetch animals");
    return res.status(401).json({ message: "Unauthorized" });
  }

  try {
    const { rows: animals } = await db.query(
      `
      SELECT 
        a.id,
        a.animal_type,
        a.price_per_share,
        a.shares,
        a.created_at,
        a.qurbani_datetime,
        ad.barcode,

        COUNT(sd.id) AS assigned_shares,
        (a.shares - COUNT(sd.id)) AS remaining_shares

      FROM animals a

      LEFT JOIN animal_details ad 
        ON ad.animal_id = a.id

      LEFT JOIN shareholder_details sd
        ON sd.animal_id = a.id

      WHERE a.admin_id = $1

      GROUP BY 
        a.id,
        a.animal_type,
        a.price_per_share,
        a.shares,
        a.created_at,
        ad.barcode,
        a.qurbani_datetime

      ORDER BY a.created_at DESC
      `,
      [adminId]
    );

    res.status(200).json({ animals });
  } catch (err) {
    logger.error("Error fetching animals", {
      adminId,
      error: err.message,
    });

    res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
};

/**
 * DELETE /api/animals/:id
 * Delete an animal added by the logged-in admin
 */
exports.deleteAnimal = async (req, res) => {
  const adminId = req.user?.id;
  const animalId = req.params.id;

  if (!adminId) {
    logger.warn("Unauthorized attempt to delete animal", { animalId });
    return res.status(401).json({ message: "Unauthorized" });
  }

  logger.info("Admin attempting to delete animal", {
    adminId,
    animalId,
  });

  try {
    const { rows } = await db.query(
      "SELECT id FROM animals WHERE id = $1 AND admin_id = $2",
      [animalId, adminId]
    );

    if (!rows.length) {
      logger.warn("Animal delete failed (not found or not owned)", {
        adminId,
        animalId,
      });

      return res.status(404).json({
        message: "Animal not found or not owned by you",
      });
    }

    await db.query(
      "DELETE FROM animals WHERE id = $1",
      [animalId]
    );

    logger.info("Animal deleted successfully", {
      adminId,
      animalId,
    });

    res.json({ message: "Animal deleted successfully" });
  } catch (err) {
    logger.error("Error deleting animal", {
      adminId,
      animalId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
};

/**
 * GET animal by ID
 */
exports.getAnimalById = async (req, res) => {
  const adminId = req.user?.id;
  const animalId = req.params.id;
  const orderId = req.query.orderId;
  const shareholderId = req.query.shareholderId;

  if (!adminId) {
    logger.warn("Unauthorized attempt to fetch animal", {
      animalId,
    });

    return res.status(401).json({
      message: "Unauthorized",
    });
  }

  logger.info("Admin fetching animal by ID", {
    adminId,
    animalId,
    orderId,
  });

  try {
    let query = `
      SELECT 
        a.*,
        ad.id AS animal_details_id,
        ad.order_id,
        ad.barcode,
        ad.breed AS details_breed,
        ad.description AS details_description,
        ad.age AS details_age,
        ad.height AS details_height,
        ad.weight AS details_weight,
        ad.photo_urls AS details_photo_urls,
        ad.qurbani_datetime,
        ad.meat_weight,
        ad.body_parts_description
      FROM animals a
      LEFT JOIN animal_details ad 
        ON ad.animal_id = a.id
       AND ad.order_id = $1
    `;

    const values = [orderId];
    let paramIndex = 2;

    if (shareholderId) {
      query += ` AND ad.shareholder_id = $${paramIndex}`;
      values.push(shareholderId);
      paramIndex++;
    }

    query += `
      WHERE a.id = $${paramIndex}
        AND a.admin_id = $${paramIndex + 1}
    `;

    values.push(animalId, adminId);

    const { rows } = await db.query(query, values);

    if (!rows.length) {
      logger.warn("Animal not found for admin/order", {
        adminId,
        animalId,
        orderId,
      });

      return res.status(404).json({
        message: "Animal not found",
      });
    }

    res.json(rows[0]);
  } catch (err) {
    logger.error("Error fetching animal by ID", {
      adminId,
      animalId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
};

/**
 * UPDATE animal
 */
exports.updateAnimal = async (req, res) => {
  const adminId = req.user?.id;
  const animalId = req.params.id;

  if (!adminId) {
    logger.warn("Unauthorized attempt to update animal", {
      animalId,
    });

    return res.status(401).json({
      message: "Unauthorized",
    });
  }

  logger.info("Admin updating animal", {
    adminId,
    animalId,
  });

  const {
    animalType,
    price_per_share,
    pricePerShare,
    breed,
    description,
    price,
    age,
    height,
    weight,
    shares,
    photoUrls,
    deliveryType,
    deliveryFee,
    deliveryThreshold,
  } = req.body;

  try {
    const { rowCount } = await db.query(
      `
      UPDATE animals SET
        animal_type = $1,
        price_per_share = COALESCE($2, price_per_share),
        breed = $3,
        description = $4,
        price = $5,
        age = $6,
        height = $7,
        weight = $8,
        shares = $9,
        photo_urls = $10,
        delivery_type = $11,
        delivery_fee = $12,
        delivery_threshold = $13
      WHERE id = $14
        AND admin_id = $15
      `,
      [
        animalType,
        price_per_share ?? pricePerShare,
        breed,
        description,
        price,
        age,
        height,
        weight,
        shares,
        JSON.stringify(photoUrls || []),
        deliveryType,
        deliveryFee,
        deliveryThreshold || null,
        animalId,
        adminId,
      ]
    );

    if (rowCount === 0) {
      logger.warn("Animal update failed (not found or not owned)", {
        adminId,
        animalId,
      });

      return res.status(404).json({
        message: "Animal not found or not owned",
      });
    }

    logger.info("Animal updated successfully", {
      adminId,
      animalId,
    });

    res.json({
      message: "Animal updated successfully",
    });
  } catch (err) {
    logger.error("Error updating animal", {
      adminId,
      animalId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
};

/**
 * GET delivery orders
 */
exports.getDeliveryOrders = async (req, res) => {
  try {
    const { deliveryPersonId } = req.params;

    const { rows: orders } = await db.query(
      `
      SELECT 
        id,
        user_id,
        admin_id,
        payment_method,
        total_shares,
        status,
        delivery_status,
        payment_status,
        processing_status,
        qurbani_time,
        delivery_code,
        delivery_notified,
        created_at
      FROM orders
      WHERE delivery_person_id = $1
      ORDER BY created_at DESC
      `,
      [deliveryPersonId]
    );

    return res.status(200).json({
      success: true,
      orders,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Failed to fetch delivery orders",
    });
  }
};
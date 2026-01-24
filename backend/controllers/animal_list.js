const db = require("../config/db");
const logger = require("../middleware/logger");

/**
 * GET /api/animals
 * List all animals added by the logged-in admin
 */
exports.getAnimals = async (req, res) => {
  const adminId = req.user?.id;

  if (!adminId) {
    logger.warn("Unauthorized attempt to fetch animals");
    return res.status(401).json({ message: "Unauthorized" });
  }

  logger.info("Admin fetching own animals", { adminId });

  try {
    const [animals] = await db.query(
      "SELECT * FROM animals WHERE admin_id = ?",
      [adminId]
    );

    res.status(200).json({ animals });
  } catch (err) {
    logger.error("Error fetching animals", {
      adminId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Something went wrong. Please try again later." });
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

  logger.info("Admin attempting to delete animal", { adminId, animalId });

  try {
    const [rows] = await db.query(
      "SELECT id FROM animals WHERE id = ? AND admin_id = ?",
      [animalId, adminId]
    );

    if (!rows.length) {
      logger.warn("Animal delete failed (not found or not owned)", {
        adminId,
        animalId,
      });

      return res
        .status(404)
        .json({ message: "Animal not found or not owned by you" });
    }

    await db.query("DELETE FROM animals WHERE id = ?", [animalId]);

    logger.info("Animal deleted successfully", { adminId, animalId });

    res.json({ message: "Animal deleted successfully" });
  } catch (err) {
    logger.error("Error deleting animal", {
      adminId,
      animalId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
};



exports.getAnimalById = async (req, res) => {
  const adminId = req.user?.id;
  const animalId = req.params.id;

  if (!adminId) {
    logger.warn("Unauthorized attempt to fetch animal", { animalId });
    return res.status(401).json({ message: "Unauthorized" });
  }

  logger.info("Admin fetching animal by ID", { adminId, animalId });

  try {
    const [rows] = await db.query(
      "SELECT * FROM animals WHERE id = ? AND admin_id = ?",
      [animalId, adminId]
    );

    if (!rows.length) {
      logger.warn("Animal not found for admin", { adminId, animalId });
      return res.status(404).json({ message: "Animal not found" });
    }

    res.json(rows[0]);
  } catch (err) {
    logger.error("Error fetching animal by ID", {
      adminId,
      animalId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
};


exports.updateAnimal = async (req, res) => {
  const adminId = req.user?.id;
  const animalId = req.params.id;

  if (!adminId) {
    logger.warn("Unauthorized attempt to update animal", { animalId });
    return res.status(401).json({ message: "Unauthorized" });
  }

  logger.info("Admin updating animal", {
    adminId,
    animalId,
  });

  const {
    animalType,
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
    const [result] = await db.query(
      `UPDATE animals SET
        animal_type = ?,
        breed = ?,
        description = ?,
        price = ?,
        age = ?,
        height = ?,
        weight = ?,
        shares = ?,
        photo_urls = ?,
        delivery_type = ?,
        delivery_fee = ?,
        delivery_threshold = ?
       WHERE id = ? AND admin_id = ?`,
      [
        animalType,
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

    if (result.affectedRows === 0) {
      logger.warn("Animal update failed (not found or not owned)", {
        adminId,
        animalId,
      });

      return res.status(404).json({ message: "Animal not found or not owned" });
    }

    logger.info("Animal updated successfully", { adminId, animalId });

    res.json({ message: "Animal updated successfully" });
  } catch (err) {
    logger.error("Error updating animal", {
      adminId,
      animalId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Something went wrong. Please try again later." });
  }
};

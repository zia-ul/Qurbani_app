const db = require("../config/db");

/**
 * GET /api/animals
 * List all animals added by the logged-in admin
 */
exports.getAnimals = async (req, res) => {
  try {
    if (!req.user || !req.user.id) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const [animals] = await db.query(
      "SELECT * FROM animals WHERE admin_id = ?",
      [req.user.id]
    );

    res.status(200).json({ animals });
  } catch (err) {
    console.error("Error fetching animals:", err);
    res.status(500).json({ message: "Server error" });
  }
};

/**
 * DELETE /api/animals/:id
 * Delete an animal added by the logged-in admin
 */
exports.deleteAnimal = async (req, res) => {
  try {
    const animalId = req.params.id;

    if (!req.user || !req.user.id) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    // Ensure admin owns this animal
    const [rows] = await db.query(
      "SELECT * FROM animals WHERE id = ? AND admin_id = ?",
      [animalId, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "Animal not found or not owned by you" });
    }

    // Delete
    await db.query("DELETE FROM animals WHERE id = ?", [animalId]);

    res.json({ message: "Animal deleted successfully" });
  } catch (err) {
    console.error("Error deleting animal:", err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.getAnimalById = async (req, res) => {
  try {
    const animalId = req.params.id;

    if (!req.user?.id) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const [rows] = await db.query(
      "SELECT * FROM animals WHERE id = ? AND admin_id = ?",
      [animalId, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "Animal not found" });
    }

    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};

exports.updateAnimal = async (req, res) => {
  try {
    const animalId = req.params.id;
    const adminId = req.user.id;

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
      paymentMethods,
      deliveryFee,
    } = req.body;

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
        payment_methods = ?,
        delivery_fee = ?,
        updated_at = NOW()
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
        JSON.stringify(photoUrls),
        JSON.stringify(paymentMethods),
        deliveryFee,
        animalId,
        adminId,
      ]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Animal not found or not owned" });
    }

    res.json({ message: "Animal updated successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
};


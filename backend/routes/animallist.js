const express = require("express");
const router = express.Router();
const auth = require("../controllers/auth"); 
const isAdmin = require("../middleware/isAdmin"); 
const authMiddleware = require("../middleware/authmiddleware");
const { getAnimals, deleteAnimal, updateAnimal, getAnimalById } = require("../controllers/animal_list");
const pool = require("../config/db");

// Get animals for logged-in admin
router.get("/", authMiddleware, isAdmin, getAnimals);

// Delete animal by ID (admin only)
router.delete("/:id", authMiddleware, isAdmin, deleteAnimal);

//update animal - update data after edit
router.put("/:id", authMiddleware, isAdmin, updateAnimal);

//fetch animal details - animal edit
router.get("/:id", authMiddleware, isAdmin, getAnimalById);

// GET /api/animals/:animalId/orders - Fetch orders for an animal (admin only)
router.get("/:animalId/orders", authMiddleware, async (req, res) => {
  const { animalId } = req.params;
  const adminId = req.user.id; // Assuming admin is logged in

  try {
    const [orders] = await pool.execute(
      `SELECT o.id, o.user_id, o.payment_status, o.processing_status, o.delivery_status, o.created_at, u.name AS user_name
       FROM orders o
       JOIN users u ON o.user_id = u.id
       WHERE o.animal_id = ? AND o.admin_id = ? ORDER BY o.created_at DESC`,
      [animalId, adminId]
    );
    res.json({ orders });
  } catch (err) {
    console.error("Error fetching animal orders:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

module.exports = router;

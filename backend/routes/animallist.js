const express = require("express");
const router = express.Router();
const auth = require("../controllers/auth"); 
const isAdmin = require("../middleware/isAdmin"); 
const authMiddleware = require("../middleware/authmiddleware");
const { getAnimals, deleteAnimal, updateAnimal, getAnimalById } = require("../controllers/animal_list");

// Get animals for logged-in admin
router.get("/", authMiddleware, isAdmin, getAnimals);

// Delete animal by ID (admin only)
router.delete("/:id", authMiddleware, isAdmin, deleteAnimal);

//update animal - update data after edit
router.put("/:id", authMiddleware, isAdmin, updateAnimal);

//fetch animal details - animal edit
router.get("/:id", authMiddleware, isAdmin, getAnimalById);

module.exports = router;

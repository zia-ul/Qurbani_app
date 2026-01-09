const express = require("express");
const router = express.Router();
const auth = require("../controllers/auth"); 
const isAdmin = require("../middleware/isAdmin"); 
const { getAnimals, deleteAnimal, updateAnimal, getAnimalById } = require("../controllers/animal_list");

// Get animals for logged-in admin
router.get("/", auth, isAdmin, getAnimals);

// Delete animal by ID (admin only)
router.delete("/:id", auth, isAdmin, deleteAnimal);

//update animal - update data after edit
router.put("/:id", auth, isAdmin, updateAnimal);

//fetch animal details - animal edit
router.get("/:id", auth, isAdmin, getAnimalById);

module.exports = router;

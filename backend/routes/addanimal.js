const express = require("express");
const { body } = require("express-validator");
const auth = require("../controllers/auth");
const isAdmin = require("../middleware/isAdmin");
const { addAnimal } = require("../controllers/add_animal_details");

const router = express.Router();

/**
 * ADD ANIMAL (Admin only)
 */
router.post(
  "/",
  auth,
  isAdmin,
  [
    body("animalType").notEmpty(),
    body("breed").notEmpty(),
    body("price").isNumeric(),
    body("lastBookedDate")
      .notEmpty()
      .isISO8601()
      .withMessage("lastBookedDate is required and must be a valid date"),
  ],
  async (req, res) => {
    try {
      const id = await addAnimal(req.user.id, req.body);
      res.status(201).json({
        message: "Animal added successfully",
        animalId: id,
      });
    } catch (err) {
      console.error("Error adding animal:", err);
      res.status(500).json({ message: err.message });
    }
  }
);

module.exports = router;

/**
 * @swagger
 * /api/animals:
 *   post:
 *     summary: Add a new animal (Admin only)
 *     description: Creates a new animal record. Only admins can access this endpoint.
 *     tags: [Animals]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - animalType
 *               - breed
 *               - price
 *               - lastBookedDate
 *             properties:
 *               animalType:
 *                 type: string
 *                 example: Cow
 *               breed:
 *                 type: string
 *                 example: Jersey
 *               price:
 *                 type: number
 *                 example: 15000
 *               lastBookedDate:
 *                 type: string
 *                 format: date
 *                 example: 2024-01-15
 *     responses:
 *       201:
 *         description: Animal added successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 message:
 *                   type: string
 *                   example: Animal added successfully
 *                 animalId:
 *                   type: integer
 *                   example: 12
 *       401:
 *         description: Unauthorized (JWT missing or invalid)
 *       403:
 *         description: Forbidden (Admin access required)
 *       500:
 *         description: Server error
 */



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
    const adminId = req.user.id;

    logger.info("Add animal request received", {
      adminId,
      animalType: req.body.animalType,
      breed: req.body.breed,
    });

    try {
      const id = await addAnimal(adminId, req.body);

      logger.info("Animal added successfully", {
        adminId,
        animalId: id,
      });

      res.status(201).json({
        message: "Animal added successfully",
        animalId: id,
      });
    } catch (err) {
      logger.error("Error adding animal", {
        adminId,
        error: err.message,
        stack: err.stack,
      });

      res.status(500).json({ message: err.message });
    }
  }
);


module.exports = router;

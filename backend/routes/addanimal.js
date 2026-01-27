const express = require("express");
const { body } = require("express-validator");
const auth = require("../controllers/auth");
const isAdmin = require("../middleware/isAdmin");
const { addAnimal } = require("../controllers/add_animal_details");
const logger = require("../middleware/logger");
const pool = require("../config/db");
const router = express.Router();

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
 *         description: Something went wrong. Please try again later.
 */

/**
 * ADD ANIMAL (Admin only)
 */
router.post(
  "/",
  auth,
  isAdmin,
  [
    body("animalType").notEmpty().withMessage("animalType is required"),

    body("price").isNumeric().withMessage("price must be a number"),

    body("shares")
      .isInt({ min: 1 })
      .withMessage("shares must be an integer >= 1"),

    body("lastBookedDate")
      .notEmpty()
      .isISO8601()
      .withMessage("lastBookedDate must be a valid date"),

    body("deliveryType")
      .isIn(["free", "paid"])
      .withMessage("deliveryType must be free or paid"),

    body("deliveryFee")
      .if(body("deliveryType").equals("paid"))
      .isNumeric()
      .withMessage("deliveryFee is required for paid delivery"),

    body("deliveryThreshold")
      .optional()
      .isNumeric()
      .withMessage("deliveryThreshold must be numeric"),
  ],
  async (req, res) => {
    const adminId = req.user.id;

    logger.info("Add animal request received", {
      adminId,
      animalType: req.body.animalType,
    });

    try {
      const animalId = await addAnimal(adminId, req.body);

      logger.info("Animal added successfully", {
        adminId,
        animalId,
      });

      res.status(201).json({
        message: "Animal added successfully",
        animalId,
      });
    } catch (err) {
      logger.error("Error adding animal", {
        adminId,
        error: err.message,
        stack: err.stack,
      });

      res.status(500).json({ message: err.message });
    }
  },
);

router.post("/:animalId", async (req, res) => {
  const { animalId } = req.params;
  const {
    orderId,
    barcode,
    breed,
    description,
    age,
    height,
    weight,
    photoUrls,
  } = req.body;

  if (!animalId || !orderId) {
    return res.status(400).json({ error: "animalId and orderId are required" });
  }

  try {
    const id = crypto.randomUUID();

    await pool.query(
      `INSERT INTO animal_details
       (id, animal_id, order_id, barcode, breed, description, age, height, weight, photo_urls)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        animalId,
        orderId,
        barcode,
        breed,
        description,
        age,
        height,
        weight,
        photoUrls,
      ],
    );

    return res.status(200).json({
      message: "Animal details saved",
      id,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Internal server error" });
  }
});


module.exports = router;

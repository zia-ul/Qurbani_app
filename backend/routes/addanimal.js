const express = require("express");
const { body, validationResult } = require("express-validator");

const auth = require("../controllers/auth");
const isAdmin = require("../middleware/isAdmin");
const { addAnimal } = require("../controllers/add_animal_details");
const logger = require("../middleware/logger");
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
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

const crypto = require("crypto");

// Generate 12 digit numeric barcode
function generateBarcode() {
  const timestampPart = Date.now().toString().slice(-6); // last 6 digits of timestamp
  const randomPart = Math.floor(100000 + Math.random() * 900000); // 6 random digits
  return timestampPart + randomPart; // total 12 digits
}

router.post(
  "/",
  authMiddleware,
  isAdmin,
  [
    body("animalType").notEmpty().withMessage("animalType is required"),
    body("shares").isInt({ min: 1 }).withMessage("shares must be >= 1"),

    body("breed").optional({ nullable: true }).isString(),
    body("description").optional({ nullable: true }).isString(),
    body("age").optional({ nullable: true }).isString(),
    body("height").optional({ nullable: true }).isString(),
    body("weight").optional({ nullable: true }).isString(),
    body("images").optional({ nullable: true }).isArray(),
  ],
  async (req, res) => {
    const adminId = req.user.id;
    const errors = validationResult(req);

    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const barcode = generateBarcode();

    const {
      animalType,
      shares,
      breed,
      description,
      age,
      height,
      weight,
      images,
    } = req.body;

    console.log("Add Animal Request Body:", req.body);

    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      // Insert into animals
      const [animalResult] = await connection.query(
        `
        INSERT INTO animals (
          admin_id,
          animal_type,
          price,
          shares,
          delivery_type,
          delivery_fee,
          last_booked_date
        )
        VALUES (?, ?, NULL, ?, NULL, NULL, NULL)
        `,
        [adminId, animalType, shares]
      );

      const animalId = animalResult.insertId;

      // Insert into animal_details using same animalId
      await connection.query(
        `
        INSERT INTO animal_details (
          animal_id,
          barcode,
          breed,
          description,
          age,
          height,
          weight,
          photo_urls
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `,
        [
          animalId,
          barcode,
          breed || null,
          description || null,
          age || null,
          height || null,
          weight || null,
          JSON.stringify(images || []),
        ]
      );

      await connection.commit();

      return res.status(201).json({
        message: "Animal added successfully",
        animalId,
      });
    } catch (err) {
      await connection.rollback();
      console.error("[ADD ANIMAL ERROR]", err);

      return res.status(500).json({
        message: "Failed to add animal",
      });
    } finally {
      connection.release();
    }
  }
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
    return res.status(400).json({
      error: "animalId and orderId are required",
    });
  }

  try {
    // Fetch a valid shareholder_id for this animal + order
    const [shareholders] = await pool.query(
      `SELECT id 
       FROM order_shareholders 
       WHERE animal_id = ? AND order_id = ?
       LIMIT 1`,
      [animalId, orderId]
    );

    if (!shareholders.length) {
      return res.status(400).json({
        error: "No shareholder found for this animal and order",
      });
    }

    const shareholderId = shareholders[0].id;
    const id = crypto.randomUUID();

    // Insert animal_details with shareholder_id
    await pool.query(
      `INSERT INTO animal_details
       (
         id,
         animal_id,
         order_id,
         shareholder_id,
         barcode,
         breed,
         description,
         age,
         height,
         weight,
         photo_urls
       )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        animalId,
        orderId,
        shareholderId,
        barcode,
        breed,
        description,
        age,
        height,
        weight,
        JSON.stringify(photoUrls || []),
      ]
    );

    return res.status(200).json({
      message: "Animal details saved",
      id,
    });
  } catch (err) {
    console.error("Animal details insert failed:", err);
    return res.status(500).json({
      error: "Internal server error",
    });
  }
});


module.exports = router;

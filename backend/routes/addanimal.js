const express = require("express");
const { body, validationResult } = require("express-validator");

const auth = require("../controllers/auth");
const isAdmin = require("../middleware/isAdmin");
const logger = require("../middleware/logger");
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const router = express.Router();

router.get("/barcode/:barcode", authMiddleware, async (req, res) => {
  const { barcode } = req.params;

  try {
    // Find animal by barcode
    const animalQuery = `
      SELECT
        a.id,
        a.animal_type,
        a.qurbani_day,
        a.qurbani_datetime,
        ad.barcode
      FROM animal_details ad
      INNER JOIN animals a
        ON a.id = ad.animal_id
      WHERE ad.barcode = $1
      LIMIT 1
    `;

    const animalResult = await pool.query(
      animalQuery,
      [barcode]
    );

    if (!animalResult.rows.length) {
      return res.status(404).json({
        message: "Animal not found",
      });
    }

    const animal = animalResult.rows[0];

    // Get shareholders
    const shareholderQuery = `
      SELECT
        sd.id,
        sd.shareholder_name,
        sd.guardian_name,
        sd.address,
        sd.share_number,
        sd.qurbani_day,
        sd.qurbani_datetime,
        o.user_id,
        u.phone AS contact_no,
        u.name AS user_name
      FROM shareholder_details sd
      LEFT JOIN orders o
        ON o.id = sd.order_id
      LEFT JOIN users u
        ON u.id = o.user_id
      WHERE sd.animal_id = $1
      ORDER BY sd.share_number ASC, sd.id ASC
    `;

    const shareholderResult = await pool.query(
      shareholderQuery,
      [animal.id]
    );

    return res.status(200).json({
      animal: {
        id: animal.id,
        animal_type: animal.animal_type,
        barcode: animal.barcode,
        qurbani_day: animal.qurbani_day,
        qurbani_datetime: animal.qurbani_datetime,
      },

      shareholders: shareholderResult.rows.map((row) => ({
        id: row.id,
        shareholder_name: row.shareholder_name,
        guardian_name: row.guardian_name,
        contact_no: row.contact_no,
        user_name: row.user_name,
        address: row.address,
        share_number: row.share_number,
        qurbani_day: row.qurbani_day,
        qurbani_datetime: row.qurbani_datetime,
      })),
    });

  } catch (err) {
    logger.error("Failed to fetch animal details by barcode", {
      barcode,
      error: err.message,
      stack: err.stack,
    });

    return res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
});

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

async function getAnimalsIdConfig() {
  const query = `
    SELECT
      column_name,
      data_type,
      is_identity
    FROM information_schema.columns
    WHERE table_name = 'animals'
      AND column_name = 'id'
  `;

  const result = await pool.query(query);

  const columns = result.rows;

  const idColumn = columns[0];

  const idDataType = (idColumn?.data_type || "").toLowerCase();

  return {
    requiresExplicitId: Boolean(idColumn) && idColumn.is_identity !== "YES",

    idIsNumeric: [
      "smallint",
      "integer",
      "bigint",
      "numeric",
      "decimal",
    ].includes(idDataType),
  };
}

async function buildAnimalInsertPayload(
  adminId,
  animalType,
  pricePerShare,
  shares,
  qurbaniDay,
  qurbaniDatetime,
) {
  const tableConfig = await getAnimalsIdConfig();

  const columns = [];
  const values = [];

  let animalId = null;

  if (tableConfig.requiresExplicitId) {
    columns.push("id");

    if (tableConfig.idIsNumeric) {
      const result = await pool.query(`
        SELECT COALESCE(MAX(id), 0) AS max_id
        FROM animals
      `);

      animalId = Number(result.rows[0]?.max_id || 0) + 1;
    } else {
      animalId = `${Date.now()}${Math.floor(1000 + Math.random() * 9000)}`;
    }

    values.push(animalId);
  }

  columns.push(
    "admin_id",
    "animal_type",
    "price_per_share",
    "shares",
    "last_booked_date",
    "qurbani_day",
    "qurbani_datetime",
  );

  values.push(
    adminId,
    animalType,
    pricePerShare,
    shares,
    null,
    qurbaniDay,
    qurbaniDatetime,
  );

  return {
    columns,
    values,
    animalId,
  };
}

router.post(
  "/",
  authMiddleware,
  isAdmin,
  [
    body("animalType").notEmpty().withMessage("animalType is required"),
    body("price_per_share")
      .custom((value, { req }) => {
        const price = value ?? req.body.pricePerShare;
        return Number.isFinite(Number(price)) && Number(price) >= 0;
      })
      .withMessage("price_per_share must be a non-negative number"),
    body("shares").isInt({ min: 1 }).withMessage("shares must be >= 1"),

    body("qurbaniDay")
      .notEmpty()
      .withMessage("qurbaniDay is required")
      .isIn(["day_1", "day_2", "day_3"])
      .withMessage("qurbaniDay must be day_1, day_2, or day_3"),

    body("qurbaniDatetime")
      .notEmpty()
      .withMessage("qurbaniDatetime is required")
      .isISO8601()
      .withMessage("qurbaniDatetime must be a valid ISO8601 date"),

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
      customAnimalType,
      custom_animal_type,
      price_per_share,
      pricePerShare,
      shares,
      qurbaniDay,
      qurbaniDatetime,
      images,
    } = req.body;
    const normalizedPricePerShare = Number(price_per_share ?? pricePerShare);
    const resolvedAnimalType =
      animalType === "Others"
        ? String(custom_animal_type ?? customAnimalType ?? "").trim()
        : String(animalType).trim();

    if (!resolvedAnimalType) {
      return res.status(400).json({
        message: "Custom animal type is required when Others is selected",
      });
    }

    const client = await pool.connect();

    try {
      await client.query("BEGIN");

      const animalInsert = await buildAnimalInsertPayload(
        adminId,
        resolvedAnimalType,
        normalizedPricePerShare,
        shares,
        qurbaniDay,
        qurbaniDatetime,
      );

      // Insert into animals
      const placeholders = animalInsert.values
        .map((_, index) => `$${index + 1}`)
        .join(", ");

      const animalQuery = `
  INSERT INTO animals (
    ${animalInsert.columns.join(", ")}
  )
  VALUES (${placeholders})
  RETURNING id
`;

      const animalResult = await client.query(animalQuery, animalInsert.values);

      const animalId = animalInsert.animalId ?? animalResult.rows[0].id;
      // Insert into animal_details using same animalId
      await client.query(
        `
  INSERT INTO animal_details (
    animal_id,
    barcode,
    photo_urls,
    qurbani_datetime
  )
  VALUES ($1, $2, $3, $4)
  `,
        [animalId, barcode, JSON.stringify(images || []), qurbaniDatetime],
      );

      await client.query("COMMIT");

      logger.info("Animal added successfully", {
        adminId,
        animalId,
        animalType: resolvedAnimalType,
        pricePerShare: normalizedPricePerShare,
        shares,
        qurbaniDay,
      });

      return res.status(201).json({
        message: "Animal added successfully",
        animalId,
      });
    } catch (err) {
      await client.query("ROLLBACK");
      logger.error("Failed to add animal", {
        adminId,
        animalType,
        shares,
        qurbaniDay,
        error: err.message,
        stack: err.stack,
      });

      return res.status(500).json({
        message: "Unable to add the animal right now. Please try again later.",
      });
    } finally {
      client.release();
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
    return res.status(400).json({
      error: "animalId and orderId are required",
    });
  }

  try {

    // Fetch shareholder
    const shareholderQuery = `
      SELECT id
      FROM order_shareholders
      WHERE animal_id = $1
        AND order_id = $2
      LIMIT 1
    `;

    const shareholderResult = await pool.query(
      shareholderQuery,
      [animalId, orderId]
    );

    if (!shareholderResult.rows.length) {
      return res.status(400).json({
        error:
          "No shareholder found for this animal and order",
      });
    }

    const shareholderId =
      shareholderResult.rows[0].id;

    const id = crypto.randomUUID();

    // Insert animal details
    const insertQuery = `
      INSERT INTO animal_details (
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
      VALUES (
        $1,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9,
        $10,
        $11
      )
    `;

    await pool.query(insertQuery, [
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
    ]);

    return res.status(200).json({
      message: "Animal details saved",
      id,
    });

  } catch (err) {

    logger.error("Animal details insert failed", {
      animalId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    return res.status(500).json({
      error: "Internal server error",
    });
  }
});

module.exports = router;

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
    // 1) Find animal by barcode
    const [animalRows] = await pool.execute(
      `
      SELECT
        a.id,
        a.animal_type,
        a.qurbani_day,
        a.qurbani_datetime,
        ad.barcode
      FROM animal_details ad
      INNER JOIN animals a ON a.id = ad.animal_id
      WHERE ad.barcode = ?
      LIMIT 1
      `,
      [barcode]
    );

    if (!animalRows.length) {
      return res.status(404).json({ message: "Animal not found" });
    }

    const animal = animalRows[0];

    // 2) Get all shareholders assigned to this animal
    // contact comes from orders.user_id -> users.phone
    const [shareholderRows] = await pool.execute(
      `
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
      LEFT JOIN orders o ON o.id = sd.order_id
      LEFT JOIN users u ON u.id = o.user_id
      WHERE sd.animal_id = ?
      ORDER BY sd.share_number ASC, sd.id ASC
      `,
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
      shareholders: shareholderRows.map((row) => ({
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

async function getAnimalsIdConfig(connection) {
  const [columns] = await connection.query(
    `
    SELECT
      COLUMN_NAME AS column_name,
      DATA_TYPE AS data_type,
      EXTRA AS extra
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'animals'
      AND COLUMN_NAME = 'id'
    `,
  );

  const idColumn = columns[0];
  const idDataType = (idColumn?.data_type || "").toLowerCase();
  const idExtra = (idColumn?.extra || "").toLowerCase();

  return {
    requiresExplicitId: Boolean(idColumn) && !idExtra.includes("auto_increment"),
    idIsNumeric: [
      "tinyint",
      "smallint",
      "mediumint",
      "int",
      "bigint",
      "decimal",
      "numeric",
    ].includes(idDataType),
  };
}

async function buildAnimalInsertPayload(
  connection,
  adminId,
  animalType,
  pricePerShare,
  shares,
  qurbaniDay,
  qurbaniDatetime,
) {
  const tableConfig = await getAnimalsIdConfig(connection);
  const columns = [];
  const values = [];

  let animalId = null;
  if (tableConfig.requiresExplicitId) {
    columns.push("id");

    if (tableConfig.idIsNumeric) {
      const [[row]] = await connection.query(
        `SELECT COALESCE(MAX(id), 0) AS maxId FROM animals`,
      );
      animalId = Number(row?.maxId || 0) + 1;
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
  values.push(adminId, animalType, pricePerShare, shares, null, qurbaniDay, qurbaniDatetime);

  return { columns, values, animalId };
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

    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      const animalInsert = await buildAnimalInsertPayload(
        connection,
        adminId,
        resolvedAnimalType,
        normalizedPricePerShare,
        shares,
        qurbaniDay,
        qurbaniDatetime,
      );

      // Insert into animals
      const [animalResult] = await connection.query(
        `
        INSERT INTO animals (
          ${animalInsert.columns.join(", ")}
        )
        VALUES (${animalInsert.columns.map(() => "?").join(", ")})
        `,
        animalInsert.values
      );

      const animalId = animalInsert.animalId ?? animalResult.insertId;

      // Insert into animal_details using same animalId
      await connection.query(
        `
        INSERT INTO animal_details (
          animal_id,
          barcode,
          photo_urls,
          qurbani_datetime
        )
        VALUES (?, ?, ?, ?)
        `,
        [
          animalId,
          barcode,
          JSON.stringify(images || []),
          qurbaniDatetime,
        ]
      );

      await connection.commit();

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
      await connection.rollback();
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

const { v4: uuidv4 } = require("uuid");
const pool = require("../config/db");
const logger = require("../middleware/logger");

exports.addAnimal = async function addAnimal(adminId, data) {
  const {
    animalType,
    price,
    currency,
    shares,
    lastBookedDate,
    deliveryType,
    deliveryFee,
    deliveryThreshold,
  } = data;

  console.log(
    "[ADD ANIMAL] Incoming price:",
    price,
    currency,
  );

  // Get system base currency (USD)
  const metaResult = await pool.query(
    "SELECT base_currency FROM currency_meta WHERE id = 1"
  );

  const meta = metaResult.rows[0];

  if (!meta) {
    throw new Error("Base currency configuration not found");
  }

  const baseCurrency = meta.base_currency;

  let finalPrice = price;

  // Convert if needed
  if (currency !== baseCurrency) {
    const rateResult = await pool.query(
      `
      SELECT rate
      FROM currency_rates
      WHERE currency_code = $1
        AND base_currency = $2
      `,
      [currency, baseCurrency]
    );

    const rateRow = rateResult.rows[0];

    if (!rateRow) {
      throw new Error(`Missing exchange rate for ${currency}`);
    }

    finalPrice = price / rateRow.rate;

    console.log(
      `[ADD ANIMAL] Converted ${price} ${currency} → ${finalPrice} ${baseCurrency}`
    );
  }

  // Insert animal
  const insertResult = await pool.query(
    `
    INSERT INTO animals
    (
      admin_id,
      animal_type,
      price,
      shares,
      last_booked_date,
      delivery_type,
      delivery_fee,
      delivery_threshold
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    RETURNING id
    `,
    [
      adminId,
      animalType,
      finalPrice,
      shares,
      lastBookedDate,
      deliveryType,
      deliveryFee,
      deliveryThreshold,
    ]
  );

  const animalId = insertResult.rows[0].id;

  logger.info("Animal created successfully", {
    animalId,
    adminId,
    storedPrice: finalPrice,
    baseCurrency,
  });

  console.log(
    `[ADD ANIMAL] Stored base price: ${finalPrice} ${baseCurrency}`
  );

  return animalId;
};
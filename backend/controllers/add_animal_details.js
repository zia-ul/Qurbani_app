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
  const [[meta]] = await pool.execute(
    "SELECT base_currency FROM currency_meta WHERE id = 1",
  );

  const baseCurrency = meta.base_currency;

  let finalPrice = price;

  // Convert if needed
  if (currency !== baseCurrency) {
    const [[rateRow]] = await pool.execute(
      `
      SELECT rate
      FROM currency_rates
      WHERE currency_code = ?
        AND base_currency = ?
      `,
      [currency, baseCurrency],
    );

    if (!rateRow) {
      throw new Error(`Missing exchange rate for ${currency}`);
    }

    finalPrice = price / rateRow.rate;

    console.log(
      `[ADD ANIMAL] Converted ${price} ${currency} → ${finalPrice} ${baseCurrency}`,
    );
  }

  // Store ONLY base price
  // const animalId = crypto.randomUUID();

  await pool.execute(
    `
    INSERT INTO animals
    (admin_id, animal_type, price, shares, last_booked_date,
     delivery_type, delivery_fee, delivery_threshold)
    VALUES ( ?, ?, ?, ?, ?, ?, ?, ?)
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
    ],
  );

   logger.info("Animal created successfully", {
      animalId,
      adminId,
      storedPrice: finalPrice,
      baseCurrency,
    });

  console.log(
    `[ADD ANIMAL] Stored base price: ${finalPrice} ${baseCurrency}`,
  );

  return animalId;
};
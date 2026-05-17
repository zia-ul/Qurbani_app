const logger = require("../middleware/logger");

const orderColumns = [
  ["razorpay_order_id", "VARCHAR(255) NULL"],
  ["razorpay_payment_id", "VARCHAR(255) NULL"],
  ["razorpay_signature", "VARCHAR(255) NULL"],
  ["razorpay_refund_id", "VARCHAR(255) NULL"],
  ["razorpay_refund_status", "VARCHAR(50) NULL DEFAULT 'none'"],
  ["refund_amount", "BIGINT NULL"],
  ["refund_initiated_at", "DATETIME NULL"],
  ["refund_processed_at", "DATETIME NULL"],
  ["payment_verified_at", "DATETIME NULL"],
  ["cancelled_at", "DATETIME NULL"],
  ["cancellation_reason", "TEXT NULL"],
  ["cancellation_requested_by", "CHAR(36) NULL"],
  ["cancellation_status", "VARCHAR(50) NULL DEFAULT 'none'"],
  ["vendor_linked_account_id", "VARCHAR(255) NULL"],
  ["platform_commission_amount", "BIGINT NULL"],
  ["vendor_amount", "BIGINT NULL"],
  ["razorpay_expected_amount", "BIGINT NULL"],
  ["razorpay_currency", "VARCHAR(10) NULL"],
  ["razorpay_order_status", "VARCHAR(50) NULL"],
  ["razorpay_payment_status", "VARCHAR(50) NULL"],
  ["razorpay_transfer_id", "VARCHAR(255) NULL"],
  ["razorpay_transfer_status", "VARCHAR(50) NULL"],
  ["razorpay_transfer_reversal_id", "VARCHAR(255) NULL"],
  ["razorpay_transfer_reversal_status", "VARCHAR(50) NULL"],
  ["refund_error", "TEXT NULL"],
];

async function columnExists(connection, tableName, columnName) {
  const [rows] = await connection.query(
    `
    SELECT 1
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = ?
      AND COLUMN_NAME = ?
    LIMIT 1
    `,
    [tableName, columnName],
  );

  return rows.length > 0;
}

async function tableExists(connection, tableName) {
  const [rows] = await connection.query(
    `
    SELECT 1
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = ?
    LIMIT 1
    `,
    [tableName],
  );

  return rows.length > 0;
}

async function addColumnIfMissing(connection, tableName, columnName, definition) {
  if (await columnExists(connection, tableName, columnName)) {
    return;
  }

  await connection.query(
    `ALTER TABLE \`${tableName}\` ADD COLUMN \`${columnName}\` ${definition}`,
  );
}

async function createWebhookEventsTable(connection) {
  if (await tableExists(connection, "razorpay_webhook_events")) {
    return;
  }

  await connection.query(`
    CREATE TABLE razorpay_webhook_events (
      id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
      razorpay_event_id VARCHAR(255) NOT NULL UNIQUE,
      event_type VARCHAR(100) NOT NULL,
      entity_id VARCHAR(255) NULL,
      payload_json LONGTEXT NOT NULL,
      processed_at DATETIME NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  `);
}

async function createTransfersTable(connection) {
  if (await tableExists(connection, "razorpay_transfers")) {
    return;
  }

  await connection.query(`
    CREATE TABLE razorpay_transfers (
      id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
      order_id INT NOT NULL,
      razorpay_order_id VARCHAR(255) NULL,
      razorpay_payment_id VARCHAR(255) NULL,
      transfer_id VARCHAR(255) NOT NULL UNIQUE,
      linked_account_id VARCHAR(255) NULL,
      amount BIGINT NOT NULL,
      currency VARCHAR(10) NOT NULL DEFAULT 'INR',
      status VARCHAR(50) NULL,
      reversal_id VARCHAR(255) NULL,
      reversal_amount BIGINT NULL,
      reversal_status VARCHAR(50) NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      INDEX idx_razorpay_transfers_order_id (order_id),
      INDEX idx_razorpay_transfers_payment_id (razorpay_payment_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  `);
}

async function ensurePaymentSchema() {
  try {
    logger.info("Supabase schema bootstrap skipped");
    return true;
  } catch (error) {
    logger.error("Failed to initialize payment schema", {
      error: error.message,
      stack: error.stack,
    });

    return false;
  }
}
module.exports = {
  ensurePaymentSchema,
};

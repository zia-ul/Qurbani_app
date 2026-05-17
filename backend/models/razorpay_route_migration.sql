ALTER TABLE orders
  ADD COLUMN razorpay_order_id VARCHAR(255) NULL,
  ADD COLUMN razorpay_payment_id VARCHAR(255) NULL,
  ADD COLUMN razorpay_signature VARCHAR(255) NULL,
  ADD COLUMN razorpay_refund_id VARCHAR(255) NULL,
  ADD COLUMN razorpay_refund_status VARCHAR(50) NULL DEFAULT 'none',
  ADD COLUMN refund_amount BIGINT NULL,
  ADD COLUMN refund_initiated_at DATETIME NULL,
  ADD COLUMN refund_processed_at DATETIME NULL,
  ADD COLUMN payment_verified_at DATETIME NULL,
  ADD COLUMN cancelled_at DATETIME NULL,
  ADD COLUMN cancellation_reason TEXT NULL,
  ADD COLUMN cancellation_requested_by CHAR(36) NULL,
  ADD COLUMN cancellation_status VARCHAR(50) NULL DEFAULT 'none',
  ADD COLUMN vendor_linked_account_id VARCHAR(255) NULL,
  ADD COLUMN platform_commission_amount BIGINT NULL,
  ADD COLUMN vendor_amount BIGINT NULL,
  ADD COLUMN razorpay_expected_amount BIGINT NULL,
  ADD COLUMN razorpay_currency VARCHAR(10) NULL,
  ADD COLUMN razorpay_order_status VARCHAR(50) NULL,
  ADD COLUMN razorpay_payment_status VARCHAR(50) NULL,
  ADD COLUMN razorpay_transfer_id VARCHAR(255) NULL,
  ADD COLUMN razorpay_transfer_status VARCHAR(50) NULL,
  ADD COLUMN razorpay_transfer_reversal_id VARCHAR(255) NULL,
  ADD COLUMN razorpay_transfer_reversal_status VARCHAR(50) NULL,
  ADD COLUMN refund_error TEXT NULL;

ALTER TABLE users
  ADD COLUMN razorpay_linked_account_id VARCHAR(255) NULL;

CREATE TABLE razorpay_webhook_events (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  razorpay_event_id VARCHAR(255) NOT NULL UNIQUE,
  event_type VARCHAR(100) NOT NULL,
  entity_id VARCHAR(255) NULL,
  payload_json LONGTEXT NOT NULL,
  processed_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

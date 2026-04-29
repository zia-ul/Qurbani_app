ALTER TABLE `animals`
  ADD COLUMN `price_per_share` DECIMAL(10,2) NOT NULL DEFAULT 0.00 AFTER `shares`;

ALTER TABLE `shareholder_details`
  ADD COLUMN `animal_type` varchar(50) DEFAULT NULL AFTER `qurbani_day`;

ALTER TABLE `admin_share_setups`
  DROP COLUMN `total_shares`,
  DROP COLUMN `price_per_share`;

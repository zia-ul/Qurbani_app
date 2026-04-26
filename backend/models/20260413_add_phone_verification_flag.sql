ALTER TABLE users
ADD COLUMN is_phone_verified TINYINT(1) NOT NULL DEFAULT 0 AFTER is_verified;

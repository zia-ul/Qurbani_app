-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jan 13, 2026 at 11:37 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `qurbani`
--

-- --------------------------------------------------------

--
-- Table structure for table `admin_verifications`
--

CREATE TABLE `admin_verifications` (
  `id` char(36) NOT NULL,
  `admin_id` char(36) DEFAULT NULL,
  `documents` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`documents`)),
  `status` varchar(50) DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `admin_verification_requests`
--

CREATE TABLE `admin_verification_requests` (
  `id` char(36) NOT NULL,
  `user_id` char(36) NOT NULL,
  `organization_name` varchar(150) NOT NULL,
  `phone` varchar(30) NOT NULL,
  `experience` varchar(50) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `govt_id_url` text NOT NULL,
  `business_proof_url` text NOT NULL,
  `bank_proof_url` text NOT NULL,
  `farm_photo_url` text NOT NULL,
  `status` enum('pending','approved','rejected') DEFAULT 'pending',
  `reviewed_by` char(36) DEFAULT NULL,
  `review_note` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `animals`
--

CREATE TABLE `animals` (
  `id` char(36) NOT NULL,
  `admin_id` char(36) NOT NULL,
  `animal_type` varchar(50) NOT NULL,
  `breed` varchar(100) NOT NULL,
  `price` decimal(10,2) NOT NULL,
  `description` text DEFAULT NULL,
  `age` varchar(50) DEFAULT NULL,
  `height` varchar(50) DEFAULT NULL,
  `weight` varchar(50) DEFAULT NULL,
  `shares` int(11) DEFAULT 1,
  `photo_urls` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`photo_urls`)),
  `payment_methods` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL CHECK (json_valid(`payment_methods`)),
  `delivery_type` enum('Free','Paid') DEFAULT 'Free',
  `delivery_fee` decimal(10,2) DEFAULT 0.00,
  `delivery_threshold` decimal(10,2) DEFAULT 0.00,
  `is_available` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `animals`
--

INSERT INTO `animals` (`id`, `admin_id`, `animal_type`, `breed`, `price`, `description`, `age`, `height`, `weight`, `shares`, `photo_urls`, `payment_methods`, `delivery_type`, `delivery_fee`, `delivery_threshold`, `is_available`, `created_at`) VALUES
('30aec06e-f94d-478e-9a80-13f3b6752a7e', '6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'hhh', 'hjj', 3999.00, NULL, '7', NULL, '56', 1, '[]', '[\"cod\"]', 'Free', 0.00, 0.00, 1, '2026-01-09 08:21:56');

-- --------------------------------------------------------

--
-- Table structure for table `eid_slots`
--

CREATE TABLE `eid_slots` (
  `id` char(36) NOT NULL,
  `admin_id` char(36) DEFAULT NULL,
  `day` varchar(10) DEFAULT NULL,
  `slots` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`slots`))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `orders`
--

CREATE TABLE `orders` (
  `id` char(36) NOT NULL,
  `user_id` char(36) NOT NULL,
  `admin_id` char(36) NOT NULL,
  `payment_method` enum('Cash','Online') NOT NULL,
  `total_shares` int(11) NOT NULL,
  `status` enum('pending','confirmed','completed','cancelled') DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `delivery_status` enum('pending','sent','delivered') DEFAULT 'pending',
  `delivery_person_id` char(36) DEFAULT NULL,
  `delivery_code` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `orders`
--

INSERT INTO `orders` (`id`, `user_id`, `admin_id`, `payment_method`, `total_shares`, `status`, `created_at`, `delivery_status`, `delivery_person_id`, `delivery_code`) VALUES
('81286af2-7dea-4abd-8f09-59a26cbd274b', 'e49b0212-78a7-4684-b1e5-5929347ece16', '6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'Cash', 1, 'pending', '2026-01-12 04:49:20', 'pending', NULL, NULL),
('be21cddc-625d-44e4-9b94-b3257cfc1027', 'e49b0212-78a7-4684-b1e5-5929347ece16', '6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'Online', 1, 'pending', '2026-01-12 04:50:18', 'pending', NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `ratings`
--

CREATE TABLE `ratings` (
  `id` char(36) NOT NULL DEFAULT uuid(),
  `order_id` char(36) NOT NULL,
  `user_id` char(36) NOT NULL,
  `admin_id` char(36) NOT NULL,
  `admin_rating` decimal(2,1) NOT NULL CHECK (`admin_rating` >= 1 and `admin_rating` <= 5),
  `delivery_rating` decimal(2,1) NOT NULL CHECK (`delivery_rating` >= 1 and `delivery_rating` <= 5),
  `feedback` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `requests`
--

CREATE TABLE `requests` (
  `id` char(36) NOT NULL DEFAULT uuid(),
  `order_id` char(36) NOT NULL,
  `user_id` char(36) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text NOT NULL,
  `status` enum('Pending','Approved','Rejected','Completed') DEFAULT 'Pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `reply_message` text DEFAULT NULL,
  `replied_at` datetime DEFAULT NULL,
  `closed_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `shareholders`
--

CREATE TABLE `shareholders` (
  `id` char(36) NOT NULL,
  `order_id` char(36) NOT NULL,
  `name` varchar(255) NOT NULL,
  `guardian_name` varchar(255) NOT NULL,
  `qurbani_day` enum('Day 1','Day 2','Day 3') NOT NULL DEFAULT 'Day 1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `shareholders`
--

INSERT INTO `shareholders` (`id`, `order_id`, `name`, `guardian_name`, `qurbani_day`) VALUES
('7caa1e0c-fc4e-4127-907c-0b252b8edd9e', 'be21cddc-625d-44e4-9b94-b3257cfc1027', 'bb', 'bb', 'Day 1'),
('cad705e3-694d-42ed-8ca9-f249abe977f8', '81286af2-7dea-4abd-8f09-59a26cbd274b', 'hg', 'vb', 'Day 1');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` char(36) NOT NULL,
  `name` varchar(100) NOT NULL,
  `email` varchar(150) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `phone` varchar(30) DEFAULT NULL,
  `country_iso` char(5) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `gender` enum('Male','Female') DEFAULT NULL,
  `role` enum('user','admin','delivery') NOT NULL DEFAULT 'user',
  `admin_status` enum('pending','approved','rejected') DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `currency` char(3) DEFAULT 'USD',
  `verification_token` char(36) DEFAULT NULL,
  `is_verified` tinyint(1) DEFAULT 0,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `description` text DEFAULT '',
  `order_deadline` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `name`, `email`, `password_hash`, `phone`, `country_iso`, `address`, `gender`, `role`, `admin_status`, `city`, `currency`, `verification_token`, `is_verified`, `is_active`, `created_at`, `updated_at`, `description`, `order_deadline`) VALUES
('6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'Admin hajra', 'hajra@gmail.com', '$2b$12$SNUizWtw18XsdhTezFQMCeGMn0Q7xRale6MCo4bxUUPFA2hGUhZga', '9932326266', 'IN', 'ggg', 'Male', 'admin', 'approved', NULL, 'USD', 'd1dbf484-6b2e-4ca6-8bc2-7f0d4e9a7244', 1, 1, '2026-01-09 06:05:42', '2026-01-12 12:16:35', 'vb', NULL),
('ded5a7a4-a203-42b2-abde-bfbe5b9765d1', 'delivery', 'delivery@gmail.com', '$2b$12$DQ56kqVfNqCmvksoEJ516OBFYgsOT4qwIC3AKkgXt7zIP9MrgBXrO', '+916666666666', 'IN', 'vhb', 'Male', 'delivery', NULL, NULL, 'USD', 'bd648cc9-dae1-45f7-b770-7f985d1ce428', 1, 1, '2026-01-13 08:28:53', '2026-01-13 08:30:13', '', NULL),
('e49b0212-78a7-4684-b1e5-5929347ece16', 'hajra', 'hajra.mshahid24@gmail.com', '$2b$12$ooy.JHRY7srI4nEJ8x.FZO6S1EaSQWhudBibcUeWOIoaHiy2bGid2', '9988864646', 'IN', 'ggg', 'Female', 'user', NULL, NULL, 'USD', '1a3e2678-a3c7-48c2-a12f-6fc70090498d', 1, 1, '2026-01-09 05:07:38', '2026-01-12 14:43:47', 'gh', NULL);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `admin_verifications`
--
ALTER TABLE `admin_verifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `admin_id` (`admin_id`);

--
-- Indexes for table `admin_verification_requests`
--
ALTER TABLE `admin_verification_requests`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_user_request` (`user_id`),
  ADD KEY `idx_status` (`status`);

--
-- Indexes for table `animals`
--
ALTER TABLE `animals`
  ADD PRIMARY KEY (`id`),
  ADD KEY `admin_id` (`admin_id`);

--
-- Indexes for table `eid_slots`
--
ALTER TABLE `eid_slots`
  ADD PRIMARY KEY (`id`),
  ADD KEY `admin_id` (`admin_id`);

--
-- Indexes for table `orders`
--
ALTER TABLE `orders`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_user` (`user_id`),
  ADD KEY `fk_admin` (`admin_id`),
  ADD KEY `fk_delivery_person` (`delivery_person_id`);

--
-- Indexes for table `ratings`
--
ALTER TABLE `ratings`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_rating` (`order_id`,`user_id`,`admin_id`),
  ADD KEY `fk_rating_user` (`user_id`),
  ADD KEY `fk_rating_admin` (`admin_id`),
  ADD KEY `idx_ratings_order_user` (`order_id`,`user_id`);

--
-- Indexes for table `requests`
--
ALTER TABLE `requests`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_request_user` (`user_id`),
  ADD KEY `idx_requests_order_user` (`order_id`,`user_id`),
  ADD KEY `idx_requests_status` (`status`);

--
-- Indexes for table `shareholders`
--
ALTER TABLE `shareholders`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_order` (`order_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD KEY `idx_role` (`role`),
  ADD KEY `idx_city` (`city`);

--
-- Constraints for dumped tables
--

--
-- Constraints for table `admin_verifications`
--
ALTER TABLE `admin_verifications`
  ADD CONSTRAINT `admin_verifications_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`);

--
-- Constraints for table `admin_verification_requests`
--
ALTER TABLE `admin_verification_requests`
  ADD CONSTRAINT `admin_verification_requests_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `animals`
--
ALTER TABLE `animals`
  ADD CONSTRAINT `animals_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`);

--
-- Constraints for table `eid_slots`
--
ALTER TABLE `eid_slots`
  ADD CONSTRAINT `eid_slots_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`);

--
-- Constraints for table `orders`
--
ALTER TABLE `orders`
  ADD CONSTRAINT `fk_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_delivery_person` FOREIGN KEY (`delivery_person_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `ratings`
--
ALTER TABLE `ratings`
  ADD CONSTRAINT `fk_rating_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_rating_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_rating_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `requests`
--
ALTER TABLE `requests`
  ADD CONSTRAINT `fk_request_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_request_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `shareholders`
--
ALTER TABLE `shareholders`
  ADD CONSTRAINT `fk_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

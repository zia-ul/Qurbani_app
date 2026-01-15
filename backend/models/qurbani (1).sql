-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jan 15, 2026 at 06:21 PM
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
-- Table structure for table `admin_payment_settings`
--

CREATE TABLE `admin_payment_settings` (
  `admin_id` char(36) NOT NULL,
  `allow_cod` tinyint(1) DEFAULT 0,
  `allow_online` tinyint(1) DEFAULT 1,
  `cod_deadline` date DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `admin_payment_settings`
--

INSERT INTO `admin_payment_settings` (`admin_id`, `allow_cod`, `allow_online`, `cod_deadline`, `updated_at`) VALUES
('6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 1, 0, NULL, '2026-01-15 07:05:08');

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
  `delivery_type` enum('Free','Paid') DEFAULT 'Free',
  `delivery_fee` decimal(10,2) DEFAULT 0.00,
  `delivery_threshold` decimal(10,2) DEFAULT 0.00,
  `is_available` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_booked_date` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `animals`
--

INSERT INTO `animals` (`id`, `admin_id`, `animal_type`, `breed`, `price`, `description`, `age`, `height`, `weight`, `shares`, `photo_urls`, `delivery_type`, `delivery_fee`, `delivery_threshold`, `is_available`, `created_at`, `last_booked_date`) VALUES
('2ac80959-d35a-409e-8a41-ff2b1c263f9a', '6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'Sheep', 'bbb', 336.00, NULL, NULL, NULL, NULL, 2, '[]', 'Paid', 20.00, 0.00, 1, '2026-01-14 06:01:14', NULL),
('30aec06e-f94d-478e-9a80-13f3b6752a7e', '6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'hhh', 'hjj', 3999.00, NULL, '7', NULL, '56', 1, '[]', 'Free', 0.00, 0.00, 1, '2026-01-09 08:21:56', NULL),
('5693c78f-fb86-47d6-a1c5-90ea22625806', '6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'Sheep', 'ghg', 366.00, '', '', '3', '', 1, '[]', 'Paid', 566.00, 0.00, 1, '2026-01-14 05:57:17', NULL),
('7fc3270f-8d7b-401d-a658-151dfedb867d', '6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'Sheep', 'vb', 236.00, NULL, NULL, NULL, NULL, 9, '[]', 'Free', 0.00, 0.00, 1, '2026-01-14 05:58:41', NULL),
('88f38e5d-a914-428a-a194-36bc8a25babc', '6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'Camel', '', 85.00, NULL, NULL, NULL, NULL, 7, '[]', 'Free', 0.00, 0.00, 1, '2026-01-15 07:12:56', NULL),
('8c157aa1-fa6a-43bc-8f18-1ba9d7c65124', '6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'Goat', 'breed', 2355.00, NULL, NULL, NULL, NULL, 1, '[]', 'Free', 0.00, 0.00, 1, '2026-01-13 10:51:53', NULL),
('a519317e-a885-4f57-b02c-9cd07df080d3', '6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'Sheep', 'vvv', 366.00, NULL, NULL, NULL, NULL, 1, '[]', 'Free', 0.00, 0.00, 1, '2026-01-14 06:04:01', '2026-01-14'),
('a545f6e6-82f6-402e-ae0e-e7ee30dca611', '6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'Buffalo', 'vv', 235.00, NULL, NULL, NULL, NULL, 1, '[]', 'Paid', 50.00, 0.00, 1, '2026-01-14 05:52:27', NULL);

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
  `status` enum('active','completed','cancelled') DEFAULT 'active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `delivery_status` enum('pending','sent','delivered') DEFAULT 'pending',
  `delivery_person_id` char(36) DEFAULT NULL,
  `delivery_code` varchar(50) DEFAULT NULL,
  `payment_status` enum('paid','unpaid','pending') DEFAULT 'pending',
  `processing_status` enum('pending','processing','completed') DEFAULT 'pending'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `orders`
--

INSERT INTO `orders` (`id`, `user_id`, `admin_id`, `payment_method`, `total_shares`, `status`, `created_at`, `delivery_status`, `delivery_person_id`, `delivery_code`, `payment_status`, `processing_status`) VALUES
('41ce24be-a48c-4f15-b821-471c2976d43f', 'e49b0212-78a7-4684-b1e5-5929347ece16', '6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'Cash', 1, 'active', '2026-01-15 17:09:33', 'pending', NULL, NULL, 'pending', 'pending'),
('be21cddc-625d-44e4-9b94-b3257cfc1027', 'e49b0212-78a7-4684-b1e5-5929347ece16', '6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'Online', 1, '', '2026-01-12 04:50:18', 'sent', 'ded5a7a4-a203-42b2-abde-bfbe5b9765d1', '883835', 'pending', 'pending');

-- --------------------------------------------------------

--
-- Table structure for table `order_shareholders`
--

CREATE TABLE `order_shareholders` (
  `id` char(36) NOT NULL,
  `order_id` char(36) NOT NULL,
  `animal_id` char(36) NOT NULL,
  `shareholder_name` varchar(100) NOT NULL,
  `guardian_name` varchar(100) NOT NULL,
  `qurbani_day` enum('Day 1','Day 2','Day 3') NOT NULL,
  `price` decimal(10,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `order_shareholders`
--

INSERT INTO `order_shareholders` (`id`, `order_id`, `animal_id`, `shareholder_name`, `guardian_name`, `qurbani_day`, `price`) VALUES
('49f43400-50db-4f14-ae09-f616e65e886d', '41ce24be-a48c-4f15-b821-471c2976d43f', '2ac80959-d35a-409e-8a41-ff2b1c263f9a', 'bb', 'bb', 'Day 1', 336.00);

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

--
-- Dumping data for table `requests`
--

INSERT INTO `requests` (`id`, `order_id`, `user_id`, `title`, `description`, `status`, `created_at`, `reply_message`, `replied_at`, `closed_at`) VALUES
('596c25ae-f081-11f0-b3d6-fc5ceef07ad3', 'be21cddc-625d-44e4-9b94-b3257cfc1027', 'e49b0212-78a7-4684-b1e5-5929347ece16', 'hh', 'nb', 'Pending', '2026-01-13 13:11:19', NULL, NULL, NULL),
('cec0eccb-f227-11f0-a522-fc5ceef07ad3', 'be21cddc-625d-44e4-9b94-b3257cfc1027', 'e49b0212-78a7-4684-b1e5-5929347ece16', 'hh', 'bb', 'Pending', '2026-01-15 15:35:19', NULL, NULL, NULL),
('d6853820-f080-11f0-b3d6-fc5ceef07ad3', 'be21cddc-625d-44e4-9b94-b3257cfc1027', 'e49b0212-78a7-4684-b1e5-5929347ece16', 'kk', 'ii', '', '2026-01-13 13:07:39', 'bb', '2026-01-13 20:06:12', NULL);

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
('7caa1e0c-fc4e-4127-907c-0b252b8edd9e', 'be21cddc-625d-44e4-9b94-b3257cfc1027', 'bb', 'bb', 'Day 1');

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
  `role` enum('user','admin','delivery','pending_admin','pending','super_admin') NOT NULL DEFAULT 'user',
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
('0cecd6eb-ae42-4fbe-929c-57ef2e13010c', 'hsshh', 'haj@gmail.com', '$2b$10$mGca7B/ziK6nUDBBds1DjOW.tsDQTwf3/eA/fa6z7jNSeiC1tKdNG', '+915469880000', 'IN', 'hhshd', 'Female', 'user', NULL, NULL, 'USD', 'c49320bb-01f5-4ea1-a198-2ae826314631', 1, 1, '2026-01-15 09:48:49', '2026-01-15 09:58:08', '', NULL),
('66f5a899-f085-11f0-b3d6-fc5ceef07ad3', '', 'sadmin@gmail.com', '', '5555', '45', 'fff', 'Male', 'super_admin', 'approved', NULL, 'USD', NULL, 0, 1, '2026-01-13 13:40:19', '2026-01-13 13:40:19', '', NULL),
('6a6fcd2a-0e88-495e-aff2-5f0ea76f9d74', 'Admin hajra', 'hajra@gmail.com', '$2b$12$SNUizWtw18XsdhTezFQMCeGMn0Q7xRale6MCo4bxUUPFA2hGUhZga', '9932326266', 'IN', 'ggg', 'Male', 'admin', 'approved', NULL, 'USD', 'd1dbf484-6b2e-4ca6-8bc2-7f0d4e9a7244', 1, 1, '2026-01-09 06:05:42', '2026-01-13 10:54:27', 'vb', '2026-01-16'),
('ded5a7a4-a203-42b2-abde-bfbe5b9765d1', 'delivery', 'delivery@gmail.com', '$2b$12$DQ56kqVfNqCmvksoEJ516OBFYgsOT4qwIC3AKkgXt7zIP9MrgBXrO', '+916666666666', 'IN', 'vhb', 'Male', 'delivery', NULL, NULL, 'USD', 'bd648cc9-dae1-45f7-b770-7f985d1ce428', 1, 1, '2026-01-13 08:28:53', '2026-01-13 08:30:13', '', NULL),
('e49b0212-78a7-4684-b1e5-5929347ece16', 'hajra', 'hajra.mshahid24@gmail.com', '$2b$12$ooy.JHRY7srI4nEJ8x.FZO6S1EaSQWhudBibcUeWOIoaHiy2bGid2', '9988864646', 'IN', 'ggg', 'Female', 'user', NULL, NULL, 'AED', '1a3e2678-a3c7-48c2-a12f-6fc70090498d', 1, 1, '2026-01-09 05:07:38', '2026-01-15 06:09:34', 'gh', NULL),
('ea907a0c-304b-4dbb-a07c-969d2a5584e5', 'super admin', 's_admin@gmail.com', '$2b$12$u6t6RMaQhMGDwmPAX/p7cuWLwftsgT5AQ2WvqxzaDB5RSLefudzCa', '+913235656666', 'IN', 'yyh', 'Male', 'super_admin', NULL, NULL, 'USD', 'c1a406df-7308-4362-a968-7a6f10019108', 1, 1, '2026-01-13 13:43:04', '2026-01-13 13:43:55', '', NULL);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `admin_payment_settings`
--
ALTER TABLE `admin_payment_settings`
  ADD PRIMARY KEY (`admin_id`);

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
-- Indexes for table `order_shareholders`
--
ALTER TABLE `order_shareholders`
  ADD PRIMARY KEY (`id`),
  ADD KEY `order_id` (`order_id`),
  ADD KEY `animal_id` (`animal_id`);

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
-- Constraints for table `order_shareholders`
--
ALTER TABLE `order_shareholders`
  ADD CONSTRAINT `order_shareholders_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `order_shareholders_ibfk_2` FOREIGN KEY (`animal_id`) REFERENCES `animals` (`id`) ON DELETE CASCADE;

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

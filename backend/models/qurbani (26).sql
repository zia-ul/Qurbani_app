-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Mar 21, 2026 at 03:32 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.0.30

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
('573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 1, 1, '2026-03-23', '2026-03-14 06:01:23');

-- --------------------------------------------------------

--
-- Table structure for table `admin_share_setups`
--

CREATE TABLE `admin_share_setups` (
  `id` char(36) NOT NULL,
  `admin_id` char(36) NOT NULL,
  `total_shares` int(11) NOT NULL,
  `price_per_share` decimal(10,2) NOT NULL,
  `late_booking_fee` decimal(10,2) NOT NULL DEFAULT 0.00,
  `last_booking_date` date NOT NULL,
  `delivery_type` enum('free','paid') NOT NULL DEFAULT 'free',
  `delivery_fee` decimal(10,2) NOT NULL DEFAULT 0.00,
  `free_delivery_threshold` decimal(10,2) DEFAULT NULL,
  `currency` char(3) NOT NULL DEFAULT 'USD',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `day1` decimal(10,0) NOT NULL DEFAULT 0,
  `day2` decimal(10,0) NOT NULL DEFAULT 0,
  `day3` decimal(10,0) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `admin_share_setups`
--

INSERT INTO `admin_share_setups` (`id`, `admin_id`, `total_shares`, `price_per_share`, `late_booking_fee`, `last_booking_date`, `delivery_type`, `delivery_fee`, `free_delivery_threshold`, `currency`, `is_active`, `created_at`, `updated_at`, `day1`, `day2`, `day3`) VALUES
('', '573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 350, 2356.00, 56.00, '2026-03-25', 'paid', 25.00, NULL, 'USD', 1, '2026-02-05 07:54:46', '2026-03-20 15:02:11', 3, 12, 10);

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

--
-- Dumping data for table `admin_verification_requests`
--

INSERT INTO `admin_verification_requests` (`id`, `user_id`, `organization_name`, `phone`, `experience`, `address`, `govt_id_url`, `business_proof_url`, `bank_proof_url`, `farm_photo_url`, `status`, `reviewed_by`, `review_note`, `created_at`, `updated_at`) VALUES
('63a773d9-df5b-438a-8917-36b159946440', '573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 'jddhjj', '6669988888', '1', 'hshshhhh', 'https://res.cloudinary.com/dfezveorl/image/upload/v1769756139/meidwgt8olzxdhgatkgk.jpg', 'https://res.cloudinary.com/dfezveorl/image/upload/v1769756142/z98yuwiitzvedyq7e6ef.jpg', 'https://res.cloudinary.com/dfezveorl/image/upload/v1769756145/w2o4wxkbqfjap7fg2zzh.jpg', 'https://res.cloudinary.com/dfezveorl/image/upload/v1769756147/m8irkyhvj8nfqrzt1u0r.jpg', 'approved', 'b49274a9-df58-4529-b29d-a252f2a33d53', 'Documents verified and approved', '2026-01-30 06:55:48', '2026-01-30 06:57:19'),
('b829031f-f3af-4c95-80ab-ad4784e41d99', '52177dcd-3d76-46a8-a542-d13624b31c7a', 'test', '9595999999', '1', 'shshh', 'https://res.cloudinary.com/dfezveorl/image/upload/v1770611602/fyhqr0dtlka0ljzjidra.jpg', 'https://res.cloudinary.com/dfezveorl/image/upload/v1770611606/qqnre5re8lhmfpxt5nlw.jpg', 'https://res.cloudinary.com/dfezveorl/image/upload/v1770611609/vtdm9ut2gcxowxkmoo4f.jpg', 'https://res.cloudinary.com/dfezveorl/image/upload/v1770611613/pgzmgkptihijgdwvhgwx.jpg', 'approved', 'b49274a9-df58-4529-b29d-a252f2a33d53', 'Documents verified and approved', '2026-02-09 04:33:33', '2026-02-09 04:33:50');

-- --------------------------------------------------------

--
-- Table structure for table `animals`
--

CREATE TABLE `animals` (
  `id` int(11) NOT NULL,
  `admin_id` char(36) NOT NULL,
  `animal_type` varchar(50) NOT NULL,
  `shares` int(11) DEFAULT 7,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_booked_date` date DEFAULT NULL,
  `qurbani_datetime` datetime DEFAULT NULL,
  `qurbani_day` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `animals`
--

INSERT INTO `animals` (`id`, `admin_id`, `animal_type`, `shares`, `created_at`, `last_booked_date`, `qurbani_datetime`, `qurbani_day`) VALUES
(1, '573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 'Camel', 7, '2026-03-16 15:02:40', NULL, NULL, NULL),
(2, '573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 'Camel', 7, '2026-03-19 16:09:00', NULL, '2026-03-20 21:38:00', 'day_1'),
(3, '573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 'Buffalo', 7, '2026-03-20 05:38:45', NULL, '2026-03-23 04:13:00', 'day_2');

-- --------------------------------------------------------

--
-- Table structure for table `animal_details`
--

CREATE TABLE `animal_details` (
  `animal_id` int(11) NOT NULL,
  `order_id` int(11) DEFAULT NULL,
  `barcode` varchar(100) DEFAULT NULL,
  `photo_urls` longtext DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `qurbani_datetime` datetime DEFAULT NULL,
  `shareholder_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `animal_details`
--

INSERT INTO `animal_details` (`animal_id`, `order_id`, `barcode`, `photo_urls`, `created_at`, `qurbani_datetime`, `shareholder_id`) VALUES
(1, NULL, '360342914532', '[\"https://res.cloudinary.com/dfezveorl/image/upload/v1773673357/lfwpqlwt8wsf8v17tvdl.jpg\"]', '2026-03-16 15:02:40', NULL, NULL),
(2, NULL, '540454254655', '[]', '2026-03-19 16:09:00', '2026-03-20 21:38:00', NULL),
(3, NULL, '125716506131', '[]', '2026-03-20 05:38:45', '2026-03-23 04:13:00', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `orders`
--

CREATE TABLE `orders` (
  `id` int(11) NOT NULL,
  `user_id` char(36) NOT NULL,
  `admin_id` char(36) NOT NULL,
  `payment_method` tinyint(4) NOT NULL DEFAULT 0 COMMENT '0=Cash, 1=Online',
  `total_shares` int(11) NOT NULL,
  `total_amt` decimal(10,2) NOT NULL DEFAULT 0.00,
  `status` tinyint(4) NOT NULL DEFAULT 0 COMMENT '0=active, 1=completed, 2=cancelled',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `payment_status` tinyint(4) NOT NULL DEFAULT 2 COMMENT '0=paid, 1=unpaid, 2=pending',
  `payment_id` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `orders`
--

INSERT INTO `orders` (`id`, `user_id`, `admin_id`, `payment_method`, `total_shares`, `total_amt`, `status`, `created_at`, `payment_status`, `payment_id`) VALUES
(5038, 'f7596158-0a99-41c3-8f91-565e4a841e58', '573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 0, 1, 2381.00, 0, '2026-03-16 15:06:30', 2, NULL),
(5040, 'f7596158-0a99-41c3-8f91-565e4a841e58', '573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 0, 1, 2381.00, 0, '2026-03-17 16:10:13', 0, NULL),
(5041, 'f7596158-0a99-41c3-8f91-565e4a841e58', '573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 0, 1, 2381.00, 0, '2026-03-17 16:10:31', 0, NULL),
(5042, 'f7596158-0a99-41c3-8f91-565e4a841e58', '573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 0, 1, 2381.00, 0, '2026-03-20 15:01:40', 0, NULL),
(5043, 'f7596158-0a99-41c3-8f91-565e4a841e58', '573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 0, 1, 2381.00, 0, '2026-03-20 15:49:55', 0, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `ratings`
--

CREATE TABLE `ratings` (
  `id` char(36) NOT NULL DEFAULT uuid(),
  `order_id` int(11) NOT NULL,
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
  `id` int(11) NOT NULL,
  `order_id` int(11) NOT NULL,
  `user_id` char(36) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text NOT NULL,
  `status` tinyint(4) NOT NULL DEFAULT 0 COMMENT '0=Pending, 1=Replied, 2=Closed',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `reply_message` text DEFAULT NULL,
  `replied_at` datetime DEFAULT NULL,
  `closed_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `requests`
--

INSERT INTO `requests` (`id`, `order_id`, `user_id`, `title`, `description`, `status`, `created_at`, `reply_message`, `replied_at`, `closed_at`) VALUES
(1, 5040, 'f7596158-0a99-41c3-8f91-565e4a841e58', 'bb', 'bb', 2, '2026-03-20 06:19:20', 'yo', '2026-03-20 11:50:04', '2026-03-20 11:50:22');

-- --------------------------------------------------------

--
-- Table structure for table `shareholder_details`
--

CREATE TABLE `shareholder_details` (
  `id` int(11) NOT NULL,
  `order_id` int(11) NOT NULL,
  `shareholder_name` varchar(100) NOT NULL,
  `guardian_name` varchar(100) NOT NULL,
  `address` longtext DEFAULT NULL,
  `qurbani_day` enum('Day 1','Day 2','Day 3') NOT NULL,
  `price` decimal(10,2) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `animal_id` int(11) DEFAULT NULL,
  `share_number` int(11) DEFAULT NULL,
  `status` tinyint(4) NOT NULL DEFAULT 0 COMMENT '0=Not started, 1=Qurbani Started, 2=Processing, 3=Meat Packaged, 4=Sent for delivery, 5=Delivered, 6=Cancelled',
  `qurbani_datetime` datetime DEFAULT NULL,
  `payment_status` tinyint(4) NOT NULL DEFAULT 2 COMMENT '0=paid, 1=unpaid, 2=pending'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `shareholder_details`
--

INSERT INTO `shareholder_details` (`id`, `order_id`, `shareholder_name`, `guardian_name`, `address`, `qurbani_day`, `price`, `created_at`, `animal_id`, `share_number`, `status`, `qurbani_datetime`, `payment_status`) VALUES
(1, 5038, 'test', 'f1', '{\"country\":\"Argentina\",\"country_iso\":\"IN\",\"state\":\"Mendoza\",\"city\":\"Departamento de La Paz\",\"postal_code\":null,\"address_line\":\"geye\"}', 'Day 1', 2356.00, '2026-03-16 15:06:30', 1, 1, 0, NULL, 0),
(3, 5040, 'gsg', 'b', '{\"country\":\"Argentina\",\"country_iso\":\"IN\",\"state\":\"Mendoza\",\"city\":\"Departamento de La Paz\",\"postal_code\":null,\"address_line\":\"geye\"}', 'Day 1', 2356.00, '2026-03-17 16:10:13', 2, 1, 5, NULL, 0),
(4, 5041, 'hb', 'hh', '{\"country\":\"Argentina\",\"country_iso\":\"IN\",\"state\":\"Mendoza\",\"city\":\"Departamento de La Paz\",\"postal_code\":null,\"address_line\":\"geye\"}', 'Day 1', 2356.00, '2026-03-17 16:10:31', 1, 1, 5, NULL, 0),
(5, 5042, 'ddd', 'bb', '{\"country\":\"Argentina\",\"country_iso\":\"IN\",\"state\":\"Mendoza\",\"city\":\"Departamento de La Paz\",\"postal_code\":null,\"address_line\":\"geye\"}', 'Day 1', 2356.00, '2026-03-20 15:01:40', NULL, NULL, 0, NULL, 2),
(6, 5043, 'tutu', 'turu', '{\"country\":\"Argentina\",\"country_iso\":\"IN\",\"state\":\"Mendoza\",\"city\":\"Departamento de La Paz\",\"postal_code\":null,\"address_line\":\"geye\"}', 'Day 2', 2356.00, '2026-03-20 15:49:55', NULL, NULL, 0, NULL, 0);

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
  `country` varchar(100) DEFAULT NULL,
  `state` varchar(100) DEFAULT NULL,
  `country_iso` char(5) DEFAULT NULL,
  `country_code` varchar(5) NOT NULL,
  `address` text DEFAULT NULL,
  `gender` enum('Male','Female') DEFAULT NULL,
  `role` enum('user','admin','delivery','pending_admin','pending','super_admin') NOT NULL DEFAULT 'user',
  `admin_status` enum('pending','approved','rejected') DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `postal_code` varchar(20) DEFAULT NULL,
  `currency` char(3) DEFAULT 'USD',
  `verification_token` char(36) DEFAULT NULL,
  `is_verified` tinyint(1) DEFAULT 0,
  `is_phone_verified` tinyint(1) DEFAULT 0,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `description` text DEFAULT '',
  `order_deadline` date DEFAULT NULL,
  `photo_url` varchar(500) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `name`, `email`, `password_hash`, `phone`, `country`, `state`, `country_iso`, `country_code`, `address`, `gender`, `role`, `admin_status`, `city`, `postal_code`, `currency`, `verification_token`, `is_verified`, `is_phone_verified`, `is_active`, `created_at`, `updated_at`, `description`, `order_deadline`, `photo_url`) VALUES
('2289b807-a528-4e03-bafc-44e526bd8999', 'hajra', 'test@gmail.com', '$2b$12$EpENYLZ0yP92AAMvZVjDJObWBmwp6xcmmAS5NZD11ZrbyzdZYrenu', '6565666666', 'Armenia', 'Kotayk Region', 'IN', '+91', NULL, 'Female', 'delivery', NULL, 'Bjni', '123456', 'USD', '086c3ba7-33fd-4976-90c9-6f98b6d7b7a6', 0, 0, 1, '2026-02-06 12:41:53', '2026-02-06 12:41:53', '', NULL, NULL),
('2c44acb4-0f2d-42f0-b07e-f3cad14c902f', 'hajra', 'hajra.shahid2401@gmail.com', '$2b$12$EhoQuRshaxmI.YSyTpQ9jeaZjRgLDI1ksDTgslp0k1lm4P6LLM4fG', '9699856888', NULL, NULL, 'IN', '+91', 'gdysg', 'Female', 'user', NULL, NULL, NULL, 'USD', '6881ebfa-6972-478a-9196-84c1d93b72d8', 0, 0, 1, '2026-02-01 15:16:21', '2026-02-01 15:16:21', '', NULL, NULL),
('32739865-2a99-43a3-88f1-4eb578f44c54', 'delivery', 'delivery@gmail.com', '$2b$12$tTIN4W.GOQQkbsnqL8101OsE21aAu9kJNXgUJ6g/RJFRUmIZyPvLG', '9699888888', NULL, NULL, 'IN', '+91', 'uriej', 'Male', 'delivery', NULL, NULL, NULL, 'USD', '465e3b3d-d9c4-4c4e-b30e-2dc171871003', 1, 1, 1, '2026-01-30 06:25:47', '2026-01-30 06:26:12', '', NULL, NULL),
('52177dcd-3d76-46a8-a542-d13624b31c7a', 'admin haj', 'ad@gmail.com', '$2b$12$Azvatw7a4Qfnqet1Bn1KTu8rOYiqBoZo0g09aUvvv7Cv21rzbEuB.', '9595999999', 'Armenia', 'Kotayk Region', 'IN', '+91', NULL, 'Female', 'admin', 'approved', 'Bjni', '123456', 'USD', '8274ee9f-f001-4d37-b610-133d6d18ae27', 1, 1, 1, '2026-02-06 14:12:14', '2026-02-09 04:32:42', '', NULL, NULL),
('573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 'test admin', 'hajra@gmail.com', '$2b$12$ct6SR.TAB3V.O5jsiR1SdeAUyNzb2L2.cGNEzVRa1Wjm5Yzy35LRW', '6669988888', 'India', 'Uttar Pradesh', 'IN', '+91', 'hshsh', 'Male', 'admin', 'approved', 'Aligarh', NULL, 'ARS', '78921d60-7f3a-4d16-8ce1-5812a3f33dcc', 1, 1, 1, '2026-01-30 06:22:22', '2026-03-20 15:01:18', 'testing admin description', '2026-03-25', 'https://res.cloudinary.com/dfezveorl/image/upload/v1769756405/ybtcak4ydgmsmulxyqpp.jpg'),
('5984a6f6-15e6-4fdc-9612-907a653c78a3', 'test delivery', 'del@gmail.com', '$2b$12$2i8uUzdTGXqw56nq3goCZex0h.kFm/DPM5t1Agipln4qVxNKxTwK6', '6565464999', 'Armenia', 'Kotayk Region', 'IN', '+91', NULL, 'Male', 'delivery', NULL, 'Bjni', '123456', 'USD', 'eaf20b92-d95b-4647-9251-35e76a1da867', 0, 0, 1, '2026-02-09 04:12:28', '2026-02-09 04:12:28', '', NULL, NULL),
('68c0d655-61f1-413c-a518-1c8a02f93933', 'vvbb', 'hajraa.mshahid24@gmail.com', '$2b$12$ipyUJd6wwdtfOoYJwUFPreeVGdeMXSS80Ia/e9HvHIIVZ3bOtCBZi', '6464959999', 'Argentina', 'Mendoza', 'IN', '+91', NULL, 'Female', 'user', NULL, 'Departamento de La Paz', '373777', 'USD', '10e4a59a-dab4-4e2d-a45e-dc225aa626f3', 0, 0, 1, '2026-02-05 04:26:36', '2026-02-05 04:26:36', '', NULL, NULL),
('98b5a8fc-ec0c-4bd9-95dd-2081c23bb2b7', 'new admin', 'n_admin@gmail.com', '$2b$12$6ic2kng.JPjxFUCNVsTCIeXUKsb/uhyW643fBfA2HfaEs1iRdmMky', '9494949590', 'India', 'Chandigarh', 'IN', '+91', NULL, 'Male', 'admin', '', 'Chandigarh', '123456', 'USD', 'd0390300-418a-44c0-ac23-e5998d85b217', 1, 1, 1, '2026-02-11 12:54:37', '2026-02-11 12:55:25', '', NULL, NULL),
('b49274a9-df58-4529-b29d-a252f2a33d53', 'super admin account', 's_admin@gmail.com', '$2b$12$h2Svk.sZ8Nui3iJqFAUl3ernMGnJCoOQY8m8hKRMyefi93F3WnLq.', '6262959599', NULL, NULL, 'IN', '+91', 'huhh', 'Male', 'super_admin', NULL, NULL, NULL, 'USD', '9171855f-55b9-4045-9f0f-0747cfd2ba54', 1, 1, 1, '2026-01-30 06:24:18', '2026-01-30 06:26:20', '', NULL, NULL),
('d58ab32c-1213-40fd-975e-6234f6b84c97', 'testt', 'test22@gmail.com', '$2b$12$b4b6Ohszxd9Lohdpun4n7ewq9/1gqVT9qcXlf6F0aL7ASp2dU5KVK', '6666966666666', 'Algeria', 'Batna', 'DZ', '+1', NULL, 'Male', 'user', NULL, 'Batna', '36377', 'USD', 'f06c8eef-a21f-4434-ad27-204c4e1be8e5', 0, 0, 1, '2026-02-12 14:05:18', '2026-02-12 14:05:18', '', NULL, NULL),
('f2f1d573-d470-42b7-bcd0-40c85a49cfbb', 'New delivery person', 'test2@gmail.com', '$2b$12$MZU/V6s33kFMQYgd8eXUO.aaEKkEU67GTX0GNrjfGXeJmlJ6XkHle', '9565999998', 'Armenia', 'Kotayk Region', 'IN', '+91', NULL, 'Male', 'delivery', NULL, 'Bjni', '123456', 'USD', 'eaaa168e-ca0a-4cd0-8b19-bcf87caf9d3d', 0, 0, 1, '2026-02-06 14:15:25', '2026-02-06 14:15:25', '', NULL, NULL),
('f7596158-0a99-41c3-8f91-565e4a841e58', 'Hajra user', 'hajra.mshahid24@gmail.com', '$2b$12$pue6em0ZxeGfq0q/6tID/.ZoeDaNqsnmkSGwJ8STtxHPu5Bz7wmA2', '9698888888', 'Argentina', 'Mendoza', 'IN', '+91', 'geye', 'Female', 'user', NULL, 'Departamento de La Paz', NULL, 'AWG', 'e87d3ae4-5dfb-445d-909a-9825a9dbe536', 1, 1, 1, '2026-01-30 06:25:02', '2026-02-09 12:41:44', '', NULL, NULL),
('fc402b7e-d175-4897-a495-ee01745152df', 'Hajra Shahid', 'hajrashahid4201@gmail.com', '$2b$12$fjLqibr2gFyDJIhHByPWP.8E1LABzWQsY6WNnxXLWckr6CbhhgKx6', '9565659999', NULL, NULL, 'IN', '+91', 'gdyeg', 'Female', 'user', NULL, NULL, NULL, 'USD', NULL, 1, 1, 1, '2026-02-01 15:29:36', '2026-02-01 15:30:02', '', NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `user_devices`
--

CREATE TABLE `user_devices` (
  `id` int(11) NOT NULL,
  `user_id` char(36) NOT NULL,
  `role` enum('user','admin','super_admin') NOT NULL,
  `subscription_id` varchar(255) NOT NULL,
  `device_type` varchar(50) DEFAULT 'android',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `user_devices`
--

INSERT INTO `user_devices` (`id`, `user_id`, `role`, `subscription_id`, `device_type`, `created_at`, `updated_at`) VALUES
(1, 'f7596158-0a99-41c3-8f91-565e4a841e58', 'user', '5f23b16c-9785-4beb-8428-4f1942f6cd46', 'android', '2026-02-22 05:55:11', '2026-02-23 15:17:07'),
(3, '573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 'admin', '5f23b16c-9785-4beb-8428-4f1942f6cd46', 'android', '2026-02-22 06:32:18', '2026-02-23 07:44:01'),
(21, 'f7596158-0a99-41c3-8f91-565e4a841e58', 'user', 'be94f67c-a2c2-4d00-8d34-cdb03b26b1e0', 'android', '2026-03-14 05:55:31', '2026-03-20 14:44:55'),
(22, '573b7cb3-a55e-40e8-a3c8-40369b5e83ec', 'admin', 'be94f67c-a2c2-4d00-8d34-cdb03b26b1e0', 'android', '2026-03-14 05:58:07', '2026-03-20 06:19:55'),
(29, 'f7596158-0a99-41c3-8f91-565e4a841e58', 'user', '5986832f-b09f-43df-b8c4-a4cdf5b7f647', 'android', '2026-03-14 06:46:03', '2026-03-14 06:46:03');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `admin_payment_settings`
--
ALTER TABLE `admin_payment_settings`
  ADD PRIMARY KEY (`admin_id`);

--
-- Indexes for table `admin_share_setups`
--
ALTER TABLE `admin_share_setups`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_admin_share_admin` (`admin_id`);

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
  ADD KEY `animal_fk1` (`admin_id`);

--
-- Indexes for table `animal_details`
--
ALTER TABLE `animal_details`
  ADD PRIMARY KEY (`animal_id`),
  ADD KEY `idx_order_id` (`order_id`),
  ADD KEY `idx_shareholder_id` (`shareholder_id`);

--
-- Indexes for table `orders`
--
ALTER TABLE `orders`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_admin` (`admin_id`),
  ADD KEY `fk_user` (`user_id`);

--
-- Indexes for table `ratings`
--
ALTER TABLE `ratings`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_rating` (`order_id`,`user_id`,`admin_id`),
  ADD UNIQUE KEY `unique_order_user` (`order_id`,`user_id`),
  ADD KEY `fk_rating_user` (`user_id`),
  ADD KEY `fk_rating_admin` (`admin_id`),
  ADD KEY `idx_ratings_order_user` (`order_id`,`user_id`);

--
-- Indexes for table `requests`
--
ALTER TABLE `requests`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_request_order` (`order_id`),
  ADD KEY `fk_request_user` (`user_id`);

--
-- Indexes for table `shareholder_details`
--
ALTER TABLE `shareholder_details`
  ADD PRIMARY KEY (`id`),
  ADD KEY `shareholder_details_ibfk_1` (`order_id`),
  ADD KEY `fk_shareholder_animal` (`animal_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `unique_phone_country` (`country_code`,`phone`),
  ADD KEY `idx_role` (`role`),
  ADD KEY `idx_city` (`city`);

--
-- Indexes for table `user_devices`
--
ALTER TABLE `user_devices`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_user_device` (`user_id`,`subscription_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `animals`
--
ALTER TABLE `animals`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `orders`
--
ALTER TABLE `orders`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5044;

--
-- AUTO_INCREMENT for table `requests`
--
ALTER TABLE `requests`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `shareholder_details`
--
ALTER TABLE `shareholder_details`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `user_devices`
--
ALTER TABLE `user_devices`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=44;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `admin_share_setups`
--
ALTER TABLE `admin_share_setups`
  ADD CONSTRAINT `fk_admin_share_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `admin_verification_requests`
--
ALTER TABLE `admin_verification_requests`
  ADD CONSTRAINT `admin_verification_requests_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `animals`
--
ALTER TABLE `animals`
  ADD CONSTRAINT `animal_fk1` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `animal_details`
--
ALTER TABLE `animal_details`
  ADD CONSTRAINT `fk_animal_details_animal` FOREIGN KEY (`animal_id`) REFERENCES `animals` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_animal_details_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_animal_details_shareholder` FOREIGN KEY (`shareholder_id`) REFERENCES `shareholder_details` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `orders`
--
ALTER TABLE `orders`
  ADD CONSTRAINT `fk_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `ratings`
--
ALTER TABLE `ratings`
  ADD CONSTRAINT `fk_rating_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_rating_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `requests`
--
ALTER TABLE `requests`
  ADD CONSTRAINT `fk_request_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_request_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `shareholder_details`
--
ALTER TABLE `shareholder_details`
  ADD CONSTRAINT `fk_shareholder_animal` FOREIGN KEY (`animal_id`) REFERENCES `animals` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `shareholder_details_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `user_devices`
--
ALTER TABLE `user_devices`
  ADD CONSTRAINT `fk_user_devices_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

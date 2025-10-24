-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Oct 24, 2025 at 02:27 PM
-- Server version: 9.2.0
-- PHP Version: 8.1.10

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `room_reservation_system`
--

-- --------------------------------------------------------

--
-- Table structure for table `booking`
--

CREATE TABLE `booking` (
  `request_id` int NOT NULL,
  `User_id` smallint NOT NULL,
  `name` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `room_id` smallint UNSIGNED NOT NULL,
  `room_name` varchar(10) COLLATE utf8mb4_general_ci NOT NULL,
  `booking_date` date NOT NULL,
  `booking_time` enum('8','10','13','15') COLLATE utf8mb4_general_ci NOT NULL,
  `booking_status` enum('pending','approve','reject','unavailable') COLLATE utf8mb4_general_ci DEFAULT 'pending',
  `approver_name` varchar(50) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `approve_id` smallint DEFAULT NULL,
  `reason` varchar(20) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `booking`
--

INSERT INTO `booking` (`request_id`, `User_id`, `name`, `room_id`, `room_name`, `booking_date`, `booking_time`, `booking_status`, `approver_name`, `approve_id`, `reason`, `created_at`) VALUES
(317, 29, 'ta', 35, 'abc-123', '2025-10-24', '15', 'approve', 'Morgan Freeman', 1, 'Study group meeting', '2025-10-24 10:18:51'),
(318, 4, 'Sam', 35, 'abc-123', '2025-10-24', '13', 'approve', 'James Sunderland', 22, 'Study group meeting', '2025-10-24 12:15:35'),
(319, 6, 'Mike BB', 35, 'abc-123', '2025-10-24', '8', 'reject', 'Morgan Freeman', 1, 'Study group meeting', '2025-10-24 13:40:37'),
(320, 6, 'Mike BB', 35, 'abcs-123', '2025-10-24', '8', 'approve', 'James Sunderland', 22, 'Study group meeting', '2025-10-24 13:51:17');

--
-- Triggers `booking`
--
DELIMITER $$
CREATE TRIGGER `set_booking_details_before_insert` BEFORE INSERT ON `booking` FOR EACH ROW BEGIN
    -- Set room_name
    SET NEW.room_name = (
        SELECT room_name 
        FROM room 
        WHERE room_id = NEW.room_id
    );
    
    -- Set user name
    SET NEW.name = (
        SELECT name 
        FROM users 
        WHERE UserID = NEW.User_id
    );
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `set_room_name_before_insert` BEFORE INSERT ON `booking` FOR EACH ROW BEGIN
    SET NEW.room_name = (
        SELECT room_name 
        FROM room 
        WHERE room_id = NEW.room_id
    );
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `set_user_name_before_insert` BEFORE INSERT ON `booking` FOR EACH ROW BEGIN
    SET NEW.name = (
        SELECT name 
        FROM users 
        WHERE UserID = NEW.User_id
    );
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_approver_name_trigger` BEFORE UPDATE ON `booking` FOR EACH ROW BEGIN
    DECLARE approver_name_var VARCHAR(50);
    
    IF NEW.approve_id IS NOT NULL AND (OLD.approve_id IS NULL OR OLD.approve_id != NEW.approve_id) THEN
        SELECT name INTO approver_name_var
        FROM users 
        WHERE UserID = NEW.approve_id;
        SET NEW.approver_name = approver_name_var;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_room_status_after_insert` AFTER INSERT ON `booking` FOR EACH ROW BEGIN
    UPDATE room 
    SET 
        timestatus8 = CASE WHEN NEW.booking_time = '8' THEN 'Pending' ELSE timestatus8 END,
        timestatus10 = CASE WHEN NEW.booking_time = '10' THEN 'Pending' ELSE timestatus10 END,
        timestatus13 = CASE WHEN NEW.booking_time = '13' THEN 'Pending' ELSE timestatus13 END,
        timestatus15 = CASE WHEN NEW.booking_time = '15' THEN 'Pending' ELSE timestatus15 END
    WHERE room_id = NEW.room_id;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_room_status_on_booking_change` AFTER UPDATE ON `booking` FOR EACH ROW BEGIN
    IF OLD.booking_status != NEW.booking_status THEN
        UPDATE room 
        SET 
            timestatus8 = CASE 
                WHEN NEW.booking_time = '8' THEN 
                    CASE NEW.booking_status
                        WHEN 'approve' THEN 'Reserved'
                        WHEN 'reject' THEN 'Free'
                        ELSE 'Pending'
                    END
                ELSE timestatus8 
            END,
            timestatus10 = CASE 
                WHEN NEW.booking_time = '10' THEN 
                    CASE NEW.booking_status
                        WHEN 'approve' THEN 'Reserved'
                        WHEN 'reject' THEN 'Free'
                        ELSE 'Pending'
                    END
                ELSE timestatus10 
            END,
            timestatus13 = CASE 
                WHEN NEW.booking_time = '13' THEN 
                    CASE NEW.booking_status
                        WHEN 'approve' THEN 'Reserved'
                        WHEN 'reject' THEN 'Free'
                        ELSE 'Pending'
                    END
                ELSE timestatus13 
            END,
            timestatus15 = CASE 
                WHEN NEW.booking_time = '15' THEN 
                    CASE NEW.booking_status
                        WHEN 'approve' THEN 'Reserved'
                        WHEN 'reject' THEN 'Free'
                        ELSE 'Pending'
                    END
                ELSE timestatus15 
            END
        WHERE room_id = NEW.room_id;
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `update_room_status_outside_hours` AFTER UPDATE ON `booking` FOR EACH ROW BEGIN
    IF (HOUR(CURRENT_TIME()) < 8 OR HOUR(CURRENT_TIME()) >= 17) AND NEW.booking_status = 'approve' THEN
        UPDATE room 
        SET 
            timestatus8 = IF(NEW.booking_time = '8' AND timestatus8 = 'Reserved', 'Free', timestatus8),
            timestatus10 = IF(NEW.booking_time = '10' AND timestatus10 = 'Reserved', 'Free', timestatus10),
            timestatus13 = IF(NEW.booking_time = '13' AND timestatus13 = 'Reserved', 'Free', timestatus13),
            timestatus15 = IF(NEW.booking_time = '15' AND timestatus15 = 'Reserved', 'Free', timestatus15)
        WHERE room_id = NEW.room_id;
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `room`
--

CREATE TABLE `room` (
  `room_id` smallint UNSIGNED NOT NULL,
  `room_name` varchar(10) COLLATE utf8mb4_general_ci NOT NULL,
  `room_description` varchar(100) COLLATE utf8mb4_general_ci NOT NULL,
  `timestatus8` enum('Free','Pending','Reserved','Disable','Unavailable') COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'Free',
  `timestatus10` enum('Free','Pending','Reserved','Disable','Unavailable') COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'Free',
  `timestatus13` enum('Free','Pending','Reserved','Disable','Unavailable') COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'Free',
  `timestatus15` enum('Free','Pending','Reserved','Disable','Unavailable') COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'Free'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `room`
--

INSERT INTO `room` (`room_id`, `room_name`, `room_description`, `timestatus8`, `timestatus10`, `timestatus13`, `timestatus15`) VALUES
(1, 'C5-302', 'projector with air conditioner', 'Free', 'Free', 'Free', 'Free'),
(3, 'C1-313', 'A lecture hall, Lcd projector, Screen, Amp, Mic and speaker with 160 available seats', 'Free', 'Free', 'Free', 'Free'),
(4, 'C1-314', 'A lecture hall, Lcd projector, Screen, Amp, Mic and speaker with 160 available seats', 'Free', 'Free', 'Free', 'Free'),
(5, 'S1-301', 'A computer lab room, Lcd projector, Screen, Amp, Mic and speaker with 60 available seats', 'Free', 'Free', 'Free', 'Free'),
(26, 'S7-A-201', 'A perfect room for examination', 'Free', 'Free', 'Free', 'Free'),
(27, 'C1-315', 'A lecture hall, Lcd projector, Screen, Amp, Mic and speaker with 160 available seats', 'Free', 'Free', 'Free', 'Free'),
(32, 'A7-128', 'blablablablabla', 'Disable', 'Disable', 'Disable', 'Disable'),
(33, 'X2123', 'awdawda', 'Free', 'Free', 'Free', 'Free'),
(34, 'qaz-123', 'a new room', 'Free', 'Free', 'Free', 'Free'),
(35, 'abcs-123', 'a new room', 'Reserved', 'Free', 'Reserved', 'Reserved'),
(36, 'ioi-123', 'a new room', 'Disable', 'Disable', 'Disable', 'Disable');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `UserID` smallint NOT NULL,
  `name` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `username` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `password` varchar(60) COLLATE utf8mb4_general_ci NOT NULL,
  `role` enum('0','1','2') COLLATE utf8mb4_general_ci NOT NULL COMMENT '0 = student 1 = staff 2 = appover'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`UserID`, `name`, `username`, `password`, `role`) VALUES
(1, 'Morgan Freeman', 'Freeman_Approver', '$2b$10$02yYYqargD9z7JF9Ixnkf.7XFdxmZgj3g6Hw.W/UL1AMw/SZnI60G', '2'),
(4, 'Sam', 'Sam Lake', '$2b$10$PDV4VpUpMWZnw5Hpz5JnMOaoP.E9BkKSoqsJBfL58NHeO8E60mQ.O', '0'),
(5, 'Tony Morgan', 'Tony_Staff', '$2b$10$Tg7RBqr2sfDHb9cdBoxNSecntWtop55YZyHnh5ngukBIdby8gYdVi', '1'),
(6, 'Mike BB', 'Mike_Student', '$2b$10$FS83ewT4FpI8ifXQUoieIeRVJJgCPW7FVOSSGTPC8iokQfR2D7Fjq', '0'),
(9, 'DB Cooper', 'Cooper7312', '$2b$10$igZdYSDTZthApZXvLpMd6u7OJxmhozORUU.NWXiLpSMjB/aKFAvQG', '0'),
(20, 'John Doe', 'johnfarmer', '$2b$10$LqZFwsJwwfznUcO.hXCXC.UGvAYHjvOIYl3GcTgkKhlO1ZIIjhwH.', '0'),
(22, 'James Sunderland', 'Sunderland_Approver', '$2b$10$ypKXpQHwg6KPfV/3RVKyMOpH2TESnypwdcHVj0p7O1WK1DAV3maAu', '2'),
(29, 'ta', 'taa', '$2b$10$ZHTGSd3wV5ImnDq4tvn5Lu.4Z6ViaydlDw9YMV1ZvvVBKnNc60/R.', '0');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `booking`
--
ALTER TABLE `booking`
  ADD PRIMARY KEY (`request_id`),
  ADD KEY `booking_date` (`booking_date`,`booking_time`,`booking_status`,`approve_id`),
  ADD KEY `User_id` (`User_id`),
  ADD KEY `room_name` (`room_name`),
  ADD KEY `approve_id` (`approve_id`),
  ADD KEY `booking_ibfk_2` (`room_id`);

--
-- Indexes for table `room`
--
ALTER TABLE `room`
  ADD PRIMARY KEY (`room_id`),
  ADD KEY `booking_roomID` (`room_name`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`UserID`),
  ADD UNIQUE KEY `username` (`username`),
  ADD KEY `username_2` (`username`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `booking`
--
ALTER TABLE `booking`
  MODIFY `request_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=321;

--
-- AUTO_INCREMENT for table `room`
--
ALTER TABLE `room`
  MODIFY `room_id` smallint UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=37;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `UserID` smallint NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=30;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `booking`
--
ALTER TABLE `booking`
  ADD CONSTRAINT `booking_ibfk_2` FOREIGN KEY (`room_id`) REFERENCES `room` (`room_id`),
  ADD CONSTRAINT `booking_ibfk_3` FOREIGN KEY (`approve_id`) REFERENCES `users` (`UserID`),
  ADD CONSTRAINT `booking_ibfk_4` FOREIGN KEY (`User_id`) REFERENCES `users` (`UserID`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

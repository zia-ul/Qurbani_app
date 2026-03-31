/**
 * Controller for handling admin verification applications.
 * This module provides endpoints for users to apply for admin verification.
 * It includes validation, database operations, and logging for the application process.
 */

// Import necessary modules
const express = require("express");
const { body, validationResult } = require("express-validator");
const { v4: uuidv4 } = require("uuid");
const db = require("../config/db");
// const auth = require("./auth"); // Commented out alternative auth import
const auth = require("../middleware/authmiddleware");
const isSuperAdmin = require("../middleware/isSuperAdmin");
const logger = require("../middleware/logger");

// Create Express router instance
const router = express.Router();

/**
 * ======================================================
 * ADMIN → SUBMIT VERIFICATION APPLICATION
 * POST /api/admin-verification/apply
 * ======================================================
 * This endpoint allows authenticated users to submit an application for admin verification.
 * It validates the input data, checks for duplicate applications, inserts the request into the database,
 * and updates the user's admin status to 'pending'.
 */
router.post(
  "/apply",
  auth, // Middleware to authenticate the user
  [
    // Validation rules for required fields
    body("organizationName").notEmpty(),
    body("phone").notEmpty(),
    body("govtIdUrl").notEmpty(),
    body("businessProofUrl").notEmpty(),
    body("bankProofUrl").notEmpty(),
    body("farmPhotoUrl").notEmpty(),
  ],
  async (req, res) => {
    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      logger.warn("Invalid admin verification apply request", {
        userId: req.user?.id,
        errors: errors.array(),
      });
      return res.status(400).json({ message: "Invalid input" });
    }

    // Extract user ID and request body data
    const userId = req.user.id;
    const {
      organizationName,
      phone,
      experience,
      address,
      govtIdUrl,
      businessProofUrl,
      bankProofUrl,
      farmPhotoUrl,
    } = req.body;

    logger.info("Admin verification application attempt", { userId });

    try {
      // Check for existing applications to prevent duplicates
      const [existing] = await db.query(
        "SELECT id FROM admin_verification_requests WHERE user_id = ?",
        [userId]
      );

      if (existing.length > 0) {
        logger.warn("Duplicate admin verification application", { userId });
        return res
          .status(409)
          .json({ message: "Application already submitted" });
      }

      // Generate a unique ID for the request
      const requestId = uuidv4();

      // Insert the verification request into the database
      await db.query(
        `INSERT INTO admin_verification_requests
         (id, user_id, organization_name, phone, experience, address,
          govt_id_url, business_proof_url, bank_proof_url, farm_photo_url)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          requestId,
          userId,
          organizationName,
          phone,
          experience || null,
          address || null,
          govtIdUrl,
          businessProofUrl,
          bankProofUrl,
          farmPhotoUrl,
        ]
      );

      // Update the user's admin status to 'pending'
      await db.query(
        "UPDATE users SET admin_status = 'pending' WHERE id = ?",
        [userId]
      );

      logger.info("Admin verification application submitted", {
        userId,
        requestId,
      });

      // Send success response
      res.status(201).json({
        message: "Admin verification application submitted",
      });
    } catch (err) {
      logger.error("Admin verification apply error", {
        userId,
        error: err.message,
        stack: err.stack,
      });

      // Send error response
      res.status(500).json({ message: "Something went wrong. Please try again later." });
    }
  }
);


/**
 * ======================================================
 * SUPER ADMIN → REVIEW APPLICATION
 * POST /api/admin-verification/review
 * ======================================================
 * Note: This route is commented out as it appears to be a duplicate of the /apply route.
 * The review functionality might be implemented elsewhere or not yet developed.
 */

// Commented out duplicate route - not in use
// router.post(
//   "/apply",  // This should probably be "/review" if implemented
//   auth,
//   [
//     body("organizationName").notEmpty(),
//     body("phone").notEmpty(),
//     body("govtIdUrl").notEmpty(),
//     body("businessProofUrl").notEmpty(),
//     body("bankProofUrl").notEmpty(),
//     body("farmPhotoUrl").notEmpty(),
//   ],
//   async (req, res) => {
//     const errors = validationResult(req);
//     if (!errors.isEmpty()) {
//       logger.warn("Invalid admin verification apply request", {
//         userId: req.user?.id,
//         errors: errors.array(),
//       });
//       return res.status(400).json({ message: "Invalid input" });
//     }

//     const userId = req.user.id;
//     const {
//       organizationName,
//       phone,
//       experience,
//       address,
//       govtIdUrl,
//       businessProofUrl,
//       bankProofUrl,
//       farmPhotoUrl,
//     } = req.body;

//     logger.info("Admin verification application attempt", { userId });

//     try {
//       // Prevent duplicate applications
//       const [existing] = await db.query(
//         "SELECT id FROM admin_verification_requests WHERE user_id = ?",
//         [userId]
//       );

//       if (existing.length > 0) {
//         logger.warn("Duplicate admin verification application", { userId });
//         return res
//           .status(409)
//           .json({ message: "Application already submitted" });
//       }

//       const requestId = uuidv4();

//       await db.query(
//         `INSERT INTO admin_verification_requests
//          (id, user_id, organization_name, phone, experience, address,
//           govt_id_url, business_proof_url, bank_proof_url, farm_photo_url)
//          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
//         [
//           requestId,
//           userId,
//           organizationName,
//           phone,
//           experience || null,
//           address || null,
//           govtIdUrl,
//           businessProofUrl,
//           bankProofUrl,
//           farmPhotoUrl,
//         ]
//       );

//       await db.query(
//         "UPDATE users SET admin_status = 'pending' WHERE id = ?",
//         [userId]
//       );

//       logger.info("Admin verification application submitted", {
//         userId,
//         requestId,
//       });

//       res.status(201).json({
//         message: "Admin verification application submitted",
//       });
//     } catch (err) {
//       logger.error("Admin verification apply error", {
//         userId,
//         error: err.message,
//         stack: err.stack,
//       });

//       res.status(500).json({ message: "Something went wrong. Please try again later." });
//     }
//   }
// );


module.exports = router;

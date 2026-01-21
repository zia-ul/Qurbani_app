const express = require("express");
const { body, validationResult } = require("express-validator");
const { v4: uuidv4 } = require("uuid");
const db = require("../config/db");
// const auth = require("./auth");
const auth = require("../middleware/authmiddleware");
const isSuperAdmin = require("../middleware/isSuperAdmin");
const logger = require("../middleware/logger");

const router = express.Router();

/**
 * ======================================================
 * ADMIN → SUBMIT VERIFICATION APPLICATION
 * POST /api/admin-verification/apply
 * ======================================================
 */
router.post(
  "/apply",
  auth,
  [
    body("organizationName").notEmpty(),
    body("phone").notEmpty(),
    body("govtIdUrl").notEmpty(),
    body("businessProofUrl").notEmpty(),
    body("bankProofUrl").notEmpty(),
    body("farmPhotoUrl").notEmpty(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      logger.warn("Invalid admin verification apply request", {
        userId: req.user?.id,
        errors: errors.array(),
      });
      return res.status(400).json({ message: "Invalid input" });
    }

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
      // Prevent duplicate applications
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

      const requestId = uuidv4();

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

      await db.query(
        "UPDATE users SET admin_status = 'pending' WHERE id = ?",
        [userId]
      );

      logger.info("Admin verification application submitted", {
        userId,
        requestId,
      });

      res.status(201).json({
        message: "Admin verification application submitted",
      });
    } catch (err) {
      logger.error("Admin verification apply error", {
        userId,
        error: err.message,
        stack: err.stack,
      });

      res.status(500).json({ message: "Something went wrong. Please try again later." });
    }
  }
);


/**
 * ======================================================
 * SUPER ADMIN → REVIEW APPLICATION
 * POST /api/admin-verification/review
 * ======================================================
 */

// router.post(
//   "/apply",
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

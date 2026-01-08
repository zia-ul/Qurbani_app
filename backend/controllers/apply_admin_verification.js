const express = require("express");
const { body, validationResult } = require("express-validator");
const { v4: uuidv4 } = require("uuid");
const db = require("../config/db");
const auth = require("./auth");
const isSuperAdmin = require("../middleware/isSuperAdmin");

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

    try {
      // Prevent duplicate applications
      const [existing] = await db.query(
        "SELECT id FROM admin_verification_requests WHERE user_id = ?",
        [userId]
      );

      if (existing.length > 0) {
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

      // Ensure admin stays pending
      await db.query(
        "UPDATE users SET admin_status = 'pending' WHERE id = ?",
        [userId]
      );

      res.status(201).json({
        message: "Admin verification application submitted",
      });
    } catch (err) {
      console.error("Admin apply error:", err);
      res.status(500).json({ message: "Server error" });
    }
  }
);

/**
 * ======================================================
 * SUPER ADMIN → REVIEW APPLICATION
 * POST /api/admin-verification/review
 * ======================================================
 */
router.post(
  "/review",
  auth,
  isSuperAdmin,
  async (req, res) => {
    const { requestId, status, note } = req.body;

    if (!requestId || !["approved", "rejected"].includes(status)) {
      return res.status(400).json({ message: "Invalid request" });
    }

    try {
      const [[request]] = await db.query(
        "SELECT user_id FROM admin_verification_requests WHERE id = ?",
        [requestId]
      );

      if (!request) {
        return res.status(404).json({ message: "Request not found" });
      }

      await db.query(
        `UPDATE admin_verification_requests
         SET status = ?, reviewed_by = ?, review_note = ?
         WHERE id = ?`,
        [status, req.user.id, note || null, requestId]
      );

      // If approved → activate admin
      if (status === "approved") {
        await db.query(
          "UPDATE users SET admin_status = 'approved' WHERE id = ?",
          [request.user_id]
        );
      }

      res.json({ message: "Admin verification reviewed successfully" });
    } catch (err) {
      console.error("Admin review error:", err);
      res.status(500).json({ message: "Server error" });
    }
  }
);

module.exports = router;

const express = require("express");
const router = express.Router();
const controller = require("../controllers/admin_payment_settings.controller");

/**
 * @swagger
 * /api/admins/{adminId}/payment-settings:
 *   get:
 *     summary: Get public payment settings for an admin
 *     description: Fetches payment configuration of an admin for the user order page. No authentication required.
 *     tags: [Admin Payment Settings]
 *     parameters:
 *       - in: path
 *         name: adminId
 *         required: true
 *         description: Admin user ID
 *         schema:
 *           type: string
 *           example: "b3b6f4e2-1234-4567-89ab-9cdef1234567"
 *     responses:
 *       200:
 *         description: Admin payment settings fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 paymentMethod:
 *                   type: string
 *                   example: "online"
 *                 accountName:
 *                   type: string
 *                   example: "Admin Name"
 *                 accountNumber:
 *                   type: string
 *                   example: "03001234567"
 *                 bankName:
 *                   type: string
 *                   example: "HBL"
 *       404:
 *         description: Admin or payment settings not found
 *       500:
 *         description: Internal server error
 */


// User order page (NO auth)
router.get(
  "/admins/:adminId/payment-settings",
  controller.getAdminPaymentSettingsPublic
);

module.exports = router;

const express = require("express");
const router = express.Router();
const controller = require("../controllers/admin_payment_settings.controller");

// User order page (NO auth)
router.get(
  "/admins/:adminId/payment-settings",
  controller.getAdminPaymentSettingsPublic
);

module.exports = router;

const express = require("express");
const router = express.Router();
const auth = require("../middleware/authmiddleware");
const controller = require("../controllers/admin_payment_settings");

// Admin dashboard
router.get("/payment-settings", auth, controller.getMyPaymentSettings);
router.put("/payment-settings", auth, controller.updateMyPaymentSettings);

module.exports = router;

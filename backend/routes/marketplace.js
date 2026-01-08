const express = require("express");
const { fetchVerifiedAdmins } = require("../controllers/marketplaceAdmin");

const router = express.Router();

/**
 * PUBLIC – Fetch verified admins
 */
router.get("/verified", fetchVerifiedAdmins);

module.exports = router;

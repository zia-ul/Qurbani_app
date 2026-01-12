const express = require("express");
const router = express.Router();

router.use("/", require("../controllers/user_order"));
router.use("/admin", require("../controllers/admin_order"));

module.exports = router;

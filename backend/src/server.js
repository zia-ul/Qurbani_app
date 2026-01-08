const express = require("express");
const cors = require("cors");
const bodyParser = require("body-parser");
const authRoutes = require('../controllers/auth');
const adminVerificationRoutes = require("../controllers/apply_admin_verification");
const animalRoutes = require("../routes/animal");
const adminRoutes = require("../routes/marketplace");

const app = express();

app.use(cors());
app.use(bodyParser.json());

app.use('/api/auth', authRoutes);
app.use("/api/admin-verification", adminVerificationRoutes);
app.use("/api/animals", animalRoutes);
app.use("/api/admins", adminRoutes);
app.use("/api/orders", require("../controllers/orders"));

const PORT = 3000;

app.get("/", (req, res) => {
  res.send("API is running");
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});
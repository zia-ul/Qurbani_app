const express = require("express");
const cors = require("cors");
const bodyParser = require("body-parser");
const authRoutes = require('../controllers/auth');
const animalListRoutes = require('../routes/animallist');
const adminVerificationRoutes = require("../controllers/apply_admin_verification");
const animalRoutes = require("../routes/addanimal");
const adminRoutes = require("../routes/marketplace");
const adminProfileRoutes = require("../routes/adminprofile");
const orderRoutes = require("../controllers/orders"); 
const userRoutes = require("../routes/users"); 
require('dotenv').config();

console.log("JWT_SECRET:", process.env.JWT_SECRET);

const app = express();

app.use(cors());
app.use(bodyParser.json());

// Existing routes
app.use('/api/auth', authRoutes);
app.use("/api/auth/adminprofile", adminProfileRoutes);
app.use("/api/admin-verification", adminVerificationRoutes);
app.use("/api/animals", animalRoutes);
app.use("/api/admins", adminRoutes);
// app.use("/api/orders", orderRoutes); 
app.use("/api/animals", animalListRoutes);

app.use("/api/orders", require("../routes/orders"));
app.use("/api/ratings", require("../routes/rating_routes"));
app.use("/api/requests", require("../routes/requests_routes"));


// Mount the user-related routes (profile, ratings, requests, delivery-boys)
app.use('/api', userRoutes); // This mounts /api/profile, /api/ratings, /api/requests, /api/delivery-boys


const PORT = 3000;

app.get("/", (req, res) => {
  res.send("API is running");
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});
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
const adminPaymentRoutes = require("../routes/admin_payment_routes");
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('../swagger');
const requestLogger = require("../middleware/request_logger");
const errorHandler = require("../middleware/error_logger");
const rateLimit = require("express-rate-limit");

require("./cron");
require('dotenv').config();
console.log("Using API key:", process.env.OPENEXCHANGE_API_KEY);

// Winston logger
const logger = require("../middleware/logger");
logger.info("Application starting");

// Express app setup
const app = express();

// Global rate limiter (applies to all requests)
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 200, // limit each IP to 200 requests per window
  message: {
    message: "Too many requests from this IP, please try again later."
  },
  standardHeaders: true, // Return rate limit info in headers
  legacyHeaders: false,
});

app.use(globalLimiter);


// Cross-Origin Resource Sharing
app.use(cors());
app.use(bodyParser.json());
app.use(requestLogger); 
app.use(errorHandler);

// routes
app.use('/api/auth', authRoutes);
app.use("/api/auth/adminprofile", adminProfileRoutes);
app.use("/api/admin-verification", adminVerificationRoutes);
app.use("/api/animals", animalRoutes);
app.use("/api/admins", adminRoutes);
app.use("/api/orders", orderRoutes); 
app.use("/api/animals", animalListRoutes);

// Orders
app.use("/api/orders", require("../routes/orders"));

app.use("/api/users", require("../routes/currency_rates"))

// Rating Routes
app.use("/api/ratings", require("../routes/rating_routes"));

// Special Requests Routes
app.use("/api/requests", require("../routes/requests_routes"));

app.use("/api/slots", require("../routes/slots")); // Mount the slots routes

// Admin payment settings
app.use("/api/admin/payment-settings", adminPaymentRoutes);
app.use("/api/admin", require("../routes/admin_payment_routes"));
app.use("/api", require("../routes/public_admin_routes"));

// user-related routes (profile, ratings, requests, delivery-boys)
app.use('/api', userRoutes); // This mounts /api/profile, /api/ratings, /api/requests, /api/delivery-boys

// Swagger API docs
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

const PORT = 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});
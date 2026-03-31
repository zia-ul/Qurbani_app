const express = require("express");
const cors = require("cors");
const swaggerUi = require("swagger-ui-express");
const rateLimit = require("express-rate-limit");
require("dotenv").config();

const authRoutes = require("../controllers/auth");
const animalListRoutes = require("../routes/animallist");
const adminVerificationRoutes = require("../controllers/apply_admin_verification");
const animalRoutes = require("../routes/addanimal");
const adminRoutes = require("../routes/marketplace");
const adminProfileRoutes = require("../routes/adminprofile");
const orderRoutes = require("../controllers/orders");
const userRoutes = require("../routes/users");
const adminPaymentRoutes = require("../routes/admin_payment_routes");
const swaggerSpec = require("../swagger");
const requestLogger = require("../middleware/request_logger");
const errorHandler = require("../middleware/error_logger");
const logger = require("../middleware/logger");

logger.info("Application starting");

const app = express();

const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 2000,
  message: {
    message: "Too many requests from this IP, please try again later."
  },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use(globalLimiter);
app.use(cors());
app.use(express.json());
app.use(requestLogger);

// health check
app.get("/", (req, res) => {
  res.json({ ok: true, message: "Backend is running" });
});

app.get("/health", (req, res) => {
  res.json({ ok: true });
});

// routes
app.use("/api/auth", authRoutes);
app.use("/api/auth/adminprofile", adminProfileRoutes);
app.use("/api/admin-verification", adminVerificationRoutes);
app.use("/api/animals", animalRoutes);
app.use("/api/admins", adminRoutes);
app.use("/api/orders", orderRoutes);
app.use("/api/animals", animalListRoutes);
app.use("/api/shareholders", require("../routes/shareholder"));
app.use("/api/superadmin", require("../routes/superadmin"));
app.use("/api/notifications", require("../routes/notifications"));
app.use("/api/ratings", require("../routes/rating_routes"));
app.use("/api/requests", require("../routes/requests_routes"));
app.use("/api/admin/payment-settings", adminPaymentRoutes);
app.use("/api/admin", require("../routes/admin_payment_routes"));
app.use("/api", require("../routes/public_admin_routes"));
app.use("/api", userRoutes);
app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// error handler should usually be last
app.use(errorHandler);

module.exports = app;

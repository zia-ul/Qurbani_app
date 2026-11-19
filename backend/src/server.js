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

// Winston logger
const logger = require("../middleware/logger");
logger.info("Application starting");

// Express app setup
const app = express();
const compression = require("compression");

// Trust proxy for reverse proxies (Render, Cloudflare)
app.set("trust proxy", 1);

// Gzip compression for high-performance payload transfer
app.use(compression());

// Health check endpoint for uptime monitors
app.get("/api/health", (req, res) => {
  res.status(200).json({ status: "ok", timestamp: new Date().toISOString() });
});

// Public Privacy Policy endpoint for Google Play Console compliance
app.get(["/privacy-policy", "/privacy"], (req, res) => {
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Privacy Policy - Qurbani App</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; color: #2d3748; max-width: 800px; margin: 0 auto; padding: 24px; background: #f7fafc; }
    .card { background: #ffffff; padding: 32px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
    h1 { color: #1a202c; border-bottom: 2px solid #edf2f7; padding-bottom: 12px; }
    h2 { color: #2b6cb0; margin-top: 24px; }
    p, li { font-size: 15px; }
    .contact { background: #ebf8ff; border-left: 4px solid #3182ce; padding: 12px 16px; margin-top: 24px; border-radius: 4px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Privacy Policy</h1>
    <p><strong>Last updated:</strong> November 2026</p>
    <p>This Privacy Policy describes how the <strong>Qurbani App</strong> ("we", "us", or "our") collects, uses, and safeguards information when you use our mobile application and related online services.</p>
    
    <h2>1. Information We Collect</h2>
    <p>When you create an account, browse livestock, book sacrificial shares, or manage orders, we may collect:</p>
    <ul>
      <li><strong>Account Details:</strong> Full name, email address, phone number, and delivery address.</li>
      <li><strong>Order & Transaction Data:</strong> Details of animals selected, share quantities, order timestamps, and payment reference identifiers.</li>
      <li><strong>Device & Usage Data:</strong> Basic device telemetry, operating system version, and anonymous crash analytics to keep the app secure and stable.</li>
    </ul>

    <h2>2. How We Use Your Information</h2>
    <ul>
      <li>To process, fulfill, and track your livestock and Qurbani share bookings.</li>
      <li>To coordinate timely slaughter, butchering, and meat delivery with verified personnel.</li>
      <li>To communicate order confirmation, status updates, and essential service alerts.</li>
      <li>To prevent fraudulent bookings and ensure platform security.</li>
    </ul>

    <h2>3. Data Protection and Security</h2>
    <p>We implement industry-standard encryption and security measures to protect your personal information against unauthorized access, alteration, or disclosure. All data transmissions between the application and our servers are encrypted via HTTPS / TLS.</p>

    <h2>4. Third-Party Services</h2>
    <p>We do not sell, rent, or trade your personal information. Data is shared strictly with necessary operational providers (such as cloud hosting and database infrastructure) to deliver our core services.</p>

    <h2>5. Data Retention & Account Deletion</h2>
    <p>We retain your personal data for as long as your account remains active or as required by law. Users may request account deletion or data removal at any time by contacting us.</p>

    <h2>6. Contact Us</h2>
    <div class="contact">
      <p>If you have questions or inquiries regarding this Privacy Policy or your personal information, please contact us at:</p>
      <p><strong>Email:</strong> <a href="mailto:ziaulislam83413@gmail.com">ziaulislam83413@gmail.com</a></p>
      <p><strong>App:</strong> Qurbani (Package: com.aivion.qurbani)</p>
    </div>
  </div>
</body>
</html>`);
});

// Global rate limiter (applies to all requests)
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 2000, // limit each IP to 2000 requests per window
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
app.use("/api/shareholders", require("../routes/shareholder"));
app.use("/api/superadmin", require("../routes/superadmin"));

// Orders
// app.use("/api/orders", require("../routes/orders"));

app.use("/api/users", require("../routes/currency_rates"))

// Rating Routes
app.use("/api/ratings", require("../routes/rating_routes"));

// Special Requests Routes
app.use("/api/requests", require("../routes/requests_routes"));

// Admin payment settings
app.use("/api/admin/payment-settings", adminPaymentRoutes);
app.use("/api/admin", require("../routes/admin_payment_routes"));
app.use("/api", require("../routes/public_admin_routes"));

// user-related routes (profile, ratings, requests, delivery-boys)
app.use('/api', userRoutes); // This mounts /api/profile, /api/ratings, /api/requests, /api/delivery-boys

// Swagger API docs
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});
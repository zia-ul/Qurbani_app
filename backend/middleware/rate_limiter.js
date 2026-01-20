const rateLimit = require("express-rate-limit");

exports.loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // max 5 requests per IP
  message: { message: "Too many login attempts. Try again after 15 minutes." },
  standardHeaders: true,
  legacyHeaders: false,
});

exports.registerLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10, // max 10 registration attempts per IP
  message: { message: "Too many registration attempts. Try again later." },
  standardHeaders: true,
  legacyHeaders: false,
});

const jwt = require("jsonwebtoken");

// JWT middleware
const authMiddleware = (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ message: "No token provided" });
  }

  const token = authHeader.split(" ")[1];

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ message: "Invalid token" });
  }
};

module.exports = authMiddleware;

// const jwt = require("jsonwebtoken");
// const logger = require("../middleware/logger");

// /**
//  * Authentication Middleware
//  * -------------------------
//  * Verifies JWT token from Authorization header
//  * and attaches decoded user data to req.user
//  */

// const authMiddleware = async (req, res, next) => {
//   try {
//     /**
//      * Get Authorization Header
//      */
//     const authHeader = req.headers.authorization;

//     /**
//      * Validate Header
//      */
//     if (!authHeader) {
//       logger.warn("Authorization header missing", {
//         ip: req.ip,
//         route: req.originalUrl,
//       });

//       return res.status(401).json({
//         success: false,
//         message: "Authorization token is required",
//       });
//     }

//     /**
//      * Validate Bearer Format
//      */
//     if (!authHeader.startsWith("Bearer ")) {
//       logger.warn("Invalid authorization format", {
//         ip: req.ip,
//         route: req.originalUrl,
//       });

//       return res.status(401).json({
//         success: false,
//         message: "Invalid authorization format",
//       });
//     }

//     /**
//      * Extract Token
//      */
//     const token = authHeader.split(" ")[1];

//     if (!token) {
//       logger.warn("JWT token missing after Bearer", {
//         ip: req.ip,
//         route: req.originalUrl,
//       });

//       return res.status(401).json({
//         success: false,
//         message: "Token not provided",
//       });
//     }

//     /**
//      * Verify JWT Secret Exists
//      */
//     if (!process.env.JWT_SECRET) {
//       logger.error("JWT_SECRET is not configured");

//       return res.status(500).json({
//         success: false,
//         message: "Server configuration error",
//       });
//     }

//     /**
//      * Verify Token
//      */
//     const decoded = jwt.verify(token, process.env.JWT_SECRET);

//     /**
//      * Validate Decoded Payload
//      */
//     if (!decoded || !decoded.id) {
//       logger.warn("Invalid JWT payload", {
//         route: req.originalUrl,
//       });

//       return res.status(401).json({
//         success: false,
//         message: "Invalid token payload",
//       });
//     }

//     /**
//      * Attach User To Request
//      */
//     req.user = {
//       id: decoded.id,
//       email: decoded.email || null,
//       role: decoded.role || "user",
//     };

//     logger.info("User authenticated", {
//       userId: decoded.id,
//       route: req.originalUrl,
//     });

//     next();
//   } catch (err) {
//     /**
//      * Handle JWT Errors
//      */
//     if (err.name === "TokenExpiredError") {
//       logger.warn("JWT token expired", {
//         error: err.message,
//       });

//       return res.status(401).json({
//         success: false,
//         message: "Token expired",
//       });
//     }

//     if (err.name === "JsonWebTokenError") {
//       logger.warn("Invalid JWT token", {
//         error: err.message,
//       });

//       return res.status(401).json({
//         success: false,
//         message: "Invalid token",
//       });
//     }

//     /**
//      * Unknown Errors
//      */
//     logger.error("Authentication middleware error", {
//       error: err.message,
//       stack: err.stack,
//     });

//     return res.status(500).json({
//       success: false,
//       message: "Authentication failed",
//     });
//   }
// };

// module.exports = authMiddleware;
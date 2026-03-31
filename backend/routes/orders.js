/**
 * Orders Routes Module
 *
 * This module handles all order-related API operations in the Qurbani application.
 * It manages the complete order lifecycle including creation, status updates,
 * cancellations, special requests, and payment processing.
 *
 * Routes are organized by functionality:
 * - User Routes: Order details, cancellation, special requests, payment updates
 * - Admin Routes: Order status management and updates (delegated to controllers)
 *
 * Key Features:
 * - Secure order access with user authentication and ownership validation
 * - Admin-only order management with role-based access control
 * - Time-based cancellation policies (24-hour window)
 * - Payment gateway integration for online payments
 * - Comprehensive audit logging for all order operations
 * - Special request system for custom order modifications
 */

const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const { v4: uuidv4 } = require("uuid");
const logger = require("../middleware/logger");

// Mount user order routes from controller
router.use("/", require("../controllers/user_order"));
// Mount admin order routes from controller
// router.use("/admin", require("../controllers/admin_order"));


/**
 * @swagger
 * /api/orders/{orderId}/payment-success:
 *   put:
 *     summary: Update order payment status after online payment
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: orderId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - paymentId
 *             properties:
 *               paymentId:
 *                 type: string
 *     responses:
 *       200:
 *         description: Payment updated successfully
 *       401:
 *         description: Unauthorized
 *       500:
 *         description: Something went wrong. Please try again later.
 */

module.exports = router;

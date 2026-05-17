const express = require("express");
const router = express.Router();
const { v4: uuidv4 } = require("uuid");

const supabase = require("../config/db");
const auth = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");

/**
 * Utility Functions
 */
const sanitizeText = (value) => {
  if (value === null || value === undefined) return "";
  return String(value).trim();
};

const parseNumber = (value, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const mapPaymentMethod = (method) => {
  switch (Number(method)) {
    case 0:
      return "Cash";
    case 1:
      return "Online";
    default:
      return "Unknown";
  }
};

const mapPaymentStatus = (status) => {
  switch (status) {
    case 0:
    case "paid":
      return "Paid";

    case 1:
    case "unpaid":
      return "Unpaid";

    case 2:
    case "pending":
      return "Pending";

    default:
      return "Unknown";
  }
};

/**
 * ==============================
 * GET MY ORDERS
 * ==============================
 */
router.get("/my", auth, async (req, res) => {
  const userId = req.user.id;

  try {
    const { data: orders, error } = await supabase
      .from("orders")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false });

    if (error) {
      logger.error("Supabase fetch orders error", {
        userId,
        error: error.message,
      });

      return res.status(500).json({
        success: false,
        message: "Failed to fetch orders",
      });
    }

    logger.info("Fetched user orders", {
      userId,
      count: orders.length,
    });

    return res.json({
      success: true,
      orders,
    });
  } catch (err) {
    logger.error("Unexpected error fetching user orders", {
      userId,
      error: err.message,
      stack: err.stack,
    });

    return res.status(500).json({
      success: false,
      message: "Something went wrong. Please try again later.",
    });
  }
});

/**
 * ==============================
 * GET SINGLE ORDER
 * ==============================
 */
router.get("/:orderId", auth, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    /**
     * Fetch Order
     */
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select(`
        *,
        admin:users!orders_admin_id_fkey (
          id,
          name,
          phone,
          address
        )
      `)
      .eq("id", orderId)
      .eq("user_id", userId)
      .single();

    if (orderError || !order) {
      logger.warn("Order not found", {
        orderId,
        userId,
        error: orderError?.message,
      });

      return res.status(404).json({
        success: false,
        message: "Order not found",
      });
    }

    /**
     * Fetch Shareholders + Animals
     */
    const { data: shareholders, error: shareholderError } = await supabase
      .from("shareholder_details")
      .select(`
        *,
        animal:animals (
          id,
          animal_type,
          breed,
          price,
          age,
          weight,
          shares
        )
      `)
      .eq("order_id", orderId);

    if (shareholderError) {
      logger.error("Failed to fetch shareholders", {
        orderId,
        error: shareholderError.message,
      });

      return res.status(500).json({
        success: false,
        message: "Failed to fetch order details",
      });
    }

    order.animals = shareholders || [];

    logger.info("Fetched order details", {
      orderId,
      userId,
      animalsCount: shareholders.length,
    });

    return res.json({
      success: true,
      order,
    });
  } catch (err) {
    logger.error("Unexpected error fetching order", {
      orderId,
      userId,
      error: err.message,
      stack: err.stack,
    });

    return res.status(500).json({
      success: false,
      message: "Something went wrong. Please try again later.",
    });
  }
});

/**
 * ==============================
 * CREATE ORDER
 * ==============================
 */
router.post("/", auth, async (req, res) => {
  const userId = req.user.id;

  try {
    const {
      adminId,
      paymentMethod,
      paymentStatus,
      shareholders,
    } = req.body;

    /**
     * Validation
     */
    if (!adminId) {
      return res.status(400).json({
        success: false,
        message: "Admin ID is required",
      });
    }

    if (paymentMethod === undefined || paymentMethod === null) {
      return res.status(400).json({
        success: false,
        message: "Payment method is required",
      });
    }

    if (!Array.isArray(shareholders) || shareholders.length === 0) {
      return res.status(400).json({
        success: false,
        message: "At least one shareholder is required",
      });
    }

    /**
     * Normalize Payment Status
     */
    const allowedStatuses = ["pending", "paid", "unpaid"];

    const finalPaymentStatus = allowedStatuses.includes(paymentStatus)
      ? paymentStatus
      : "pending";

    /**
     * Normalize Payment Method
     */
    let normalizedPaymentMethod;

    if (typeof paymentMethod === "string") {
      const method = paymentMethod.toLowerCase().trim();

      if (method === "cash") {
        normalizedPaymentMethod = 0;
      } else if (method === "online") {
        normalizedPaymentMethod = 1;
      } else {
        return res.status(400).json({
          success: false,
          message: "Invalid payment method",
        });
      }
    } else {
      normalizedPaymentMethod = Number(paymentMethod);

      if (![0, 1].includes(normalizedPaymentMethod)) {
        return res.status(400).json({
          success: false,
          message: "Invalid payment method",
        });
      }
    }

    /**
     * Calculate Total Amount
     */
    const totalAmount = shareholders.reduce((sum, shareholder) => {
      return sum + parseNumber(shareholder.price, 0);
    }, 0);

    /**
     * Create Order
     */
    const orderId = uuidv4();

    const orderPayload = {
      id: orderId,
      user_id: userId,
      admin_id: adminId,
      payment_method: normalizedPaymentMethod,
      payment_status: finalPaymentStatus,
      total_shares: shareholders.length,
      total_amt: totalAmount,
      created_at: new Date().toISOString(),
    };

    const { data: orderData, error: orderError } = await supabase
      .from("orders")
      .insert(orderPayload)
      .select()
      .single();

    if (orderError) {
      logger.error("Failed to create order", {
        userId,
        adminId,
        error: orderError.message,
      });

      return res.status(500).json({
        success: false,
        message: "Failed to create order",
      });
    }

    /**
     * Prepare Shareholders
     */
    const shareholderPayload = shareholders.map((s) => ({
      id: uuidv4(),
      order_id: orderId,
      shareholder_name: sanitizeText(s.shareholder_name || s.name),
      guardian_name: sanitizeText(s.guardian_name || s.guardianName),
      animal_id: s.animal_id || null,
      animal_type: sanitizeText(s.animal_type),
      qurbani_day: sanitizeText(s.qurbani_day),
      address: sanitizeText(s.address),
      price: parseNumber(s.price),
      payment_status: finalPaymentStatus,
      status: 0,
      created_at: new Date().toISOString(),
    }));

    /**
     * Insert Shareholders
     */
    const { error: shareholderError } = await supabase
      .from("shareholder_details")
      .insert(shareholderPayload);

    /**
     * Rollback manually if shareholder insert fails
     */
    if (shareholderError) {
      logger.error("Failed to create shareholders", {
        orderId,
        error: shareholderError.message,
      });

      // delete order
      await supabase
        .from("orders")
        .delete()
        .eq("id", orderId);

      return res.status(500).json({
        success: false,
        message: "Failed to create shareholder details",
      });
    }

    logger.info("Order placed successfully", {
      orderId,
      userId,
      adminId,
      shares: shareholders.length,
      totalAmount,
    });

    return res.status(201).json({
      success: true,
      message: "Order placed successfully",
      order: {
        ...orderData,
        payment_method_label:
          mapPaymentMethod(normalizedPaymentMethod),
        payment_status_label:
          mapPaymentStatus(finalPaymentStatus),
      },
    });
  } catch (err) {
    logger.error("Unexpected order creation error", {
      userId,
      error: err.message,
      stack: err.stack,
    });

    return res.status(500).json({
      success: false,
      message: "Something went wrong. Please try again later.",
    });
  }
});

module.exports = router;
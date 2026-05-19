const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const auth = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");
const { sendPushNotification } = require("../utils/notification_service");
const supabase = require("../config/supabase");

function badRequest(message) {
  const error = new Error(message);
  error.statusCode = 400;
  return error;
}

async function getRatingsTableConfig(connection) {
  const [columns] = await connection.query(
    `
    SELECT
      COLUMN_NAME AS column_name,
      DATA_TYPE AS data_type,
      EXTRA AS extra
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'ratings'
      AND COLUMN_NAME IN ('id', 'delivery_rating')
    `,
  );

  const idColumn = columns.find((column) => column.column_name === "id");
  const idDataType = (idColumn?.data_type || "").toLowerCase();
  const idExtra = (idColumn?.extra || "").toLowerCase();

  return {
    requiresExplicitId: Boolean(idColumn) && !idExtra.includes("auto_increment"),
    idIsNumeric: [
      "tinyint",
      "smallint",
      "mediumint",
      "int",
      "bigint",
      "decimal",
      "numeric",
    ].includes(idDataType),
    hasDeliveryRatingColumn: columns.some(
      (column) => column.column_name === "delivery_rating",
    ),
  };
}

async function getNextRatingsId(connection, ratingsTableConfig) {
  if (!ratingsTableConfig.requiresExplicitId) {
    return null;
  }

  if (ratingsTableConfig.idIsNumeric) {
    const [[row]] = await connection.query(
      `SELECT COALESCE(MAX(id), 0) + 1 AS nextId FROM ratings`,
    );
    return Number(row?.nextId || 1);
  }

  return `${Date.now()}${Math.floor(1000 + Math.random() * 9000)}`;
}

/**
 * @swagger
 * /api/ratings/{orderId}/{userId}:
 *   get:
 *     summary: Fetch admin rating info for a user
 *     description: Returns order details along with existing admin rating for an order. User can only access their own data.
 *     tags: [Ratings]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: orderId
 *         required: true
 *         description: Order ID
 *         schema:
 *           type: string
 *       - in: path
 *         name: userId
 *         required: true
 *         description: Logged-in user ID
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Rating and order info fetched successfully
 *       403:
 *         description: Unauthorized access
 *       404:
 *         description: Order not found
 *       500:
 *         description: Something went wrong. Please try again later.
 */

/**
 * GET /api/ratings/:orderId/:userId
 * Fetch admin rating + order info for a user
 */
router.get("/:orderId/:userId", auth, async (req, res) => {
  const { orderId, userId } = req.params;

  if (req.user.id !== userId) {
    logger.warn("Unauthorized ratings fetch attempt", {
      authUserId: req.user.id,
      userId,
      orderId,
    });

    return res.status(403).json({
      message: "Unauthorized",
    });
  }

  try {
    // Fetch order
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select(`
        id,
        admin_id,
        users!orders_admin_id_fkey (
          name
        )
      `)
      .eq("id", orderId)
      .eq("user_id", userId)
      .maybeSingle();

    if (orderError) {
      throw orderError;
    }

    if (!order) {
      logger.warn("Order not found for ratings fetch", {
        orderId,
        userId,
      });

      return res.status(404).json({
        message: "Order not found",
      });
    }

    // Fetch ratings
    const { data: ratings, error: ratingsError } = await supabase
      .from("ratings")
      .select("admin_id, admin_rating, feedback")
      .eq("order_id", orderId)
      .eq("user_id", userId);

    if (ratingsError) {
      throw ratingsError;
    }

    const ratingsMap = {};

    for (const r of ratings || []) {
      ratingsMap[r.admin_id] = {
        adminRating: Number(r.admin_rating),
        feedback: r.feedback,
      };
    }

    logger.info("Fetched ratings for order", {
      userId,
      orderId,
      ratingsCount: ratings?.length || 0,
    });

    return res.json({
      order: {
        order_id: order.id,
        admin_id: order.admin_id,
        admin_name: order.users?.name ?? null,
        adminId: order.admin_id,
        adminName: order.users?.name ?? null,
      },

      ratings: ratingsMap,

      submitted: (ratings?.length || 0) > 0,
    });
  } catch (err) {
    logger.error("Error fetching ratings", {
      userId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    return res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
});

/**
 * @swagger
 * /api/ratings:
 *   post:
 *     summary: Submit or update admin rating for an order
 *     description: Allows a user to submit or update rating for the admin for an order.
 *     tags: [Ratings]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - orderId
 *               - userId
 *               - ratings
 *             properties:
 *               orderId:
 *                 type: string
 *               userId:
 *                 type: string
 *               ratings:
 *                 type: array
 *                 items:
 *                   type: object
 *                   required:
 *                     - adminId
 *                     - adminRating
 *                   properties:
 *                     adminId:
 *                       type: string
 *                     adminRating:
 *                       type: number
 *                       minimum: 1
 *                       maximum: 5
 *                     feedback:
 *                       type: string
 *     responses:
 *       200:
 *         description: Ratings submitted successfully
 *       400:
 *         description: Invalid ratings data
 *       403:
 *         description: Unauthorized
 *       404:
 *         description: Order not found
 *       500:
 *         description: Something went wrong. Please try again later.
 */

/**
 * POST /api/ratings
 * Submit or update admin rating
 */
router.post("/", auth, async (req, res) => {
  const { orderId, userId, ratings } = req.body;

  if (req.user.id !== userId) {
    logger.warn("Unauthorized ratings submission attempt", {
      authUserId: req.user.id,
      userId,
      orderId,
    });

    return res.status(403).json({
      message: "Unauthorized",
    });
  }

  if (!orderId || !Array.isArray(ratings) || ratings.length === 0) {
    logger.warn("Invalid ratings payload", {
      userId,
      orderId,
    });

    return res.status(400).json({
      message: "Invalid ratings data",
    });
  }

  try {
    // Verify order exists
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("id, admin_id")
      .eq("id", orderId)
      .eq("user_id", userId)
      .maybeSingle();

    if (orderError) {
      throw orderError;
    }

    if (!order) {
      return res.status(404).json({
        message: "Order not found",
      });
    }

    const orderAdminId = order.admin_id;

    for (const r of ratings) {
      const {
        adminId,
        adminRating,
        deliveryRating,
        feedback,
      } = r;

      if (adminId && adminId !== orderAdminId) {
        throw badRequest("Invalid admin for this order");
      }

      const normalizedAdminRating = Number(adminRating);

      if (
        Number.isNaN(normalizedAdminRating) ||
        normalizedAdminRating < 1 ||
        normalizedAdminRating > 5
      ) {
        throw badRequest("Invalid admin rating value");
      }

      const normalizedDeliveryRating =
        deliveryRating == null || deliveryRating === ""
          ? normalizedAdminRating
          : Number(deliveryRating);

      if (
        Number.isNaN(normalizedDeliveryRating) ||
        normalizedDeliveryRating < 1 ||
        normalizedDeliveryRating > 5
      ) {
        throw badRequest("Invalid delivery rating value");
      }

      const trimmedFeedback = feedback?.trim() || null;

      // Check existing rating
      const { data: existingRating, error: existingError } = await supabase
        .from("ratings")
        .select("id")
        .eq("order_id", orderId)
        .eq("user_id", userId)
        .eq("admin_id", orderAdminId)
        .maybeSingle();

      if (existingError) {
        throw existingError;
      }

      if (existingRating) {
        // UPDATE
        const { error: updateError } = await supabase
          .from("ratings")
          .update({
            admin_rating: normalizedAdminRating,
            delivery_rating: normalizedDeliveryRating,
            feedback: trimmedFeedback,
          })
          .eq("id", existingRating.id);

        if (updateError) {
          throw updateError;
        }
      } else {
        // INSERT
        const { error: insertError } = await supabase
          .from("ratings")
          .insert({
            order_id: orderId,
            user_id: userId,
            admin_id: orderAdminId,
            admin_rating: normalizedAdminRating,
            delivery_rating: normalizedDeliveryRating,
            feedback: trimmedFeedback,
          });

        if (insertError) {
          throw insertError;
        }
      }
    }

    logger.info("Ratings submitted successfully", {
      userId,
      orderId,
      ratingsCount: ratings.length,
      adminId: orderAdminId,
    });

    // Push notifications
    try {
      const { data: devices, error: devicesError } = await supabase
        .from("user_devices")
        .select("subscription_id")
        .eq("user_id", orderAdminId)
        .not("subscription_id", "is", null);

      if (devicesError) {
        throw devicesError;
      }

      const subscriptionIds = (devices || [])
        .map((d) => d.subscription_id)
        .filter(Boolean);

      if (subscriptionIds.length > 0) {
        await sendPushNotification(
          subscriptionIds,
          "New Order Rating",
          `A user has left a rating for order #${orderId}.`,
          {
            type: "ORDER_RATING_RECEIVED",
            orderId: Number(orderId),
            userId,
            adminId: orderAdminId,
          },
        );
      }
    } catch (pushErr) {
      logger.error("Failed to send admin rating notification", {
        userId,
        orderId,
        adminId: orderAdminId,
        error: pushErr.message,
      });
    }

    return res.json({
      message: "Ratings submitted successfully",
    });
  } catch (err) {
    const statusCode = err.statusCode || 500;

    logger.error("Error submitting ratings", {
      userId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    return res.status(statusCode).json({
      message:
        statusCode >= 500
          ? "Something went wrong. Please try again later."
          : err.message,
    });
  }
});

module.exports = router;

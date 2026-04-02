const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const auth = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");
const { sendPushNotification } = require("../utils/notification_service");

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
    return res.status(403).json({ message: "Unauthorized" });
  }

  try {
    const [orders] = await pool.execute(
      `
      SELECT 
        o.id AS order_id,
        o.admin_id,
        a.name AS admin_name
      FROM orders o
      JOIN users a ON a.id = o.admin_id
      WHERE o.id = ? AND o.user_id = ?
      `,
      [orderId, userId],
    );

    if (!orders.length) {
      logger.warn("Order not found for ratings fetch", {
        orderId,
        userId,
      });
      return res.status(404).json({ message: "Order not found" });
    }

    const [ratings] = await pool.execute(
      `
      SELECT admin_id, admin_rating, feedback
      FROM ratings
      WHERE order_id = ? AND user_id = ?
      `,
      [orderId, userId],
    );

    const ratingsMap = {};
    ratings.forEach((r) => {
      ratingsMap[r.admin_id] = {
        adminRating: Number(r.admin_rating),
        feedback: r.feedback,
      };
    });

    logger.info("Fetched ratings for order", {
      userId,
      orderId,
      ratingsCount: ratings.length,
    });

    const order = {
      ...orders[0],
      adminId: orders[0].admin_id,
      adminName: orders[0].admin_name,
    };

    return res.json({
      order,
      ratings: ratingsMap,
      submitted: ratings.length > 0,
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
    return res.status(403).json({ message: "Unauthorized" });
  }

  if (!orderId || !Array.isArray(ratings) || ratings.length === 0) {
    logger.warn("Invalid ratings payload", {
      userId,
      orderId,
      ratingsType: typeof ratings,
      ratingsLength: Array.isArray(ratings) ? ratings.length : null,
    });
    return res.status(400).json({ message: "Invalid ratings data" });
  }

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    const [orderRows] = await connection.execute(
      `
      SELECT id, admin_id
      FROM orders
      WHERE id = ? AND user_id = ?
      `,
      [orderId, userId],
    );

    if (!orderRows.length) {
      logger.warn("Ratings submission failed - order not found", {
        userId,
        orderId,
      });
      await connection.rollback();
      return res.status(404).json({ message: "Order not found" });
    }

    const orderAdminId = orderRows[0].admin_id;
    const ratingsTableConfig = await getRatingsTableConfig(connection);

    for (const r of ratings) {
      const { adminId, adminRating, feedback } = r;

      if (adminId && adminId !== orderAdminId) {
        logger.warn("Admin ID mismatch in rating payload", {
          userId,
          orderId,
          payloadAdminId: adminId,
          actualAdminId: orderAdminId,
        });
        throw badRequest("Invalid admin for this order");
      }

      const normalizedAdminRating = Number(adminRating);

      if (
        Number.isNaN(normalizedAdminRating) ||
        normalizedAdminRating < 1 ||
        normalizedAdminRating > 5
      ) {
        logger.warn("Invalid admin rating value detected", {
          userId,
          orderId,
          adminId: orderAdminId,
          adminRating,
        });
        throw badRequest("Invalid admin rating value");
      }

      const trimmedFeedback = feedback?.trim() || null;

      let normalizedDeliveryRating = null;
      if (ratingsTableConfig.hasDeliveryRatingColumn) {
        const deliveryRatingInput = r.deliveryRating;
        normalizedDeliveryRating =
          deliveryRatingInput == null || deliveryRatingInput === ""
            ? normalizedAdminRating
            : Number(deliveryRatingInput);

        if (
          Number.isNaN(normalizedDeliveryRating) ||
          normalizedDeliveryRating < 1 ||
          normalizedDeliveryRating > 5
        ) {
          logger.warn("Invalid delivery rating value detected", {
            userId,
            orderId,
            adminId: orderAdminId,
            deliveryRating: deliveryRatingInput,
          });
          throw badRequest("Invalid delivery rating value");
        }
      }

      const [existingRows] = await connection.execute(
        `
        SELECT id
        FROM ratings
        WHERE order_id = ? AND user_id = ? AND admin_id = ?
        LIMIT 1
        `,
        [orderId, userId, orderAdminId],
      );

      if (existingRows.length) {
        const updateColumns = ["admin_rating = ?", "feedback = ?"];
        const updateValues = [normalizedAdminRating, trimmedFeedback];

        if (ratingsTableConfig.hasDeliveryRatingColumn) {
          updateColumns.splice(1, 0, "delivery_rating = ?");
          updateValues.splice(1, 0, normalizedDeliveryRating);
        }

        updateValues.push(existingRows[0].id);

        await connection.execute(
          `UPDATE ratings SET ${updateColumns.join(", ")} WHERE id = ?`,
          updateValues,
        );
        continue;
      }

      const insertColumns = ["order_id", "user_id", "admin_id", "admin_rating"];
      const insertValues = [orderId, userId, orderAdminId, normalizedAdminRating];

      if (ratingsTableConfig.requiresExplicitId) {
        insertColumns.unshift("id");
        insertValues.unshift(
          await getNextRatingsId(connection, ratingsTableConfig),
        );
      }

      if (ratingsTableConfig.hasDeliveryRatingColumn) {
        insertColumns.push("delivery_rating");
        insertValues.push(normalizedDeliveryRating);
      }

      insertColumns.push("feedback");
      insertValues.push(trimmedFeedback);

      await connection.execute(
        `
        INSERT INTO ratings (${insertColumns.join(", ")})
        VALUES (${insertColumns.map(() => "?").join(", ")})
        `,
        insertValues,
      );
    }

    await connection.commit();

    logger.info("Ratings submitted successfully", {
      userId,
      orderId,
      ratingsCount: ratings.length,
      adminId: orderAdminId,
    });

    try {
      const [devices] = await pool.execute(
        `
        SELECT subscription_id
        FROM user_devices
        WHERE user_id = ? AND subscription_id IS NOT NULL
        `,
        [orderAdminId],
      );

      const subscriptionIds = devices
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

        logger.info("Admin notified about new order rating", {
          userId,
          orderId,
          adminId: orderAdminId,
          devicesCount: subscriptionIds.length,
        });
      } else {
        logger.warn("No admin devices found for rating notification", {
          userId,
          orderId,
          adminId: orderAdminId,
        });
      }
    } catch (pushErr) {
      logger.error("Failed to send admin rating notification", {
        userId,
        orderId,
        adminId: orderAdminId,
        error: pushErr.message,
        stack: pushErr.stack,
      });
    }

    return res.json({ message: "Ratings submitted successfully" });
  } catch (err) {
    await connection.rollback();
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
  } finally {
    connection.release();
  }
});

module.exports = router;

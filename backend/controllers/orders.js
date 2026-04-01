/**
 * Orders Controller
 *
 * This module handles all order-related API endpoints for the application.
 * It includes routes for users to view, create, and manage their orders,
 * as well as admin-specific routes for managing orders.
 *
 * Key Features:
 * - User order management (view, create, cancel)
 * - Admin order management (view, update, mark as paid)
 * - Order scheduling and delivery assignment
 * - Ratings and feedback system
 * - Special requests handling
 *
 * Dependencies:
 * - express: Web framework for routing
 * - uuid: For generating unique order IDs
 * - mysql2/promise: Database connection pool
 * - authMiddleware: Authentication middleware
 * - logger: Logging utility for audit trails
 */

const express = require("express");
const router = express.Router();
const { v4: uuidv4 } = require("uuid");
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");
const { sendPushNotification } = require("../utils/notification_service");

/**
 * Sanitizes input text by converting it to a string and removing any leading/trailing whitespace
 * @param {any} value - The input value to be sanitized
 * @returns {string} The sanitized string, or empty string if input is null/undefined
 */
const sanitizeText = (value) => {
  if (value == null) { // Check if value is null or undefined
    return ""; // Return empty string for null/undefined values
  }

  return String(value).trim();
};

const normalizeIncomingAddress = (address) => {
  if (typeof address === "string") {
    const addressLine = sanitizeText(address);

    return addressLine
      ? {
          country: null,
          country_iso: null,
          state: null,
          city: null,
          postal_code: null,
          address_line: addressLine,
        }
      : null;
  }

  if (!address || typeof address !== "object") {
    return null;
  }

  const normalized = {
    country: sanitizeText(address.country) || null,
    country_iso:
      sanitizeText(address.country_iso || address.countryISO).toUpperCase() ||
      null,
    state: sanitizeText(address.state) || null,
    city: sanitizeText(address.city) || null,
    postal_code:
      sanitizeText(address.postal_code || address.postalCode) || null,
    address_line:
      sanitizeText(
        address.address_line || address.addressLine || address.address,
      ) || null,
  };

  return normalized.address_line ? normalized : null;
};

const getTableIdConfig = async (connection, tableName) => {
  const [columns] = await connection.query(
    `
    SELECT
      COLUMN_NAME AS column_name,
      DATA_TYPE AS data_type,
      EXTRA AS extra
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = ?
      AND COLUMN_NAME = 'id'
    `,
    [tableName],
  );

  const idColumn = columns[0];
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
  };
};

const getShareholderTableConfig = async (connection) => {
  const idConfig = await getTableIdConfig(connection, "shareholder_details");
  const [columns] = await connection.query(
    `
    SELECT COLUMN_NAME AS column_name
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'shareholder_details'
      AND COLUMN_NAME = 'payment_status'
    `,
  );

  return {
    ...idConfig,
    hasPaymentStatus: columns.length > 0,
  };
};

const buildOrderInsertPayload = async (
  connection,
  userId,
  adminId,
  normalizedPaymentMethod,
  shareholderCount,
  totalAmount,
) => {
  const tableConfig = await getTableIdConfig(connection, "orders");
  const columns = [];
  const values = [];

  let orderId = null;
  if (tableConfig.requiresExplicitId) {
    columns.push("id");

    if (tableConfig.idIsNumeric) {
      const [[row]] = await connection.query(
        `SELECT COALESCE(MAX(id), 0) AS maxId FROM orders`,
      );
      orderId = Number(row?.maxId || 0) + 1;
    } else {
      orderId = uuidv4();
    }

    values.push(orderId);
  }

  columns.push("user_id", "admin_id", "payment_method", "total_shares", "total_amt");
  values.push(
    userId,
    adminId,
    normalizedPaymentMethod,
    shareholderCount,
    totalAmount,
  );

  return { columns, values, orderId };
};

const buildShareholderInsertPayload = async (
  connection,
  orderId,
  shareholders,
  normalizedPaymentStatus,
) => {
  const tableConfig = await getShareholderTableConfig(connection);
  const columns = [];

  if (tableConfig.requiresExplicitId) {
    columns.push("id");
  }

  columns.push(
    "order_id",
    "shareholder_name",
    "guardian_name",
    "qurbani_day",
    "price",
    "address",
  );

  if (tableConfig.hasPaymentStatus) {
    columns.push("payment_status");
  }

  let nextNumericId = null;
  if (tableConfig.requiresExplicitId && tableConfig.idIsNumeric) {
    const [[row]] = await connection.query(
      `SELECT COALESCE(MAX(id), 0) AS maxId FROM shareholder_details`,
    );
    nextNumericId = Number(row?.maxId || 0) + 1;
  }

  const rows = shareholders.map((shareholder) => {
    const normalizedAddress = normalizeIncomingAddress(shareholder.address);

    if (!normalizedAddress?.address_line) {
      throw new Error("Address is required for each shareholder");
    }

    const values = [];

    if (tableConfig.requiresExplicitId) {
      values.push(tableConfig.idIsNumeric ? nextNumericId++ : uuidv4());
    }

    values.push(
      orderId,
      sanitizeText(shareholder.name),
      sanitizeText(shareholder.guardianName),
      sanitizeText(shareholder.qurbaniDay),
      Number(shareholder.price || 0),
      JSON.stringify(normalizedAddress),
    );

    if (tableConfig.hasPaymentStatus) {
      values.push(normalizedPaymentStatus);
    }

    return values;
  });

  return { columns, rows };
};

const parseNumber = (value, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const applyComputedOrderStatuses = (order, shareholders, hasPaymentStatus = true) => {
  if (!shareholders.length) {
    order.processing_status = "Not started";
    order.delivery_status = "Pending";
    order.payment_status = 2;
    order.payment_status_label = "Pending";
    return;
  }

  const statuses = shareholders.map((shareholder) => parseNumber(shareholder.status));
  const maxStatus = Math.max(...statuses);

  if (maxStatus === 6) {
    order.processing_status = "Cancelled";
    order.delivery_status = "Cancelled";
  } else if (maxStatus === 5) {
    order.processing_status = "Delivered";
    order.delivery_status = "Delivered";
  } else if (maxStatus === 4) {
    order.processing_status = "Sent for delivery";
    order.delivery_status = "Sent for delivery";
  } else if (maxStatus === 3) {
    order.processing_status = "Meat Packaged";
    order.delivery_status = "Pending";
  } else if (maxStatus === 2) {
    order.processing_status = "Processing";
    order.delivery_status = "Pending";
  } else if (maxStatus === 1) {
    order.processing_status = "Qurbani Started";
    order.delivery_status = "Pending";
  } else {
    order.processing_status = "Not started";
    order.delivery_status = "Pending";
  }

  const paymentStatuses = hasPaymentStatus
    ? shareholders.map((shareholder) => parseNumber(shareholder.payment_status, 2))
    : [2];

  if (paymentStatuses.every((status) => status === 0)) {
    order.payment_status = 0;
    order.payment_status_label = "Paid";
  } else if (paymentStatuses.every((status) => status === 1)) {
    order.payment_status = 1;
    order.payment_status_label = "Unpaid";
  } else {
    order.payment_status = 2;
    order.payment_status_label = "Pending";
  }
};

const buildOrderAnimalsAndShareholders = async (orderId, shareholders) => {
  const animalIds = [
    ...new Set(
      shareholders
        .map((shareholder) => parseNumber(shareholder.animal_id, 0))
        .filter((animalId) => animalId > 0),
    ),
  ];

  if (!animalIds.length) {
    return {
      animals: [],
      shareholders,
    };
  }

  const placeholders = animalIds.map(() => "?").join(", ");
  const [animals] = await pool.query(
    `
    SELECT *
    FROM animals
    WHERE id IN (${placeholders})
    `,
    animalIds,
  );
  const [animalDetailsRows] = await pool.query(
    `
    SELECT *
    FROM animal_details
    WHERE animal_id IN (${placeholders})
    `,
    animalIds,
  );

  const animalsById = new Map(
    animals.map((animal) => [parseNumber(animal.id, 0), animal]),
  );
  const detailsByAnimalId = new Map();

  for (const detail of animalDetailsRows) {
    const animalId = parseNumber(detail.animal_id, 0);
    if (!animalId) {
      continue;
    }

    const existing = detailsByAnimalId.get(animalId);
    const belongsToOrder = String(detail.order_id ?? "") === String(orderId);

    if (!existing || belongsToOrder) {
      detailsByAnimalId.set(animalId, detail);
    }
  }

  const enrichedShareholders = shareholders.map((shareholder) => {
    const animalId = parseNumber(shareholder.animal_id, 0);
    const animal = animalsById.get(animalId);
    const animalDetail = detailsByAnimalId.get(animalId);

    return {
      ...shareholder,
      animal_type: shareholder.animal_type ?? animal?.animal_type ?? null,
      qurbani_day: animal?.qurbani_day ?? shareholder.qurbani_day ?? null,
      qurbani_datetime:
        animalDetail?.qurbani_datetime ??
        animal?.qurbani_datetime ??
        shareholder.qurbani_datetime ??
        null,
      photo_urls: animalDetail?.photo_urls ?? shareholder.photo_urls ?? null,
      barcode: animalDetail?.barcode ?? shareholder.barcode ?? null,
    };
  });

  const enrichedAnimals = animalIds
    .map((animalId) => {
      const animal = animalsById.get(animalId);
      if (!animal) {
        return null;
      }

      const animalDetail = detailsByAnimalId.get(animalId);

      return {
        ...animal,
        barcode: animalDetail?.barcode ?? null,
        photo_urls: animalDetail?.photo_urls ?? null,
        qurbani_datetime:
          animalDetail?.qurbani_datetime ?? animal.qurbani_datetime ?? null,
      };
    })
    .filter(Boolean);

  return {
    animals: enrichedAnimals,
    shareholders: enrichedShareholders,
  };
};

const formatAdminShareholders = (shareholders, hasPaymentStatus = true) =>
  shareholders.map((shareholder) => ({
    id: shareholder.id,
    shareholder_name: shareholder.shareholder_name,
    guardian_name: shareholder.guardian_name,
    animal_id: shareholder.animal_id ?? null,
    animal_type: shareholder.animal_type ?? null,
    share_number: shareholder.share_number ?? null,
    qurbani_datetime: shareholder.qurbani_datetime ?? null,
    address: shareholder.address ?? null,
    price: shareholder.price ?? 0,
    qurbani_day: shareholder.qurbani_day ?? null,
    status: parseNumber(shareholder.status, 0),
    status_label: mapShareholderStatus(shareholder.status),
    payment_status: hasPaymentStatus
      ? parseNumber(shareholder.payment_status, 2)
      : 2,
    payment_status_label: hasPaymentStatus
      ? mapPaymentStatus(shareholder.payment_status)
      : "Pending",
    photo_urls: shareholder.photo_urls ?? null,
    barcode: shareholder.barcode ?? null,
  }));

const buildAdminOrderResponse = (
  order,
  formattedShareholders,
  hasPaymentStatus = true,
) => {
  const rawOrderStatus = parseNumber(order.order_status ?? order.status, 0);
  const response = {
    orderId: order.id,
    userId: order.user_id,
    adminId: order.admin_id,
    user_name: order.user_name ?? null,
    email: order.user_email ?? order.email ?? null,
    contact_no: order.contact_no ?? null,
    address: order.address ?? null,
    admin_name: order.admin_name ?? null,
    total_amt: order.total_amt ?? 0,
    totalShares: order.total_shares,
    total_shares: order.total_shares,
    paymentMethod: order.payment_method,
    payment_method: order.payment_method,
    paymentMethodLabel: mapPaymentMethod(order.payment_method),
    payment_method_label: mapPaymentMethod(order.payment_method),
    orderStatus: rawOrderStatus,
    order_status: rawOrderStatus,
    orderStatusLabel: mapOrderStatus(rawOrderStatus),
    order_status_label: mapOrderStatus(rawOrderStatus),
    createdAt: order.created_at,
    created_at: order.created_at,
    cod_deadline: order.cod_deadline ?? null,
    shareholders: formattedShareholders,
  };

  applyComputedOrderStatuses(response, formattedShareholders, hasPaymentStatus);

  return response;
};


router.get("/my", authMiddleware, async (req, res) => {
  const userId = req.user.id;

  try {
    const shareholderTableConfig = await getShareholderTableConfig(pool);
    const [orders] = await pool.execute(
      `SELECT 
          o.id,
          o.user_id,
          o.admin_id,
          o.payment_method,
          o.total_shares,
          o.status,
          o.created_at,
          u.name AS admin_name,
          u.email AS admin_email,
          aps.cod_deadline
       FROM orders o
       JOIN users u 
         ON o.admin_id = u.id
       LEFT JOIN admin_payment_settings aps
         ON aps.admin_id = o.admin_id
       WHERE o.user_id = ?
       ORDER BY o.created_at DESC`,
      [userId]
    );

    for (const order of orders) {
      const [shareholders] = await pool.execute(
        `SELECT *
         FROM shareholder_details
         WHERE order_id = ?`,
        [order.id]
      );

      order.shareholders = shareholders;
      applyComputedOrderStatuses(
        order,
        shareholders,
        shareholderTableConfig.hasPaymentStatus,
      );
    }

    res.json({ orders });
  } catch (err) {
    logger.error("Failed to fetch user orders", {
      userId,
      error: err.message,
      stack: err.stack,
    });
    res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
});




router.post("/:orderId/assign-animal", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { animalId } = req.body;

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    // Get order to fetch user_id
    const [orderRows] = await connection.query(
      `SELECT user_id FROM orders WHERE id = ?`,
      [orderId],
    );

    if (orderRows.length === 0) {
      await connection.rollback();
      return res.status(404).json({ message: "Order not found" });
    }

    const userId = orderRows[0].user_id;

    // Assign share (animal_details)
    await connection.query(
      `UPDATE animal_details 
       SET order_id = ?
       WHERE animal_id = ? AND order_id IS NULL
       LIMIT 1`,
      [orderId, animalId],
    );

    // Count assigned shares
    const [assignedRows] = await connection.query(
      `SELECT COUNT(*) as totalAssigned
       FROM animal_details
       WHERE animal_id = ? AND order_id IS NOT NULL`,
      [animalId],
    );

    const totalAssigned = assignedRows[0].totalAssigned;

    // Get total shares
    const [animalRows] = await connection.query(
      `SELECT shares FROM animals WHERE id = ?`,
      [animalId],
    );

    const totalShares = animalRows[0].shares;

    // If fully booked → mark sold
    if (totalAssigned >= totalShares) {
      await connection.query(
        `UPDATE animals 
         SET status = 'sold'
         WHERE id = ?`,
        [animalId],
      );
    }

    await connection.commit();

    // SEND PUSH TO USER (after commit)
    try {
      const [devices] = await connection.query(
        `SELECT subscription_id
         FROM user_devices
         WHERE user_id = ?`,
        [userId],
      );

      const subscriptionIds = devices.map((d) => d.subscription_id);

      if (subscriptionIds.length > 0) {
        await sendPushNotification(
          subscriptionIds,
          "🐄 Animal Assigned",
          "Your Qurbani animal has been successfully assigned.",
          {
            type: "ANIMAL_ASSIGNED",
            orderId: orderId,
          },
        );
      }
    } catch (pushErr) {
      logger.error("Animal assignment push failed", {
        orderId,
        error: pushErr.message,
      });
    }

    res.json({ message: "Animal assigned successfully" });
  } catch (error) {
    await connection.rollback();

    logger.error("Animal assignment failed", {
      orderId,
      animalId,
      error: error.message,
      stack: error.stack,
    });

    res.status(500).json({ message: "Failed to assign animal" });
  } finally {
    connection.release();
  }
});




router.post("/", authMiddleware, async (req, res) => {
  const userId = req.user.id;
  const { adminId, paymentMethod, shareholders, totalAmount, paymentStatus } =
    req.body;

  console.log(req.body);

  if (
    !adminId ||
    paymentMethod === undefined ||
    !Array.isArray(shareholders) ||
    shareholders.length === 0
  ) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  const connection = await pool.getConnection();

  try {
    await connection.beginTransaction();

    // Normalize payment method
    let normalizedPaymentMethod;
    if (typeof paymentMethod === "string") {
      const method = paymentMethod.toLowerCase().trim();
      if (method === "cash") {
        normalizedPaymentMethod = 0;
      } else if (method === "online") {
        normalizedPaymentMethod = 1;
      } else {
        throw new Error("Invalid payment method");
      }
    } else {
      normalizedPaymentMethod = Number(paymentMethod);
      if (![0, 1].includes(normalizedPaymentMethod)) {
        throw new Error("Invalid payment method");
      }
    }

    // Normalize payment status
    let normalizedPaymentStatus;
    if (typeof paymentStatus === "string") {
      const status = paymentStatus.toLowerCase().trim();
      if (status === "paid") {
        normalizedPaymentStatus = 0;
      } else if (status === "unpaid") {
        normalizedPaymentStatus = 1;
      } else if (status === "pending") {
        normalizedPaymentStatus = 2;
      } else {
        normalizedPaymentStatus = 2;
      }
    } else if (paymentStatus === undefined || paymentStatus === null) {
      normalizedPaymentStatus = 2;
    } else {
      normalizedPaymentStatus = Number(paymentStatus);
      if (![0, 1, 2].includes(normalizedPaymentStatus)) {
        normalizedPaymentStatus = 2;
      }
    }

    const orderInsert = await buildOrderInsertPayload(
      connection,
      userId,
      adminId,
      normalizedPaymentMethod,
      shareholders.length,
      totalAmount,
    );

    const [orderResult] = await connection.execute(
      `
      INSERT INTO orders
        (${orderInsert.columns.join(", ")})
      VALUES (${orderInsert.columns.map(() => "?").join(", ")})
      `,
      orderInsert.values,
    );

    const orderId = orderInsert.orderId ?? orderResult.insertId;

    const shareholderInsert = await buildShareholderInsertPayload(
      connection,
      orderId,
      shareholders,
      normalizedPaymentStatus,
    );

    await connection.query(
      `
      INSERT INTO shareholder_details
        (${shareholderInsert.columns.join(", ")})
      VALUES ?
      `,
      [shareholderInsert.rows],
    );

    await connection.commit();

    // Send push AFTER commit
    try {
      const [devices] = await connection.query(
        `
        SELECT subscription_id
        FROM user_devices
        WHERE user_id = ?
        `,
        [adminId]
      );

      const subscriptionIds = devices
        .map((d) => d.subscription_id)
        .filter(Boolean);

      if (subscriptionIds.length > 0) {
        await sendPushNotification(
          subscriptionIds,
          "New Qurbani Order",
          `New order #${orderId} has been placed.`,
          { type: "NEW_ORDER", orderId }
        );
      }
    } catch (pushErr) {
      logger.error("Push notification failed", {
        orderId,
        status: pushErr.response?.status,
        data: pushErr.response?.data,
        message: pushErr.message,
      });
    }

    res.status(201).json({
      message: "Order placed successfully",
      orderId,
    });
  } catch (err) {
    await connection.rollback();

    logger.error("Order creation failed", {
      userId,
      adminId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: err.message || "Something went wrong" });
  } finally {
    connection.release();
  }
});

router.get("/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    const shareholderTableConfig = await getShareholderTableConfig(pool);
    const [orders] = await pool.execute(
      `
      SELECT 
        o.*,
        u.name AS admin_name,
        u.address AS admin_address,
        u.phone AS admin_phone
      FROM orders o
      JOIN users u ON o.admin_id = u.id
      WHERE o.id = ? AND o.user_id = ?
      `,
      [orderId, userId]
    );

    if (!orders.length) {
      return res.status(404).json({ message: "Order not found" });
    }

    const order = orders[0];

    const [shareholders] = await pool.execute(
      `
      SELECT *
      FROM shareholder_details
      WHERE order_id = ?
      `,
      [orderId]
    );
    const orderDetails = await buildOrderAnimalsAndShareholders(
      orderId,
      shareholders,
    );

    order.shareholders = orderDetails.shareholders;
    order.animals = orderDetails.animals;

    applyComputedOrderStatuses(
      order,
      orderDetails.shareholders,
      shareholderTableConfig.hasPaymentStatus,
    );


    res.json({
      order,
    });
  } catch (err) {
    logger.error("Failed to fetch order details", {
      orderId,
      userId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Something went wrong." });
  }
});



router.put("/animal-details/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { meat_weight, body_parts_description } = req.body;

  try {
    // Fetch all shareholders for this order
    const [shareholders] = await pool.query(
      `SELECT id FROM order_shareholders WHERE order_id = ?`,
      [orderId],
    );

    if (!shareholders.length) {
      return res.status(404).json({
        message: "No shareholders found for this order",
      });
    }

    // Update animal_details for EACH shareholder
    for (const s of shareholders) {
      await pool.execute(
        `UPDATE animal_details
         SET meat_weight = ?, body_parts_description = ?
         WHERE order_id = ? AND shareholder_id = ?`,
        [meat_weight, body_parts_description, orderId, s.id],
      );
    }

    // Mark order completed
    await pool.execute(
      `UPDATE orders SET processing_status = 'completed' WHERE id = ?`,
      [orderId],
    );

    res.json({ message: "Meat details saved successfully" });
  } catch (err) {
    logger.error("Meat details update failed", err);
    res.status(500).json({ message: "Failed to save meat details" });
  }
});


function mapShareholderStatus(status) {
  switch (Number(status)) {
    case 0:
      return "Not started";
    case 1:
      return "Qurbani Started";
    case 2:
      return "Processing";
    case 3:
      return "Meat Packaged";
    case 4:
      return "Sent for delivery";
    case 5:
      return "Delivered";
    case 6:
      return "Cancelled";
    default:
      return "Unknown";
  }
}

function mapPaymentStatus(status) {
  switch (Number(status)) {
    case 0:
      return "Paid";
    case 1:
      return "Unpaid";
    case 2:
      return "Pending";
    default:
      return "Unknown";
  }
}

function mapOrderStatus(status) {
  switch (Number(status)) {
    case 0:
      return "Active";
    case 1:
      return "Completed";
    case 2:
      return "Cancelled";
    default:
      return "Unknown";
  }
}

function mapPaymentMethod(method) {
  switch (Number(method)) {
    case 0:
      return "Cash";
    case 1:
      return "Online";
    default:
      return "Unknown";
  }
}


router.get("/admin/my", authMiddleware, async (req, res) => {
  const adminId = req.user.id;

  logger.info("Admin fetching own orders", { adminId });

  try {
    const shareholderTableConfig = await getShareholderTableConfig(pool);
    const [orders] = await pool.execute(
      `
      SELECT
        o.id,
        o.user_id,
        o.admin_id,
        o.payment_method,
        o.total_shares,
        o.total_amt,
        o.status AS order_status,
        o.created_at,
        aps.cod_deadline
      FROM orders o
      LEFT JOIN admin_payment_settings aps
        ON aps.admin_id = o.admin_id
      WHERE o.admin_id = ?
      ORDER BY o.created_at DESC
      `,
      [adminId]
    );

    if (!orders.length) {
      return res.json({ orders: [] });
    }

    const orderIds = orders.map((order) => order.id);
    const placeholders = orderIds.map(() => "?").join(", ");
    const [shareholders] = await pool.query(
      `
      SELECT *
      FROM shareholder_details
      WHERE order_id IN (${placeholders})
      ORDER BY order_id DESC, id ASC
      `,
      orderIds,
    );

    const shareholdersByOrderId = new Map();
    for (const shareholder of shareholders) {
      const key = String(shareholder.order_id);
      const existing = shareholdersByOrderId.get(key) || [];
      existing.push(shareholder);
      shareholdersByOrderId.set(key, existing);
    }

    const formattedOrders = orders.map((order) => {
      const rawShareholders = shareholdersByOrderId.get(String(order.id)) || [];
      const formattedShareholders = formatAdminShareholders(
        rawShareholders,
        shareholderTableConfig.hasPaymentStatus,
      );

      return buildAdminOrderResponse(
        order,
        formattedShareholders,
        shareholderTableConfig.hasPaymentStatus,
      );
    });

    logger.info("Admin orders fetched", {
      adminId,
      orderCount: formattedOrders.length,
    });

    res.json({ orders: formattedOrders });
  } catch (err) {
    logger.error("Failed to fetch admin orders", {
      adminId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
});


router.post("/requests", authMiddleware, async (req, res) => {
  const { orderId, userId, title, description } = req.body;
  const authUserId = req.user.id;

  if (authUserId !== userId) {
    return res.status(403).json({ message: "Unauthorized" });
  }

  if (!orderId || !title || !description) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    // Insert request
    await pool.execute(
      `INSERT INTO requests (order_id, user_id, title, description, status)
       VALUES (?, ?, ?, ?, 'Pending')`,
      [orderId, userId, title, description],
    );

    // ============================
    // SEND PUSH TO ADMIN
    // ============================
    try {
      // Get admin_id from order
      const [orderRows] = await pool.execute(
        `SELECT admin_id FROM orders WHERE id = ?`,
        [orderId],
      );

      if (orderRows.length) {
        const adminId = orderRows[0].admin_id;

        // Get admin devices
        const [devices] = await pool.execute(
          `SELECT subscription_id FROM user_devices WHERE user_id = ?`,
          [adminId],
        );

        const subscriptionIds = devices.map((d) => d.subscription_id);
        const shortOrderId = orderId.toString().substring(0, 6);
        if (subscriptionIds.length > 0) {
          await sendPushNotification(
            subscriptionIds,
            "New Special Request",
            `A new request has been submitted for Order #${shortOrderId}.`,
            {
              type: "NEW_SPECIAL_REQUEST",
              orderId,
              userId,
              title,
            },
          );
        }
      }
    } catch (pushErr) {
      logger.error("Admin notification failed", {
        orderId,
        error: pushErr.message,
      });
    }

    res.status(201).json({ message: "Request submitted successfully" });
  } catch (err) {
    logger.error("Failed to submit request", {
      orderId,
      userId,
      error: err.message,
      stack: err.stack,
    });

    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

router.get("/requests/:orderId/:userId", authMiddleware, async (req, res) => {
  const { orderId, userId } = req.params;
  const authUserId = req.user.id;

  if (authUserId !== userId) {
    return res.status(403).json({ message: "Unauthorized" });
  }

  try {
    const [requests] = await pool.execute(
      `SELECT id, title, description, status, created_at
       FROM requests
       WHERE order_id = ? AND user_id = ?`,
      [orderId, userId],
    );

    res.json({ requests });
  } catch (err) {
    logger.error("Failed to fetch user requests", {
      orderId,
      userId,
      error: err.message,
      stack: err.stack,
    });
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

function mapShareholderStatus(status) {
  switch (Number(status)) {
    case 0:
      return "Not started";
    case 1:
      return "Qurbani Started";
    case 2:
      return "Processing";
    case 3:
      return "Meat Packaged";
    case 4:
      return "Sent for delivery";
    case 5:
      return "Delivered";
    case 6:
      return "Cancelled";
    default:
      return "Unknown";
  }
}

function mapPaymentStatus(status) {
  switch (Number(status)) {
    case 0:
      return "Paid";
    case 1:
      return "Unpaid";
    case 2:
      return "Pending";
    default:
      return "Unknown";
  }
}

function mapPaymentMethod(method) {
  switch (Number(method)) {
    case 0:
      return "Cash";
    case 1:
      return "Online";
    default:
      return "Unknown";
  }
}

// orders/admin/:orderId
router.get("/admin/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const adminId = req.user.id;

  try {
    const shareholderTableConfig = await getShareholderTableConfig(pool);
    const [orders] = await pool.execute(
      `
      SELECT 
        o.id,
        o.user_id,
        o.admin_id,
        o.payment_method,
        o.total_shares,
        o.total_amt,
        o.status AS order_status,
        o.created_at,
        u.name AS user_name,
        u.email AS user_email,
        u.phone AS contact_no,
        u.address,
        a.name AS admin_name,
        aps.cod_deadline
      FROM orders o
      JOIN users u ON o.user_id = u.id
      JOIN users a ON o.admin_id = a.id
      LEFT JOIN admin_payment_settings aps
        ON aps.admin_id = o.admin_id
      WHERE o.id = ? AND o.admin_id = ?
      `,
      [orderId, adminId],
    );

    if (!orders.length) {
      return res
        .status(404)
        .json({ message: "Order not found or not authorized" });
    }

    const order = orders[0];

    const [shareholders] = await pool.execute(
      `
      SELECT *
      FROM shareholder_details
      WHERE order_id = ?
      `,
      [order.id],
    );
    const orderDetails = await buildOrderAnimalsAndShareholders(
      order.id,
      shareholders,
    );
    const formattedShareholders = formatAdminShareholders(
      orderDetails.shareholders,
      shareholderTableConfig.hasPaymentStatus,
    );
    const orderWithDetails = buildAdminOrderResponse(
      order,
      formattedShareholders,
      shareholderTableConfig.hasPaymentStatus,
    );
    orderWithDetails.animals = orderDetails.animals;

    logger.info("Admin order details fetched", {
      adminId,
      orderId,
      shareholderCount: formattedShareholders.length,
      processing_status: orderWithDetails.processing_status,
      payment_status: orderWithDetails.payment_status,
    });

    res.json({ order: orderWithDetails });
  } catch (err) {
    logger.error("Failed to fetch admin order details", {
      adminId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    res.status(500).json({
      message: "Something went wrong. Please try again later.",
    });
  }
});


router.put("/admin/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { processingStatus, deliveryStatus, deliveryPersonId } = req.body;
  const adminId = req.user.id;

  if (!processingStatus || !deliveryStatus) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    // Check if order belongs to admin
    const [orders] = await pool.execute(
      `SELECT id FROM orders WHERE id = ? AND admin_id = ?`,
      [orderId, adminId],
    );
    if (orders.length === 0) {
      return res
        .status(404)
        .json({ message: "Order not found or not authorized" });
    }

    // Update order
    await pool.execute(
      `UPDATE orders SET status = ?, delivery_status = ?, delivery_person_id = ? WHERE id = ?`,
      [processingStatus, deliveryStatus, deliveryPersonId || null, orderId],
    );

    res.json({ message: "Order updated successfully" });
  } catch (err) {
    logger.error("Failed to update admin order", {
      adminId,
      orderId,
      error: err.message,
      stack: err.stack,
    });
    res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

router.put("/:orderId/cancel", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    // 1) Verify order exists and belongs to logged-in user
    const [orders] = await pool.execute(
      `SELECT id, user_id, created_at, status
       FROM orders
       WHERE id = ? AND user_id = ?`,
      [orderId, userId]
    );

    if (!orders.length) {
      logger.warn("Order cancellation attempt on missing or unauthorized order", {
        userId,
        orderId,
        reason: "Order not found or does not belong to user",
      });

      return res.status(404).json({ message: "Order not found" });
    }

    const order = orders[0];

    // 2) Get shareholder statuses for this order
    const [shareholders] = await pool.execute(
      `SELECT status
       FROM shareholder_details
       WHERE order_id = ?`,
      [orderId]
    );

    const statuses = shareholders.map((s) => Number(s.status));
    const isDelivered = statuses.some((s) => s === 5); // 5 = Delivered
    const isCancelled = statuses.some((s) => s === 6) || Number(order.status) === 2; // 6 = Cancelled, order.status 2 = cancelled

    // 3) Check 24-hour cancellation rule
    const timeSinceOrder = Date.now() - new Date(order.created_at).getTime();
    const within24Hours = timeSinceOrder < 24 * 60 * 60 * 1000;
    const orderAgeHours = Math.floor(timeSinceOrder / (1000 * 60 * 60));
    const orderAgeMinutes = Math.floor(timeSinceOrder / (1000 * 60));

    const canCancel = within24Hours && !isDelivered && !isCancelled;

    if (!canCancel) {
      logger.warn("Invalid order cancellation attempt - business rules violation", {
        userId,
        orderId,
        orderStatus: order.status,
        shareholderStatuses: statuses,
        within24Hours,
        orderAgeHours,
        isDelivered,
        isCancelled,
        reason: !within24Hours
          ? "Outside 24-hour window"
          : isDelivered
            ? "Order already delivered"
            : "Order already cancelled",
      });

      return res.status(400).json({ message: "Cannot cancel this order" });
    }

    // 4) Cancel order and all associated shareholders
    await pool.execute(
      `UPDATE orders
       SET status = 2
       WHERE id = ? AND user_id = ?`,
      [orderId, userId]
    );

    await pool.execute(
      `UPDATE shareholder_details
       SET status = 6
       WHERE order_id = ?`,
      [orderId]
    );

    logger.info("Order successfully cancelled by user", {
      userId,
      orderId,
      orderAgeMinutes,
      cancellationType: "user_initiated",
      previousOrderStatus: order.status,
      previousShareholderStatuses: statuses,
    });

    // 5) Send push notification to user's registered devices
    try {
      const [devices] = await pool.execute(
        `SELECT subscription_id
         FROM user_devices
         WHERE user_id = ? AND subscription_id IS NOT NULL`,
        [userId]
      );

      const subscriptionIds = devices
        .map((d) => d.subscription_id)
        .filter(Boolean);

      if (subscriptionIds.length > 0) {
        const title = `Order #${orderId} Cancelled`;
        const message = `Your Qurbani order #${orderId} has been cancelled successfully.`;

        await sendPushNotification(subscriptionIds, title, message, {
          type: "ORDER_CANCELLED",
          orderId: Number(orderId),
          status: 2,
        });

        logger.info("Order cancellation notification sent", {
          userId,
          orderId,
          devicesCount: subscriptionIds.length,
        });
      } else {
        logger.warn("No device subscriptions found for cancellation notification", {
          userId,
          orderId,
        });
      }
    } catch (pushErr) {
      logger.error("Failed to send order cancellation notification", {
        userId,
        orderId,
        error: pushErr.message,
        stack: pushErr.stack,
      });
    }

    return res.json({ message: "Order cancelled successfully" });
  } catch (err) {
    logger.error("Error processing order cancellation", {
      userId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    return res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

// PUT /api/orders/:orderId/payment-success - Update order payment status after online payment completion
// Called by payment gateway webhook or frontend after successful payment processing
// Marks order as paid and stores payment gateway reference ID for reconciliation
// Critical for order fulfillment workflow and financial tracking
router.put("/:orderId/payment-success", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { paymentId } = req.body;
  const userId = req.user.id;

  if (!paymentId) {
    logger.warn("Payment success attempt missing paymentId", {
      userId,
      orderId,
    });

    return res.status(400).json({ message: "paymentId is required" });
  }

  try {
    // 1) Verify order exists and belongs to logged-in user
    const [orders] = await pool.execute(
      `SELECT id, user_id, admin_id, status
       FROM orders
       WHERE id = ? AND user_id = ?`,
      [orderId, userId]
    );

    if (!orders.length) {
      logger.warn("Payment success update attempt on missing or unauthorized order", {
        userId,
        orderId,
        reason: "Order not found or does not belong to user",
      });

      return res.status(404).json({ message: "Order not found" });
    }

    const order = orders[0];
    const adminId = order.admin_id;

    // 2) Update order payment reference
    await pool.execute(
      `UPDATE orders
       SET payment_id = ?
       WHERE id = ? AND user_id = ?`,
      [paymentId, orderId, userId]
    );

    // 3) Mark all shareholders under this order as paid + processing
    await pool.execute(
      `UPDATE shareholder_details
       SET payment_status = 0,
           status = 1
       WHERE order_id = ?`,
      [orderId]
    );

    logger.info("Order payment recorded successfully", {
      userId,
      orderId,
      adminId,
      paymentId,
      updateType: "payment_success_callback",
      shareholderPaymentStatus: 0, // paid
      shareholderStatus: 2, // processing
    });

    // 4) Send push notification to admin's registered devices
    try {
      const [devices] = await pool.execute(
        `SELECT subscription_id
         FROM user_devices
         WHERE user_id = ? AND subscription_id IS NOT NULL`,
        [adminId]
      );

      const subscriptionIds = devices
        .map((d) => d.subscription_id)
        .filter(Boolean);

      if (subscriptionIds.length > 0) {
        const title = `Payment Received for Order #${orderId}`;
        const message = `User payment has been received successfully for order #${orderId}.`;

        await sendPushNotification(subscriptionIds, title, message, {
          type: "ORDER_PAYMENT_SUCCESS",
          orderId: Number(orderId),
          paymentId,
          status: 2,
        });

        logger.info("Order payment notification sent to admin", {
          userId,
          adminId,
          orderId,
          devicesCount: subscriptionIds.length,
        });
      } else {
        logger.warn("No device subscriptions found for payment notification", {
          userId,
          adminId,
          orderId,
        });
      }
    } catch (pushErr) {
      logger.error("Failed to send order payment notification", {
        userId,
        adminId,
        orderId,
        paymentId,
        error: pushErr.message,
        stack: pushErr.stack,
      });
    }

    return res.json({ message: "Payment status updated successfully" });
  } catch (err) {
    logger.error("Error updating order payment status", {
      userId,
      orderId,
      paymentId,
      error: err.message,
      stack: err.stack,
      impact:
        "Payment may not be properly recorded - manual reconciliation required",
    });

    return res
      .status(500)
      .json({ message: "Something went wrong. Please try again later." });
  }
});

module.exports = router;

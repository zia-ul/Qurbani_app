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
 * - Supabase: Database access
 * - authMiddleware: Authentication middleware
 * - logger: Logging utility for audit trails
 */

const express = require("express");
const router = express.Router();
const { v4: uuidv4 } = require("uuid");
const supabase = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");
const { sendPushNotification } = require("../utils/notification_service");
const razorpayService = require("../services/razorpayService");

const ok = (res, message, data = {}, status = 200) =>
  res.status(status).json({ success: true, message, data });

const fail = (res, message, status = 500, data = {}) =>
  res.status(status).json({ success: false, message, data });

const throwDb = (error, message = "Database operation failed") => {
  if (error) {
    const err = new Error(error.message || message);
    err.statusCode = 500;
    throw err;
  }
};

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

const getShareholderTableConfig = async () => ({ hasPaymentStatus: true });

const buildOrderInsertPayload = async (
  userId,
  adminId,
  normalizedPaymentMethod,
  shareholderCount,
  totalAmount,
) => {
  const orderId = uuidv4();

  return {
    id: orderId,
    user_id: userId,
    admin_id: adminId,
    payment_method: normalizedPaymentMethod,
    total_shares: shareholderCount,
    total_amt: totalAmount,
  };
};

const buildShareholderInsertPayload = async (
  orderId,
  shareholders,
  normalizedPaymentStatus,
) => {
  return shareholders.map((shareholder) => {
    const normalizedAddress = normalizeIncomingAddress(shareholder.address);

    if (!normalizedAddress?.address_line) {
      throw new Error("Address is required for each shareholder");
    }

    return {
      id: uuidv4(),
      order_id: orderId,
      shareholder_name: sanitizeText(shareholder.name || shareholder.shareholder_name),
      guardian_name: sanitizeText(shareholder.guardianName || shareholder.guardian_name),
      qurbani_day: sanitizeText(shareholder.qurbaniDay || shareholder.qurbani_day),
      animal_type: sanitizeText(shareholder.animal_type || shareholder.animalType || shareholder.animal),
      price: Number(shareholder.price || 0),
      address: JSON.stringify(normalizedAddress),
      payment_status: normalizedPaymentStatus,
    };
  });
};

const parseNumber = (value, fallback = 0) => {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
};

const cancellationWindowHours = () =>
  Number(process.env.CANCELLATION_WINDOW_HOURS || 24);

const isOnlinePaymentAllowed = async (adminId) => {
  const { data: settings, error } = await supabase
    .from("admin_payment_settings")
    .select("allow_online")
    .eq("admin_id", adminId)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  throwDb(error, "Failed to fetch payment settings");

  return Number(settings?.allow_online ?? 1) === 1;
};

const isCodPaymentAllowed = async (adminId) => {
  const { data: settings, error } = await supabase
    .from("admin_payment_settings")
    .select("allow_cod")
    .eq("admin_id", adminId)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  throwDb(error, "Failed to fetch payment settings");

  return Number(settings?.allow_cod ?? 0) === 1;
};

const normalizeRazorpayVerificationBody = (body) => ({
  razorpay_order_id: body.razorpay_order_id || body.razorpayOrderId,
  razorpay_payment_id:
    body.razorpay_payment_id || body.razorpayPaymentId || body.paymentId,
  razorpay_signature: body.razorpay_signature || body.razorpaySignature,
});

const markPaymentVerified = async ({
  orderId,
  razorpayPaymentId,
  razorpaySignature,
  paymentStatus,
}) => {
  const now = new Date().toISOString();
  const { error: orderError } = await supabase
    .from("orders")
    .update({
      payment_id: razorpayPaymentId,
      razorpay_payment_id: razorpayPaymentId,
      razorpay_signature: razorpaySignature,
      razorpay_payment_status: paymentStatus,
      payment_verified_at: now,
      payment_status: 0,
    })
    .eq("id", orderId);
  throwDb(orderError, "Failed to mark order payment verified");

  const { data: shareholders, error: fetchError } = await supabase
    .from("shareholder_details")
    .select("id,status")
    .eq("order_id", orderId);
  throwDb(fetchError, "Failed to fetch shareholders for payment update");

  const ids = (shareholders || []).map((shareholder) => shareholder.id);
  if (!ids.length) {
    return;
  }

  const { error: shareholderError } = await supabase
    .from("shareholder_details")
    .update({ payment_status: 0 })
    .in("id", ids);
  throwDb(shareholderError, "Failed to update shareholder payment status");

  const statusZeroIds = shareholders
    .filter((shareholder) => Number(shareholder.status) === 0)
    .map((shareholder) => shareholder.id);

  if (statusZeroIds.length) {
    const { error: statusError } = await supabase
      .from("shareholder_details")
      .update({ status: 1 })
      .in("id", statusZeroIds);
    throwDb(statusError, "Failed to update shareholder status");
  }
};

const verifyPaymentForOrder = async ({ orderId, userId, body }) => {
  const {
    razorpay_order_id,
    razorpay_payment_id,
    razorpay_signature,
  } = normalizeRazorpayVerificationBody(body);

  if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    const error = new Error(
      "razorpay_order_id, razorpay_payment_id, and razorpay_signature are required",
    );
    error.statusCode = 400;
    throw error;
  }

  try {
    const order = await razorpayService.loadOrderForPayment(orderId);

    if (!order || String(order.user_id) !== String(userId)) {
      const error = new Error("Order not found");
      error.statusCode = 404;
      throw error;
    }

    if (String(order.razorpay_order_id || "") !== String(razorpay_order_id)) {
      const error = new Error("Razorpay order does not match this booking");
      error.statusCode = 400;
      throw error;
    }

    if (
      order.razorpay_payment_id &&
      String(order.razorpay_payment_id) === String(razorpay_payment_id) &&
      Number(order.payment_status) === 0
    ) {
      return { alreadyVerified: true };
    }

    // Checkout success is not trusted until the HMAC signature and Razorpay
    // payment/order records match the local booking amount.
    if (
      !razorpayService.verifyPaymentSignature({
        razorpay_order_id,
        razorpay_payment_id,
        razorpay_signature,
      })
    ) {
      const error = new Error("Invalid Razorpay payment signature");
      error.statusCode = 400;
      throw error;
    }

    const [payment, razorpayOrder] = await Promise.all([
      razorpayService.fetchPayment(razorpay_payment_id),
      razorpayService.fetchOrder(razorpay_order_id),
    ]);

    const expectedAmount =
      Number(order.razorpay_expected_amount || 0) ||
      razorpayService.calculatePayableAmount(order);
    const expectedCurrency =
      order.razorpay_currency || razorpayService.getConfig().currency;

    if (String(payment.order_id) !== String(razorpay_order_id)) {
      const error = new Error("Payment does not belong to this Razorpay order");
      error.statusCode = 400;
      throw error;
    }

    if (Number(payment.amount) !== Number(expectedAmount)) {
      const error = new Error("Payment amount does not match booking amount");
      error.statusCode = 400;
      throw error;
    }

    if (String(payment.currency) !== String(expectedCurrency)) {
      const error = new Error("Payment currency does not match booking currency");
      error.statusCode = 400;
      throw error;
    }

    if (!["captured", "authorized"].includes(String(payment.status))) {
      const error = new Error("Payment is not captured");
      error.statusCode = 400;
      throw error;
    }

    if (Number(razorpayOrder.amount) !== Number(expectedAmount)) {
      const error = new Error("Razorpay order amount does not match booking amount");
      error.statusCode = 400;
      throw error;
    }

    await markPaymentVerified({
      orderId,
      razorpayPaymentId: razorpay_payment_id,
      razorpaySignature: razorpay_signature,
      paymentStatus: payment.status,
    });

    return { alreadyVerified: false };
  } catch (error) {
    throw error;
  }
};

const fetchLatestPaymentSettingsByAdminIds = async (adminIds) => {
  const ids = [...new Set((adminIds || []).filter(Boolean))];
  if (!ids.length) {
    return new Map();
  }

  const { data, error } = await supabase
    .from("admin_payment_settings")
    .select("*")
    .in("admin_id", ids)
    .order("updated_at", { ascending: false });
  throwDb(error, "Failed to fetch admin payment settings");

  const settingsByAdminId = new Map();
  for (const setting of data || []) {
    const key = String(setting.admin_id);
    if (!settingsByAdminId.has(key)) {
      settingsByAdminId.set(key, setting);
    }
  }
  return settingsByAdminId;
};

const dedupeOrdersById = (orders) => {
  const seen = new Set();

  return orders.filter((order) => {
    const key = String(order.id ?? order.orderId ?? "").trim();

    if (!key) {
      return true;
    }

    if (seen.has(key)) {
      return false;
    }

    seen.add(key);
    return true;
  });
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

  const [{ data: animals, error: animalsError }, { data: animalDetailsRows, error: detailsError }] =
    await Promise.all([
      supabase.from("animals").select("*").in("id", animalIds),
      supabase.from("animal_details").select("*").in("animal_id", animalIds),
    ]);
  throwDb(animalsError, "Failed to fetch animals");
  throwDb(detailsError, "Failed to fetch animal details");

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
    const shareholderTableConfig = await getShareholderTableConfig();
    const { data: orders, error: ordersError } = await supabase
      .from("orders")
      .select("id,user_id,admin_id,payment_method,total_shares,status,created_at")
      .eq("user_id", userId)
      .order("created_at", { ascending: false });
    throwDb(ordersError, "Failed to fetch user orders");

    const uniqueOrders = dedupeOrdersById(orders || []);
    const orderIds = uniqueOrders.map((order) => order.id);
    const adminIds = uniqueOrders.map((order) => order.admin_id).filter(Boolean);
    const [
      { data: admins, error: adminsError },
      { data: shareholders, error: shareholdersError },
      settingsByAdminId,
    ] = await Promise.all([
      adminIds.length
        ? supabase.from("users").select("id,name,email").in("id", adminIds)
        : Promise.resolve({ data: [], error: null }),
      orderIds.length
        ? supabase.from("shareholder_details").select("*").in("order_id", orderIds)
        : Promise.resolve({ data: [], error: null }),
      fetchLatestPaymentSettingsByAdminIds(adminIds),
    ]);
    throwDb(adminsError, "Failed to fetch admins");
    throwDb(shareholdersError, "Failed to fetch shareholders");

    const adminsById = new Map((admins || []).map((admin) => [String(admin.id), admin]));
    const shareholdersByOrderId = new Map();
    for (const shareholder of shareholders || []) {
      const key = String(shareholder.order_id);
      const current = shareholdersByOrderId.get(key) || [];
      current.push(shareholder);
      shareholdersByOrderId.set(key, current);
    }

    for (const order of uniqueOrders) {
      const admin = adminsById.get(String(order.admin_id));
      const settings = settingsByAdminId.get(String(order.admin_id));
      const orderShareholders = shareholdersByOrderId.get(String(order.id)) || [];
      order.admin_name = admin?.name ?? null;
      order.admin_email = admin?.email ?? null;
      order.cod_deadline = settings?.cod_deadline ?? null;
      order.shareholders = orderShareholders;
      applyComputedOrderStatuses(
        order,
        orderShareholders,
        shareholderTableConfig.hasPaymentStatus,
      );
    }

    return ok(res, "Orders fetched successfully", { orders: uniqueOrders });
  } catch (err) {
    logger.error("Failed to fetch user orders", {
      userId,
      error: err.message,
      stack: err.stack,
    });
    return fail(res, "Something went wrong. Please try again later.");
  }
});




router.post("/:orderId/assign-animal", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { animalId } = req.body;

  try {
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("user_id")
      .eq("id", orderId)
      .maybeSingle();
    throwDb(orderError, "Failed to fetch order");

    if (!order) {
      return fail(res, "Order not found", 404);
    }

    const userId = order.user_id;

    const { data: availableDetail, error: detailFetchError } = await supabase
      .from("animal_details")
      .select("id")
      .eq("animal_id", animalId)
      .is("order_id", null)
      .limit(1)
      .maybeSingle();
    throwDb(detailFetchError, "Failed to find available animal share");

    if (!availableDetail) {
      return fail(res, "No shares available", 400);
    }

    const { error: detailUpdateError } = await supabase
      .from("animal_details")
      .update({ order_id: orderId })
      .eq("id", availableDetail.id);
    throwDb(detailUpdateError, "Failed to assign animal share");

    const [{ count: totalAssigned, error: assignedError }, { data: animal, error: animalError }] =
      await Promise.all([
        supabase
          .from("animal_details")
          .select("id", { count: "exact", head: true })
          .eq("animal_id", animalId)
          .not("order_id", "is", null),
        supabase.from("animals").select("shares").eq("id", animalId).maybeSingle(),
      ]);
    throwDb(assignedError, "Failed to count assigned shares");
    throwDb(animalError, "Failed to fetch animal");

    const totalShares = Number(animal?.shares || 0);

    // If fully booked → mark sold
    if (totalAssigned >= totalShares) {
      const { error: soldError } = await supabase
        .from("animals")
        .update({ status: "sold" })
        .eq("id", animalId);
      throwDb(soldError, "Failed to mark animal sold");
    }

    try {
      const { data: devices, error: devicesError } = await supabase
        .from("user_devices")
        .select("subscription_id")
        .eq("user_id", userId);
      throwDb(devicesError, "Failed to fetch devices");

      const subscriptionIds = (devices || []).map((d) => d.subscription_id).filter(Boolean);

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

    return ok(res, "Animal assigned successfully", { orderId, animalId });
  } catch (error) {
    logger.error("Animal assignment failed", {
      orderId,
      animalId,
      error: error.message,
      stack: error.stack,
    });

    return fail(res, "Failed to assign animal");
  }
});




router.post("/", authMiddleware, async (req, res) => {
  const userId = req.user.id;
  const { adminId, paymentMethod, shareholders } = req.body;

  console.log(req.body);

  if (
    !adminId ||
    paymentMethod === undefined ||
    !Array.isArray(shareholders) ||
    shareholders.length === 0
  ) {
    return fail(res, "Missing required fields", 400);
  }

  try {
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

    if (
      normalizedPaymentMethod === 1 &&
      !(await isOnlinePaymentAllowed(adminId))
    ) {
      return fail(res, "Online payment is not allowed", 400);
    }

    if (
      normalizedPaymentMethod === 0 &&
      !(await isCodPaymentAllowed(adminId))
    ) {
      return fail(res, "Cash payment is not allowed", 400);
    }

    const normalizedPaymentStatus = normalizedPaymentMethod === 1 ? 2 : 1;

    const normalizedShareholders = shareholders.map((shareholder) => {
      const lateFee = parseNumber(shareholder.lateFee ?? shareholder.late_fee, 0);
      const price = parseNumber(shareholder.price, 0);

      return {
        ...shareholder,
        animal_type: null,
        price: price > 0 ? price : lateFee,
      };
    });

    const shareSubtotal = normalizedShareholders.reduce(
      (sum, shareholder) => sum + Number(shareholder.price || 0),
      0,
    );
    const { data: shareSetup, error: shareSetupError } = await supabase
      .from("admin_share_setups")
      .select("delivery_type,delivery_fee")
      .eq("admin_id", adminId)
      .eq("is_active", 1)
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    throwDb(shareSetupError, "Failed to fetch share setup");
    const deliveryFee =
      shareSetup?.delivery_type === "paid"
        ? Number(shareSetup.delivery_fee || 0)
        : 0;
    const normalizedTotalAmount = shareSubtotal + deliveryFee;

    const orderInsert = await buildOrderInsertPayload(
      userId,
      adminId,
      normalizedPaymentMethod,
      normalizedShareholders.length,
      normalizedTotalAmount,
    );

    const { data: orderRow, error: orderError } = await supabase
      .from("orders")
      .insert(orderInsert)
      .select("id")
      .single();
    throwDb(orderError, "Failed to create order");

    const orderId = orderRow.id;

    const shareholderInsert = await buildShareholderInsertPayload(
      orderId,
      normalizedShareholders,
      normalizedPaymentStatus,
    );

    const { error: shareholderError } = await supabase
      .from("shareholder_details")
      .insert(shareholderInsert);

    if (shareholderError) {
      await supabase.from("orders").delete().eq("id", orderId);
      throwDb(shareholderError, "Failed to create shareholder details");
    }

    try {
      const { data: devices, error: devicesError } = await supabase
        .from("user_devices")
        .select("subscription_id")
        .eq("user_id", adminId);
      throwDb(devicesError, "Failed to fetch admin devices");

      const subscriptionIds = (devices || [])
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

    return ok(res, "Order placed successfully", { orderId }, 201);
  } catch (err) {
    logger.error("Order creation failed", {
      userId,
      adminId,
      error: err.message,
      stack: err.stack,
    });

    return fail(res, err.message || "Something went wrong");
  }
});

router.get("/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    const shareholderTableConfig = await getShareholderTableConfig();
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("*")
      .eq("id", orderId)
      .eq("user_id", userId)
      .maybeSingle();
    throwDb(orderError, "Failed to fetch order");

    if (!order) {
      return fail(res, "Order not found", 404);
    }

    const [{ data: admin, error: adminError }, { data: shareholders, error: shareholdersError }] =
      await Promise.all([
        supabase
          .from("users")
          .select("name,address,phone")
          .eq("id", order.admin_id)
          .maybeSingle(),
        supabase.from("shareholder_details").select("*").eq("order_id", orderId),
      ]);
    throwDb(adminError, "Failed to fetch admin");
    throwDb(shareholdersError, "Failed to fetch shareholders");

    const orderDetails = await buildOrderAnimalsAndShareholders(
      orderId,
      shareholders || [],
    );

    order.admin_name = admin?.name ?? null;
    order.admin_address = admin?.address ?? null;
    order.admin_phone = admin?.phone ?? null;
    order.shareholders = orderDetails.shareholders;
    order.animals = orderDetails.animals;

    applyComputedOrderStatuses(
      order,
      orderDetails.shareholders,
      shareholderTableConfig.hasPaymentStatus,
    );


    return ok(res, "Order fetched successfully", { order });
  } catch (err) {
    logger.error("Failed to fetch order details", {
      orderId,
      userId,
      error: err.message,
      stack: err.stack,
    });

    return fail(res, "Something went wrong.");
  }
});



router.put("/animal-details/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { meat_weight, body_parts_description } = req.body;

  try {
    const { data: shareholders, error: shareholdersError } = await supabase
      .from("order_shareholders")
      .select("id")
      .eq("order_id", orderId);
    throwDb(shareholdersError, "Failed to fetch order shareholders");

    if (!shareholders?.length) {
      return fail(res, "No shareholders found for this order", 404);
    }

    await Promise.all(
      shareholders.map((s) =>
        supabase
          .from("animal_details")
          .update({ meat_weight, body_parts_description })
          .eq("order_id", orderId)
          .eq("shareholder_id", s.id),
      ),
    ).then((results) => {
      for (const result of results) {
        throwDb(result.error, "Failed to update animal details");
      }
    });

    const { error: orderError } = await supabase
      .from("orders")
      .update({ processing_status: "completed" })
      .eq("id", orderId);
    throwDb(orderError, "Failed to update order processing status");

    return ok(res, "Meat details saved successfully");
  } catch (err) {
    logger.error("Meat details update failed", err);
    return fail(res, "Failed to save meat details");
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
    const shareholderTableConfig = await getShareholderTableConfig();
    const [{ data: orders, error: ordersError }, settingsByAdminId] = await Promise.all([
      supabase
        .from("orders")
        .select("id,user_id,admin_id,payment_method,total_shares,total_amt,status,created_at")
        .eq("admin_id", adminId)
        .order("created_at", { ascending: false }),
      fetchLatestPaymentSettingsByAdminIds([adminId]),
    ]);
    throwDb(ordersError, "Failed to fetch admin orders");

    const uniqueOrders = dedupeOrdersById(orders || []).map((order) => ({
      ...order,
      order_status: order.status,
      cod_deadline: settingsByAdminId.get(String(order.admin_id))?.cod_deadline ?? null,
    }));

    if (!uniqueOrders.length) {
      return ok(res, "Orders fetched successfully", { orders: [] });
    }

    const orderIds = uniqueOrders.map((order) => order.id);
    const { data: shareholders, error: shareholdersError } = await supabase
      .from("shareholder_details")
      .select("*")
      .in("order_id", orderIds)
      .order("order_id", { ascending: false })
      .order("id", { ascending: true });
    throwDb(shareholdersError, "Failed to fetch shareholders");

    const shareholdersByOrderId = new Map();
    for (const shareholder of shareholders || []) {
      const key = String(shareholder.order_id);
      const existing = shareholdersByOrderId.get(key) || [];
      existing.push(shareholder);
      shareholdersByOrderId.set(key, existing);
    }

    const formattedOrders = uniqueOrders.map((order) => {
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

    return ok(res, "Orders fetched successfully", { orders: formattedOrders });
  } catch (err) {
    logger.error("Failed to fetch admin orders", {
      adminId,
      error: err.message,
      stack: err.stack,
    });

    return fail(res, "Something went wrong. Please try again later.");
  }
});


router.post("/requests", authMiddleware, async (req, res) => {
  const { orderId, userId, title, description } = req.body;
  const authUserId = req.user.id;

  if (authUserId !== userId) {
    return fail(res, "Unauthorized", 403);
  }

  if (!orderId || !title || !description) {
    return fail(res, "Missing required fields", 400);
  }

  try {
    const { error: requestError } = await supabase
      .from("requests")
      .insert({ order_id: orderId, user_id: userId, title, description, status: "Pending" });
    throwDb(requestError, "Failed to submit request");

    try {
      const { data: order, error: orderError } = await supabase
        .from("orders")
        .select("admin_id")
        .eq("id", orderId)
        .maybeSingle();
      throwDb(orderError, "Failed to fetch order admin");

      if (order) {
        const adminId = order.admin_id;

        const { data: devices, error: devicesError } = await supabase
          .from("user_devices")
          .select("subscription_id")
          .eq("user_id", adminId);
        throwDb(devicesError, "Failed to fetch admin devices");

        const subscriptionIds = (devices || []).map((d) => d.subscription_id).filter(Boolean);
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

    return ok(res, "Request submitted successfully", {}, 201);
  } catch (err) {
    logger.error("Failed to submit request", {
      orderId,
      userId,
      error: err.message,
      stack: err.stack,
    });

    return fail(res, "Something went wrong. Please try again later.");
  }
});

router.get("/requests/:orderId/:userId", authMiddleware, async (req, res) => {
  const { orderId, userId } = req.params;
  const authUserId = req.user.id;

  if (authUserId !== userId) {
    return fail(res, "Unauthorized", 403);
  }

  try {
    const { data: requests, error } = await supabase
      .from("requests")
      .select("id,title,description,status,created_at")
      .eq("order_id", orderId)
      .eq("user_id", userId);
    throwDb(error, "Failed to fetch user requests");

    return ok(res, "Requests fetched successfully", { requests: requests || [] });
  } catch (err) {
    logger.error("Failed to fetch user requests", {
      orderId,
      userId,
      error: err.message,
      stack: err.stack,
    });
    return fail(res, "Something went wrong. Please try again later.");
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
    const shareholderTableConfig = await getShareholderTableConfig();
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("id,user_id,admin_id,payment_method,total_shares,total_amt,status,created_at")
      .eq("id", orderId)
      .eq("admin_id", adminId)
      .maybeSingle();
    throwDb(orderError, "Failed to fetch admin order");

    if (!order) {
      return fail(res, "Order not found or not authorized", 404);
    }

    order.order_status = order.status;

    const [
      { data: users, error: usersError },
      { data: shareholders, error: shareholdersError },
      settingsByAdminId,
    ] = await Promise.all([
      supabase.from("users").select("id,name,email,phone,address").in("id", [order.user_id, order.admin_id]),
      supabase.from("shareholder_details").select("*").eq("order_id", order.id),
      fetchLatestPaymentSettingsByAdminIds([order.admin_id]),
    ]);
    throwDb(usersError, "Failed to fetch order users");
    throwDb(shareholdersError, "Failed to fetch shareholders");

    const usersById = new Map((users || []).map((user) => [String(user.id), user]));
    const user = usersById.get(String(order.user_id));
    const admin = usersById.get(String(order.admin_id));
    order.user_name = user?.name ?? null;
    order.user_email = user?.email ?? null;
    order.contact_no = user?.phone ?? null;
    order.address = user?.address ?? null;
    order.admin_name = admin?.name ?? null;
    order.cod_deadline = settingsByAdminId.get(String(order.admin_id))?.cod_deadline ?? null;

    const orderDetails = await buildOrderAnimalsAndShareholders(
      order.id,
      shareholders || [],
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

    return ok(res, "Order fetched successfully", { order: orderWithDetails });
  } catch (err) {
    logger.error("Failed to fetch admin order details", {
      adminId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    return fail(res, "Something went wrong. Please try again later.");
  }
});


router.put("/admin/:orderId", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { processingStatus, deliveryStatus, deliveryPersonId } = req.body;
  const adminId = req.user.id;

  if (!processingStatus || !deliveryStatus) {
    return fail(res, "Missing required fields", 400);
  }

  try {
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("id")
      .eq("id", orderId)
      .eq("admin_id", adminId)
      .maybeSingle();
    throwDb(orderError, "Failed to fetch order");

    if (!order) {
      return fail(res, "Order not found or not authorized", 404);
    }

    const { error: updateError } = await supabase
      .from("orders")
      .update({
        status: processingStatus,
        delivery_status: deliveryStatus,
        delivery_person_id: deliveryPersonId || null,
      })
      .eq("id", orderId);
    throwDb(updateError, "Failed to update order");

    return ok(res, "Order updated successfully", { orderId });
  } catch (err) {
    logger.error("Failed to update admin order", {
      adminId,
      orderId,
      error: err.message,
      stack: err.stack,
    });
    return fail(res, "Something went wrong. Please try again later.");
  }
});

router.post("/:orderId/create-razorpay-order", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    const order = await razorpayService.loadOrderForPayment(orderId);

    if (!order || String(order.user_id) !== String(userId)) {
      return fail(res, "Order not found", 404);
    }

    if (Number(order.payment_method) !== 1) {
      return fail(res, "This order is not configured for online payment", 400);
    }

    if (Number(order.payment_status) === 0 || order.razorpay_payment_id) {
      return fail(res, "Order is already paid", 400);
    }

    const statuses = (order.shareholders || []).map((s) => Number(s.status));
    const isDeliveredOrCompleted =
      Number(order.status) === 1 ||
      statuses.some((status) => status === 5) ||
      statuses.every((status) => status === 6);

    if (Number(order.status) === 2 || isDeliveredOrCompleted) {
      return fail(res, "Cannot create payment for this order", 400);
    }

    if (!(await isOnlinePaymentAllowed(order.admin_id))) {
      return fail(res, "Online payment is not allowed", 400);
    }

    const razorpayOrder = await razorpayService.createRazorpayOrder({ orderId });

    return ok(res, "Razorpay order created", razorpayOrder);
  } catch (error) {
    logger.error("Failed to create Razorpay order", {
      orderId,
      userId,
      error: razorpayService.getRazorpayErrorMessage(error),
      stack: error.stack,
    });

    return fail(
      res,
      error.statusCode && error.statusCode < 500
        ? error.message
        : "Unable to create payment order right now.",
      error.statusCode || 500,
    );
  }
});

router.post("/:orderId/verify-payment", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;

  try {
    const result = await verifyPaymentForOrder({
      orderId,
      userId,
      body: req.body,
    });

    logger.info("Razorpay payment verified", {
      orderId,
      userId,
      alreadyVerified: result.alreadyVerified,
    });

    return ok(
      res,
      result.alreadyVerified ? "Payment already verified" : "Payment verified successfully",
      result,
    );
  } catch (error) {
    logger.warn("Razorpay payment verification failed", {
      orderId,
      userId,
      error: razorpayService.getRazorpayErrorMessage(error),
    });

    return fail(
      res,
      error.statusCode && error.statusCode < 500
        ? error.message
        : "Unable to verify payment right now.",
      error.statusCode || 500,
    );
  }
});

router.put("/:orderId/cancel", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const { cancellation_reason } = req.body || {};
  const userId = req.user.id;

  try {
    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("*")
      .eq("id", orderId)
      .eq("user_id", userId)
      .maybeSingle();
    throwDb(orderError, "Failed to fetch order");

    if (!order) {
      logger.warn("Order cancellation attempt on missing or unauthorized order", {
        userId,
        orderId,
        reason: "Order not found or does not belong to user",
      });

      return fail(res, "Order not found", 404);
    }

    const { data: shareholders, error: shareholdersError } = await supabase
      .from("shareholder_details")
      .select("status")
      .eq("order_id", orderId);
    throwDb(shareholdersError, "Failed to fetch shareholders");

    const statuses = (shareholders || []).map((s) => Number(s.status));
    const isDelivered = statuses.some((s) => s === 5); // 5 = Delivered
    const isCompleted = Number(order.status) === 1;
    const isCancelled = statuses.some((s) => s === 6) || Number(order.status) === 2;

    if (isCancelled) {
      return ok(res, "Order already cancelled", {
        cancellation_status: order.cancellation_status || "cancelled",
        refund_status: order.razorpay_refund_status || "none",
        razorpay_refund_id: order.razorpay_refund_id || null,
      });
    }

    const timeSinceOrder = Date.now() - new Date(order.created_at).getTime();
    const windowMs = cancellationWindowHours() * 60 * 60 * 1000;
    const withinCancellationWindow = timeSinceOrder < windowMs;
    const orderAgeHours = Math.floor(timeSinceOrder / (1000 * 60 * 60));
    const orderAgeMinutes = Math.floor(timeSinceOrder / (1000 * 60));

    const canCancel =
      withinCancellationWindow && !isDelivered && !isCompleted && !isCancelled;

    if (!canCancel) {
      logger.warn("Invalid order cancellation attempt - business rules violation", {
        userId,
        orderId,
        orderStatus: order.status,
        shareholderStatuses: statuses,
        withinCancellationWindow,
        orderAgeHours,
        isDelivered,
        isCompleted,
        isCancelled,
        reason: !withinCancellationWindow
          ? "Outside 24-hour window"
          : isDelivered
            ? "Order already delivered"
            : isCompleted
              ? "Order already completed"
              : "Order already cancelled",
      });

      return fail(
        res,
        !withinCancellationWindow ? "Cancellation window expired." : "Cannot cancel this order",
        400,
      );
    }

    const isPaidOnline =
      Number(order.payment_method) === 1 &&
      (Number(order.payment_status) === 0 ||
        order.razorpay_payment_id ||
        order.payment_id);
    const paymentId = order.razorpay_payment_id || order.payment_id;

    if (isPaidOnline && !paymentId) {
      return fail(res, "Payment reference is missing. Please contact support.", 400);
    }

    const duplicateRefund =
      order.razorpay_refund_id ||
      ["initiated", "processed"].includes(
        String(order.razorpay_refund_status || "").toLowerCase(),
      );

    if (isPaidOnline && duplicateRefund) {
      return ok(res, "Order cancellation is already being refunded", {
        cancellation_status: order.cancellation_status || "refund_pending",
        refund_status: order.razorpay_refund_status,
        razorpay_refund_id: order.razorpay_refund_id,
      });
    }

    const cancellationStatus = isPaidOnline ? "refund_pending" : "cancelled";
    const refundStatus = isPaidOnline ? "initiated" : "none";

    const { error: cancelError } = await supabase
      .from("orders")
      .update({
        status: 2,
        cancelled_at: new Date().toISOString(),
        cancellation_reason: sanitizeText(cancellation_reason || "buyer_cancelled_within_24_hours"),
        cancellation_requested_by: userId,
        cancellation_status: cancellationStatus,
        razorpay_refund_status: isPaidOnline
          ? refundStatus
          : order.razorpay_refund_status || "none",
      })
      .eq("id", orderId)
      .eq("user_id", userId);
    throwDb(cancelError, "Failed to cancel order");

    const { error: shareholderCancelError } = await supabase
      .from("shareholder_details")
      .update({ status: 6 })
      .eq("order_id", orderId);
    throwDb(shareholderCancelError, "Failed to cancel shareholders");

    let refund = null;

    if (isPaidOnline) {
      const refundAmountPaise = razorpayService.calculateRefundAmount(order);
      // Full buyer cancellation refunds can ask Razorpay Route to reverse all
      // linked transfers while returning money to the original payment method.
      const reverseAll = Boolean(
        order.vendor_linked_account_id || order.razorpay_transfer_id,
      );

      try {
        refund = await razorpayService.refundPayment({
          razorpay_payment_id: paymentId,
          amountPaise: refundAmountPaise,
          reverseAll,
          notes: {
            orderId: String(orderId),
            reason: "buyer_cancelled_within_24_hours",
          },
        });

        const { error: refundUpdateError } = await supabase
          .from("orders")
          .update({
            razorpay_refund_id: refund.id,
            refund_amount: refundAmountPaise,
            razorpay_refund_status: refund.status || "initiated",
            refund_initiated_at: new Date().toISOString(),
            refund_error: null,
          })
          .eq("id", orderId);
        throwDb(refundUpdateError, "Failed to record refund");
      } catch (refundError) {
        await supabase
          .from("orders")
          .update({
            razorpay_refund_status: "failed",
            cancellation_status: "refund_failed",
            refund_error: razorpayService.getRazorpayErrorMessage(refundError),
          })
          .eq("id", orderId);

        logger.error("Razorpay refund failed after cancellation", {
          orderId,
          userId,
          error: razorpayService.getRazorpayErrorMessage(refundError),
          stack: refundError.stack,
        });

        return fail(
          res,
          "Order was cancelled, but refund could not be initiated. Please contact support.",
          502,
          {
          cancellation_status: "refund_failed",
          refund_status: "failed",
          },
        );
      }
    }

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
      const { data: devices, error: devicesError } = await supabase
        .from("user_devices")
        .select("subscription_id")
        .eq("user_id", userId)
        .not("subscription_id", "is", null);
      throwDb(devicesError, "Failed to fetch devices");

      const subscriptionIds = (devices || [])
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

    return ok(res, isPaidOnline
        ? "Order cancelled and refund initiated"
        : "Order cancelled successfully", {
      cancellation_status: cancellationStatus,
      refund_status: refund?.status || (isPaidOnline ? "initiated" : "none"),
      razorpay_refund_id: refund?.id || null,
    });
  } catch (err) {
    logger.error("Error processing order cancellation", {
      userId,
      orderId,
      error: err.message,
      stack: err.stack,
    });

    return fail(res, "Something went wrong. Please try again later.");
  }
});

// PUT /api/orders/:orderId/payment-success - Update order payment status after online payment completion
// Called by payment gateway webhook or frontend after successful payment processing
// Marks order as paid and stores payment gateway reference ID for reconciliation
// Critical for order fulfillment workflow and financial tracking
router.put("/:orderId/payment-success", authMiddleware, async (req, res) => {
  const { orderId } = req.params;
  const userId = req.user.id;
  const verificationBody = normalizeRazorpayVerificationBody(req.body || {});

  if (
    !verificationBody.razorpay_order_id ||
    !verificationBody.razorpay_payment_id ||
    !verificationBody.razorpay_signature
  ) {
    logger.warn("Rejected legacy payment success request without signature", {
      userId,
      orderId,
    });

    return fail(
      res,
      "Payment verification now requires razorpay_order_id, razorpay_payment_id, and razorpay_signature",
      400,
    );
  }

  try {
    const result = await verifyPaymentForOrder({
      orderId,
      userId,
      body: verificationBody,
    });

    logger.info("Order payment recorded successfully", {
      userId,
      orderId,
      updateType: "legacy_payment_success_verified",
      alreadyVerified: result.alreadyVerified,
    });

    return ok(res, "Payment verified successfully", result);
  } catch (err) {
    logger.error("Error updating order payment status", {
      userId,
      orderId,
      error: razorpayService.getRazorpayErrorMessage(err),
      stack: err.stack,
      impact:
        "Payment may not be properly recorded - manual reconciliation required",
    });

    return fail(
      res,
      err.statusCode && err.statusCode < 500
        ? err.message
        : "Something went wrong. Please try again later.",
      err.statusCode || 500,
    );
  }
});

module.exports = router;

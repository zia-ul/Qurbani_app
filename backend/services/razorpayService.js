const axios = require("axios");
const crypto = require("crypto");
const pool = require("../config/db");

const RAZORPAY_API_BASE = "https://api.razorpay.com/v1";

const parseBool = (value, fallback = false) => {
  if (value === undefined || value === null || value === "") {
    return fallback;
  }

  return ["1", "true", "yes", "on"].includes(String(value).toLowerCase());
};

const getConfig = () => ({
  keyId: process.env.RAZORPAY_KEY_ID,
  keySecret: process.env.RAZORPAY_KEY_SECRET,
  webhookSecret: process.env.RAZORPAY_WEBHOOK_SECRET,
  currency: process.env.RAZORPAY_CURRENCY || "INR",
  routeEnabled: parseBool(process.env.RAZORPAY_ROUTE_ENABLED, false),
  platformCommissionPercent: Number(process.env.PLATFORM_COMMISSION_PERCENT || 0),
});

const requireRazorpayKeys = () => {
  const config = getConfig();

  if (!config.keyId || !config.keySecret) {
    const error = new Error("Razorpay credentials are not configured");
    error.statusCode = 500;
    throw error;
  }

  return config;
};

const razorpayClient = () => {
  const config = requireRazorpayKeys();

  return axios.create({
    baseURL: RAZORPAY_API_BASE,
    auth: {
      username: config.keyId,
      password: config.keySecret,
    },
    timeout: 15000,
  });
};

const toPaise = (amount) => Math.round(Number(amount || 0) * 100);

const timingSafeEqualStrings = (left, right) => {
  const leftBuffer = Buffer.from(String(left || ""), "utf8");
  const rightBuffer = Buffer.from(String(right || ""), "utf8");

  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }

  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
};

const getRazorpayErrorMessage = (error) =>
  error.response?.data?.error?.description ||
  error.response?.data?.error?.reason ||
  error.response?.data?.message ||
  error.message;

async function loadOrderForPayment(orderId, connection = pool) {
  const [orders] = await connection.query(
    `
    SELECT
      o.*,
      u.razorpay_linked_account_id AS admin_razorpay_linked_account_id
    FROM orders o
    JOIN users u ON u.id = o.admin_id
    WHERE o.id = ?
    LIMIT 1
    `,
    [orderId],
  );

  if (!orders.length) {
    return null;
  }

  const order = orders[0];
  const [shareholders] = await connection.query(
    `
    SELECT id, price, payment_status, status
    FROM shareholder_details
    WHERE order_id = ?
    `,
    [orderId],
  );

  return {
    ...order,
    shareholders,
  };
}

function calculatePayableAmount(order) {
  const storedTotal = Number(order.total_amt || 0);

  if (storedTotal > 0) {
    return toPaise(storedTotal);
  }

  const shareTotal = (order.shareholders || []).reduce(
    (sum, shareholder) => sum + Number(shareholder.price || 0),
    0,
  );

  return toPaise(shareTotal);
}

function calculatePlatformCommission(order) {
  const totalAmountPaise = calculatePayableAmount(order);
  const percent = Number(getConfig().platformCommissionPercent || 0);

  if (!Number.isFinite(percent) || percent <= 0) {
    return 0;
  }

  return Math.round((totalAmountPaise * percent) / 100);
}

function calculateVendorAmount(order) {
  const totalAmountPaise = calculatePayableAmount(order);
  const platformCommissionPaise = calculatePlatformCommission(order);
  const vendorAmountPaise = totalAmountPaise - platformCommissionPaise;

  if (vendorAmountPaise <= 0) {
    const error = new Error("Vendor amount must be greater than zero");
    error.statusCode = 400;
    throw error;
  }

  return vendorAmountPaise;
}

function calculateRefundAmount(order) {
  return Number(order.razorpay_expected_amount || 0) || calculatePayableAmount(order);
}

function buildRazorpayOrderPayload({
  order,
  totalAmountPaise,
  platformCommissionPaise,
  vendorAmountPaise,
  vendorLinkedAccountId,
}) {
  const config = getConfig();
  const payload = {
    amount: totalAmountPaise,
    currency: config.currency,
    receipt: `order_${order.id}`,
    notes: {
      orderId: String(order.id),
    },
  };

  if (config.routeEnabled && vendorLinkedAccountId) {
    payload.transfers = [
      {
        account: vendorLinkedAccountId,
        amount: vendorAmountPaise,
        currency: config.currency,
        notes: {
          orderId: String(order.id),
          type: "vendor_share",
        },
      },
    ];

    payload.notes.platformCommission = String(platformCommissionPaise);
    payload.notes.vendorAmount = String(vendorAmountPaise);
  }

  return payload;
}

async function createRazorpayOrder({ orderId }) {
  const config = requireRazorpayKeys();
  const order = await loadOrderForPayment(orderId);

  if (!order) {
    const error = new Error("Order not found");
    error.statusCode = 404;
    throw error;
  }

  const totalAmountPaise = calculatePayableAmount(order);
  const platformCommissionPaise = calculatePlatformCommission(order);
  const vendorAmountPaise = calculateVendorAmount(order);
  const vendorLinkedAccountId =
    order.admin_razorpay_linked_account_id || order.vendor_linked_account_id;

  if (totalAmountPaise <= 0) {
    const error = new Error("Order amount is invalid");
    error.statusCode = 400;
    throw error;
  }

  if (config.routeEnabled && !vendorLinkedAccountId) {
    const error = new Error("Vendor payment setup incomplete.");
    error.statusCode = 400;
    throw error;
  }

  if (
    order.razorpay_order_id &&
    Number(order.razorpay_expected_amount || 0) === Number(totalAmountPaise)
  ) {
    return {
      key_id: config.keyId,
      razorpay_order_id: order.razorpay_order_id,
      amount: totalAmountPaise,
      currency: order.razorpay_currency || config.currency,
      orderId,
    };
  }

  const payload = buildRazorpayOrderPayload({
    order,
    totalAmountPaise,
    platformCommissionPaise,
    vendorAmountPaise,
    vendorLinkedAccountId,
  });

  const response = await razorpayClient().post("/orders", payload);
  const razorpayOrder = response.data;

  await pool.query(
    `
    UPDATE orders
    SET razorpay_order_id = ?,
        razorpay_expected_amount = ?,
        razorpay_currency = ?,
        razorpay_order_status = ?,
        vendor_linked_account_id = ?,
        platform_commission_amount = ?,
        vendor_amount = ?,
        payment_status = 2
    WHERE id = ?
    `,
    [
      razorpayOrder.id,
      totalAmountPaise,
      config.currency,
      razorpayOrder.status || "created",
      vendorLinkedAccountId || null,
      platformCommissionPaise,
      vendorAmountPaise,
      orderId,
    ],
  );

  return {
    key_id: config.keyId,
    razorpay_order_id: razorpayOrder.id,
    amount: totalAmountPaise,
    currency: config.currency,
    orderId,
  };
}

function verifyPaymentSignature({
  razorpay_order_id,
  razorpay_payment_id,
  razorpay_signature,
}) {
  const config = requireRazorpayKeys();
  const payload = `${razorpay_order_id}|${razorpay_payment_id}`;
  const expectedSignature = crypto
    .createHmac("sha256", config.keySecret)
    .update(payload)
    .digest("hex");

  return timingSafeEqualStrings(expectedSignature, razorpay_signature);
}

async function fetchPayment(razorpay_payment_id) {
  const response = await razorpayClient().get(`/payments/${razorpay_payment_id}`);
  return response.data;
}

async function fetchOrder(razorpay_order_id) {
  const response = await razorpayClient().get(`/orders/${razorpay_order_id}`);
  return response.data;
}

async function refundPayment({
  razorpay_payment_id,
  amountPaise,
  reverseAll = false,
  notes = {},
}) {
  const body = {
    amount: amountPaise,
    notes,
  };

  if (reverseAll) {
    body.reverse_all = true;
  }

  const response = await razorpayClient().post(
    `/payments/${razorpay_payment_id}/refund`,
    body,
  );

  return response.data;
}

async function reverseTransfer({ transferId, amountPaise, notes = {} }) {
  const response = await razorpayClient().post(
    `/transfers/${transferId}/reversals`,
    {
      amount: amountPaise,
      notes,
    },
  );

  return response.data;
}

function verifyWebhookSignature(rawBody, signature) {
  const config = getConfig();

  if (!config.webhookSecret) {
    const error = new Error("Razorpay webhook secret is not configured");
    error.statusCode = 500;
    throw error;
  }

  const expectedSignature = crypto
    .createHmac("sha256", config.webhookSecret)
    .update(rawBody)
    .digest("hex");

  return timingSafeEqualStrings(expectedSignature, signature);
}

module.exports = {
  calculatePayableAmount,
  calculatePlatformCommission,
  calculateVendorAmount,
  calculateRefundAmount,
  buildRazorpayOrderPayload,
  createRazorpayOrder,
  fetchOrder,
  fetchPayment,
  getConfig,
  getRazorpayErrorMessage,
  loadOrderForPayment,
  refundPayment,
  reverseTransfer,
  toPaise,
  verifyPaymentSignature,
  verifyWebhookSignature,
};

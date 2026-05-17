const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");

process.env.RAZORPAY_KEY_ID = "rzp_test_key";
process.env.RAZORPAY_KEY_SECRET = "secret";
process.env.RAZORPAY_CURRENCY = "INR";
process.env.PLATFORM_COMMISSION_PERCENT = "10";

const razorpayService = require("../services/razorpayService");

test("calculatePayableAmount uses stored order amount", () => {
  const amount = razorpayService.calculatePayableAmount({
    total_amt: "123.45",
    shareholders: [{ price: 999 }],
  });

  assert.equal(amount, 12345);
});

test("calculatePayableAmount falls back to shareholder prices", () => {
  const amount = razorpayService.calculatePayableAmount({
    total_amt: "0",
    shareholders: [{ price: "100.50" }, { price: "25" }],
  });

  assert.equal(amount, 12550);
});

test("commission and vendor amount are integer paise", () => {
  const order = { total_amt: "1000.00", shareholders: [] };

  assert.equal(razorpayService.calculatePlatformCommission(order), 10000);
  assert.equal(razorpayService.calculateVendorAmount(order), 90000);
});

test("verifyPaymentSignature accepts valid Razorpay checkout signature", () => {
  const razorpay_order_id = "order_123";
  const razorpay_payment_id = "pay_123";
  const razorpay_signature = crypto
    .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET)
    .update(`${razorpay_order_id}|${razorpay_payment_id}`)
    .digest("hex");

  assert.equal(
    razorpayService.verifyPaymentSignature({
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
    }),
    true,
  );
});

test("Route payload includes only vendor transfer amount", () => {
  process.env.RAZORPAY_ROUTE_ENABLED = "true";

  const payload = razorpayService.buildRazorpayOrderPayload({
    order: { id: 42 },
    totalAmountPaise: 100000,
    platformCommissionPaise: 10000,
    vendorAmountPaise: 90000,
    vendorLinkedAccountId: "acc_vendor",
  });

  assert.equal(payload.amount, 100000);
  assert.equal(payload.transfers.length, 1);
  assert.equal(payload.transfers[0].account, "acc_vendor");
  assert.equal(payload.transfers[0].amount, 90000);
  assert.equal(payload.notes.platformCommission, "10000");
});

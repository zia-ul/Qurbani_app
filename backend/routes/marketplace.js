const express = require("express");
const { v4: uuidv4 } = require("uuid");
const { fetchVerifiedAdmins } = require("../controllers/marketplaceAdmin");
const authMiddleware = require("../middleware/authmiddleware");
const supabase = require("../config/supabase");
const db = require("../config/db");
const logger = require("../middleware/logger");
const { saveVendorShareSetup, getVendorShareSetup } = require("../controllers/admin_share_setup");

const router = express.Router();

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

const toNumber = (value, fallback = 0) => {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
};

const buildEmptyShareUsage = () => ({
  used_shares: 0,
  day1_booked: 0,
  day2_booked: 0,
  day3_booked: 0,
});

const fetchPreferredShareSetup = async (adminId) => {
  const { data: rows, error } = await supabase
    .from("admin_share_setups")
    .select("*")
    .eq("admin_id", adminId);
  throwDb(error, "Failed to fetch share setup");

  if (!rows?.length) return null;

  const activeSetup = rows.find((row) => toNumber(row.is_active ?? 1, 1) === 1);
  const setup = activeSetup || rows[0];

  if (!activeSetup && rows.length > 1) {
    logger.warn("Using fallback share setup for marketplace admin", {
      adminId,
      setupId: setup.id,
    });
  }

  return {
    ...setup,
    late_booking_fee: toNumber(setup.late_booking_fee),
    delivery_fee: toNumber(setup.delivery_fee),
    free_delivery_threshold:
      setup.free_delivery_threshold == null ? null : toNumber(setup.free_delivery_threshold),
    currency: setup.currency || "USD",
    is_active: toNumber(setup.is_active ?? 1, 1),
    day1: toNumber(setup.day1),
    day2: toNumber(setup.day2),
    day3: toNumber(setup.day3),
  };
};

const fetchAdminAnimalsWithAvailability = async (adminId) => {
  const [{ data: animals, error: animalsError }, { data: shareholders, error: shareholdersError }] =
    await Promise.all([
      supabase
        .from("animals")
        .select("id,animal_type,price_per_share,shares,qurbani_day,qurbani_datetime,created_at")
        .eq("admin_id", adminId)
        .order("created_at", { ascending: false }),
      supabase.from("shareholder_details").select("id,animal_id"),
    ]);
  throwDb(animalsError, "Failed to fetch animals");
  throwDb(shareholdersError, "Failed to fetch assigned shares");

  const assignedByAnimalId = new Map();
  for (const shareholder of shareholders || []) {
    if (!shareholder.animal_id) continue;
    const key = String(shareholder.animal_id);
    assignedByAnimalId.set(key, (assignedByAnimalId.get(key) || 0) + 1);
  }

  return (animals || []).map((animal) => {
    const assignedShares = assignedByAnimalId.get(String(animal.id)) || 0;
    const shares = toNumber(animal.shares);

    return {
      ...animal,
      price_per_share: toNumber(animal.price_per_share),
      shares,
      assigned_shares: assignedShares,
      remaining_shares: Math.max(shares - assignedShares, 0),
    };
  });
};

const fetchShareUsage = async (adminId) => {
  const { data: orders, error: ordersError } = await supabase
    .from("orders")
    .select("id,status")
    .eq("admin_id", adminId);
  throwDb(ordersError, "Failed to fetch orders");

  const activeOrderIds = (orders || [])
    .filter((order) => Number(order.status ?? 0) !== 2)
    .map((order) => order.id)
    .filter(Boolean);

  if (!activeOrderIds.length) return buildEmptyShareUsage();

  const { data: shareholders, error: shareholdersError } = await supabase
    .from("shareholder_details")
    .select("qurbani_day")
    .in("order_id", activeOrderIds);
  throwDb(shareholdersError, "Failed to fetch shareholders");

  return (shareholders || []).reduce((usage, shareholder) => {
    usage.used_shares += 1;
    if (shareholder.qurbani_day === "Day 1") usage.day1_booked += 1;
    if (shareholder.qurbani_day === "Day 2") usage.day2_booked += 1;
    if (shareholder.qurbani_day === "Day 3") usage.day3_booked += 1;
    return usage;
  }, buildEmptyShareUsage());
};

router.post("/share-setup", authMiddleware, saveVendorShareSetup);
router.get("/share-setup", authMiddleware, getVendorShareSetup);

router.get("/:adminId/share-pricing", authMiddleware, async (req, res) => {
  const { adminId } = req.params;

  try {
    const pricing = await fetchPreferredShareSetup(adminId);
    if (!pricing) {
      return fail(res, "Order setup is not available for this admin yet.", 404);
    }

    const animals = await fetchAdminAnimalsWithAvailability(adminId);
    const firstAvailableAnimal =
      animals.find((animal) => animal.remaining_shares > 0) || animals[0];

    const { data: paymentSettings, error: paymentError } = await supabase
      .from("admin_payment_settings")
      .select("allow_cod,allow_online,cod_deadline")
      .eq("admin_id", adminId)
      .order("updated_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    throwDb(paymentError, "Failed to fetch payment settings");

    return ok(res, "Pricing fetched successfully", {
      ...pricing,
      price_per_share: firstAvailableAnimal?.price_per_share ?? 0,
      animals,
      allow_cod: paymentSettings?.allow_cod ?? 0,
      allow_online: paymentSettings?.allow_online ?? 0,
      cod_deadline: paymentSettings?.cod_deadline ?? null,
    });
  } catch (err) {
    logger.error("Failed to fetch admin pricing", { adminId, error: err.message, stack: err.stack });
    return fail(res, "Failed to load pricing");
  }
});

router.get("/:adminId/order-config", authMiddleware, async (req, res) => {
  const { adminId } = req.params;

  try {
    const setup = await fetchPreferredShareSetup(adminId);
    if (!setup) {
      return fail(res, "Order setup is not available for this admin yet.", 404);
    }

    const [usage, animals] = await Promise.all([
      fetchShareUsage(adminId),
      fetchAdminAnimalsWithAvailability(adminId),
    ]);

    const totalShares = animals.reduce((sum, animal) => sum + toNumber(animal.shares), 0);
    const day1 = toNumber(setup.day1);
    const day2 = toNumber(setup.day2);
    const day3 = toNumber(setup.day3);
    const usedShares = toNumber(usage.used_shares);
    const day1Booked = toNumber(usage.day1_booked);
    const day2Booked = toNumber(usage.day2_booked);
    const day3Booked = toNumber(usage.day3_booked);
    const remainingShares = Math.max(0, totalShares - usedShares);

    return ok(res, "Order config fetched successfully", {
      ...setup,
      total_shares: totalShares,
      day1,
      day2,
      day3,
      used_shares: usedShares,
      day1_booked: day1Booked,
      day2_booked: day2Booked,
      day3_booked: day3Booked,
      remaining_shares: remainingShares,
      day1_remaining: Math.max(0, day1 - day1Booked),
      day2_remaining: Math.max(0, day2 - day2Booked),
      day3_remaining: Math.max(0, day3 - day3Booked),
      animals,
    });
  } catch (err) {
    console.error("Error fetching admin order config", { adminId, error: err.message, stack: err.stack });
    logger.error("Failed to fetch admin order config", {
      adminId,
      error: err.message,
      stack: err.stack,
    });
    return fail(res, "Unable to load order setup right now. Please try again later.");
  }
});

router.post("/sync-delivery-requests", authMiddleware, async (req, res) => {
  const adminId = req.user.id;

  try {
    const { data: admin, error: adminError } = await supabase
      .from("users")
      .select("country,state,city")
      .eq("id", adminId)
      .eq("role", "admin")
      .maybeSingle();
    throwDb(adminError, "Failed to fetch admin location");

    if (!admin?.country) {
      return ok(res, "Admin has no location");
    }

    let deliveryQuery = supabase
      .from("users")
      .select("id,country,state,city")
      .eq("role", "delivery")
      .eq("country", admin.country);

    deliveryQuery =
      admin.state == null ? deliveryQuery.is("state", null) : deliveryQuery.eq("state", admin.state);
    deliveryQuery =
      admin.city == null ? deliveryQuery.is("city", null) : deliveryQuery.eq("city", admin.city);

    const { data: deliveryUsers, error: deliveryError } = await deliveryQuery;
    throwDb(deliveryError, "Failed to fetch delivery users");

    const { data: existing, error: existingError } = await supabase
      .from("delivery_requests")
      .select("delivery_user_id")
      .eq("admin_user_id", adminId);
    throwDb(existingError, "Failed to fetch existing delivery requests");

    const existingIds = new Set((existing || []).map((row) => String(row.delivery_user_id)));
    const inserts = (deliveryUsers || [])
      .filter((delivery) => !existingIds.has(String(delivery.id)))
      .map((delivery) => ({
        id: uuidv4(),
        delivery_user_id: delivery.id,
        admin_user_id: adminId,
        country: delivery.country,
        state: delivery.state,
        city: delivery.city,
      }));

    if (inserts.length) {
      const { error: insertError } = await supabase.from("delivery_requests").insert(inserts);
      throwDb(insertError, "Failed to sync delivery requests");
    }

    return ok(res, "Delivery requests synced", { inserted: inserts.length });
  } catch (err) {
    logger.error("Sync delivery requests failed", { adminId, error: err.message, stack: err.stack });
    return fail(res, "Sync failed");
  }
});

router.get("/verified", fetchVerifiedAdmins);

router.get("/dashboard-stats", authMiddleware, async (req, res) => {
  const adminId = req.user.id;
  logger.info("Fetching admin dashboard stats", { adminId });

  try {
    const [{ count: animals, error: animalError }, { count: orders, error: orderError }] =
      await Promise.all([
        supabase.from("animals").select("id", { count: "exact", head: true }).eq("admin_id", adminId),
        supabase.from("orders").select("id", { count: "exact", head: true }).eq("admin_id", adminId),
      ]);
    throwDb(animalError, "Failed to count animals");
    throwDb(orderError, "Failed to count orders");

    const { data: adminOrders, error: adminOrdersError } = await supabase
      .from("orders")
      .select("id")
      .eq("admin_id", adminId);
    throwDb(adminOrdersError, "Failed to fetch admin orders");

    const orderIds = (adminOrders || []).map((order) => order.id);
    const { count: requests, error: requestError } = orderIds.length
      ? await supabase
          .from("requests")
          .select("id", { count: "exact", head: true })
          .in("order_id", orderIds)
      : { count: 0, error: null };
    throwDb(requestError, "Failed to count requests");

    const stats = { animals: animals || 0, orders: orders || 0, requests: requests || 0 };
    logger.info("Admin dashboard stats fetched", { adminId, ...stats });
    return ok(res, "Dashboard stats fetched successfully", stats);
  } catch (err) {
    logger.error("Error fetching admin dashboard stats", {
      adminId,
      error: err.message,
      stack: err.stack,
    });
    return fail(res, "Something went wrong. Please try again later.");
  }
});

router.get("/:adminId/animals", authMiddleware, async (req, res) => {
  const { adminId } = req.params;

  try {
    const { data: admin, error: adminError } = await supabase
      .from("users")
      .select("currency")
      .eq("id", adminId)
      .eq("role", "admin")
      .maybeSingle();
    throwDb(adminError, "Failed to fetch admin");

    if (!admin) {
      return fail(res, "Admin not found", 404);
    }

    const animals = await fetchAdminAnimalsWithAvailability(adminId);
    return ok(res, "Animals fetched successfully", {
      admin_currency: admin.currency,
      animals,
    });
  } catch (err) {
    logger.error("Failed to fetch admin animals", {
      adminId,
      error: err.message,
      stack: err.stack,
    });
    return fail(res, "Something went wrong");
  }
});

router.get("/delivery-requests", authMiddleware, async (req, res) => {
  const adminId = req.user.id;

  try {
    const { data: admin, error: adminError } = await supabase
      .from("admins")
      .select("country,state,city")
      .eq("id", adminId)
      .maybeSingle();
    throwDb(adminError, "Failed to fetch admin location");

    if (!admin?.city) {
      return fail(res, "Admin location not set", 400);
    }

    const { data: deliveryRequests, error: requestError } = await supabase
      .from("delivery_requests")
      .select("id,user_id,country,state,city,status,created_at")
      .eq("status", "PENDING")
      .eq("country", admin.country)
      .eq("state", admin.state)
      .eq("city", admin.city)
      .order("created_at", { ascending: false });
    throwDb(requestError, "Failed to fetch delivery requests");

    const userIds = [...new Set((deliveryRequests || []).map((request) => request.user_id).filter(Boolean))];
    const { data: users, error: usersError } = userIds.length
      ? await supabase.from("users").select("id,name,phone").in("id", userIds)
      : { data: [], error: null };
    throwDb(usersError, "Failed to fetch delivery users");

    const usersById = new Map((users || []).map((user) => [String(user.id), user]));
    const requests = (deliveryRequests || []).map((request) => ({
      ...request,
      name: usersById.get(String(request.user_id))?.name ?? null,
      phone: usersById.get(String(request.user_id))?.phone ?? null,
    }));

    return ok(res, "Delivery requests fetched successfully", { requests });
  } catch (err) {
    logger.error("Fetch delivery requests error", { adminId, error: err.message, stack: err.stack });
    return fail(res, "Server error");
  }
});

router.put("/delivery-requests/:id", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  if (!["APPROVED", "REJECTED"].includes(status)) {
    return fail(res, "Invalid status value", 400);
  }

  try {
    const { data: request, error: fetchError } = await supabase
      .from("delivery_requests")
      .select("user_id,country,state,city")
      .eq("id", id)
      .maybeSingle();
    throwDb(fetchError, "Failed to fetch delivery request");

    if (!request) {
      return fail(res, "Request not found", 404);
    }

    const { error: updateError } = await supabase
      .from("delivery_requests")
      .update({ status })
      .eq("id", id);
    throwDb(updateError, "Failed to update delivery request");

    if (status === "APPROVED") {
      const { error: insertError } = await supabase.from("delivery_persons").insert({
        id: uuidv4(),
        user_id: request.user_id,
        country: request.country,
        state: request.state,
        city: request.city,
        created_at: new Date().toISOString(),
      });
      throwDb(insertError, "Failed to create delivery person");
    }

    return ok(res, `Delivery request ${status.toLowerCase()} successfully`);
  } catch (err) {
    logger.error("Update delivery request error", { id, status, error: err.message, stack: err.stack });
    return fail(res, "Server error");
  }
});

module.exports = router;

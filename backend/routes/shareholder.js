const express = require("express");
const router = express.Router();
const supabase = require("../config/supabase");
const authMiddleware = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");
const { sendPushNotification } = require("../utils/notification_service");

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

const fetchShareholderForAdmin = async (shareholderId, adminId, columns = "*") => {
  const { data: shareholder, error: shareholderError } = await supabase
    .from("shareholder_details")
    .select(columns)
    .eq("id", shareholderId)
    .maybeSingle();
  throwDb(shareholderError, "Failed to fetch shareholder");

  if (!shareholder) return null;

  const { data: order, error: orderError } = await supabase
    .from("orders")
    .select("id,user_id,admin_id,payment_status")
    .eq("id", shareholder.order_id)
    .eq("admin_id", adminId)
    .maybeSingle();
  throwDb(orderError, "Failed to fetch order");

  return order ? { ...shareholder, order } : null;
};

const fetchSubscriptionIds = async (userId) => {
  const { data: devices, error } = await supabase
    .from("user_devices")
    .select("subscription_id")
    .eq("user_id", userId)
    .not("subscription_id", "is", null);
  throwDb(error, "Failed to fetch user devices");
  return (devices || []).map((device) => device.subscription_id).filter(Boolean);
};

const pushToUser = async ({ userId, title, message, payload, logContext }) => {
  try {
    const subscriptionIds = await fetchSubscriptionIds(userId);
    if (subscriptionIds.length) {
      await sendPushNotification(subscriptionIds, title, message, payload);
    }
  } catch (pushErr) {
    logger.error(logContext || "Shareholder push failed", {
      userId,
      error: pushErr.message,
      stack: pushErr.stack,
    });
  }
};

router.post("/:id/payment", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const paymentStatus = Number(req.body.payment_status);
  const adminId = req.user.id;

  if (![0, 1, 2].includes(paymentStatus)) {
    return fail(res, "Invalid payment status", 400);
  }

  try {
    const shareholder = await fetchShareholderForAdmin(id, adminId, "id,order_id");
    if (!shareholder) {
      return fail(res, "Shareholder not found", 404);
    }

    const { error: updateError } = await supabase
      .from("shareholder_details")
      .update({ payment_status: paymentStatus })
      .eq("id", id);
    throwDb(updateError, "Failed to update shareholder payment");

    let paymentStatusLabel = "Pending";
    if (paymentStatus === 0) paymentStatusLabel = "Paid";
    if (paymentStatus === 1) paymentStatusLabel = "Unpaid";

    await pushToUser({
      userId: shareholder.order.user_id,
      title: "Payment Status Updated",
      message: `Your shareholder payment status is now '${paymentStatusLabel}'.`,
      payload: {
        type: "SHAREHOLDER_PAYMENT_UPDATED",
        orderId: shareholder.order_id,
        shareholderId: id,
        payment_status: paymentStatus,
      },
      logContext: "Shareholder payment push failed",
    });

    logger.info("Shareholder payment updated", {
      adminId,
      shareholderId: id,
      orderId: shareholder.order_id,
      paymentStatus,
    });

    return ok(res, "Payment updated successfully", {
      shareholder_id: id,
      payment_status: paymentStatus,
    });
  } catch (err) {
    logger.error("Shareholder payment route error", {
      message: err.message,
      stack: err.stack,
      adminId,
      shareholderId: id,
    });
    return fail(res, "Something went wrong");
  }
});

router.patch("/:id/status", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { status } = req.body;
  const adminId = req.user.id;
  const shareholderId = Number(id);
  const nextStatus = Number(status);

  if (![1, 2, 3, 4, 5, 6].includes(nextStatus)) {
    return fail(res, "Invalid status value", 400);
  }

  try {
    const shareholder = await fetchShareholderForAdmin(
      shareholderId,
      adminId,
      "id,order_id,status,payment_status,animal_id,share_number",
    );

    if (!shareholder) {
      return fail(res, "Shareholder not found", 404);
    }

    const currentStatus = Number(shareholder.status);
    const paymentStatus = Number(shareholder.payment_status);
    const hasAnimal = !!shareholder.animal_id;
    const hasShareNumber = shareholder.share_number !== null;
    const orderId = shareholder.order_id;

    if (currentStatus === 6) {
      return fail(res, "Cancelled shareholder status cannot be updated", 400);
    }

    if (nextStatus === 1) {
      if (paymentStatus !== 0) {
        return fail(res, "Payment must be marked as Paid before starting qurbani", 400);
      }
      if (!hasAnimal || !hasShareNumber) {
        return fail(res, "Animal and share number must be assigned first", 400);
      }
      if (currentStatus !== 0) {
        return fail(res, "Qurbani can only be started from Not started status", 400);
      }
    }

    if (nextStatus === 2 && currentStatus !== 1) {
      return fail(res, "Processing can only be set after Qurbani Started", 400);
    }

    if (nextStatus === 3 && ![1, 2].includes(currentStatus)) {
      return fail(res, "Meat can only be packaged after Qurbani Started or Processing", 400);
    }

    if (nextStatus === 4 && currentStatus !== 3) {
      return fail(res, "Order can only be sent for delivery after Meat Packaged", 400);
    }

    if (nextStatus === 5 && currentStatus !== 4) {
      return fail(res, "Order can only be delivered after Sent for delivery", 400);
    }

    if (nextStatus === 6 && currentStatus === 5) {
      return fail(res, "Delivered order cannot be cancelled", 400);
    }

    const { error: updateError } = await supabase
      .from("shareholder_details")
      .update({ status: nextStatus })
      .eq("id", shareholderId);
    throwDb(updateError, "Failed to update shareholder status");

    const { data: shareholderRows, error: statusError } = await supabase
      .from("shareholder_details")
      .select("status")
      .eq("order_id", orderId);
    throwDb(statusError, "Failed to fetch order shareholder statuses");

    const statuses = (shareholderRows || []).map((row) => Number(row.status));
    let nextOrderStatus = 0;
    if (statuses.length > 0 && statuses.every((s) => s === 5)) nextOrderStatus = 1;
    if (statuses.length > 0 && statuses.every((s) => s === 6)) nextOrderStatus = 2;

    const { error: orderUpdateError } = await supabase
      .from("orders")
      .update({ status: nextOrderStatus })
      .eq("id", orderId);
    throwDb(orderUpdateError, "Failed to update order status");

    logger.info("Shareholder status updated", {
      shareholderId,
      orderId,
      previousStatus: currentStatus,
      nextStatus,
      nextOrderStatus,
    });

    return ok(res, "Status updated successfully", {
      shareholder_status: nextStatus,
      order_status: nextOrderStatus,
    });
  } catch (err) {
    logger.error("Shareholder status route error", {
      message: err.message,
      stack: err.stack,
      adminId,
      shareholderId,
      requestedStatus: nextStatus,
    });
    return fail(res, "Something went wrong");
  }
});

router.post("/:id/assign-animal", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { animal_id, share_number } = req.body;
  const adminId = req.user.id;
  const shareholderId = Number(id);
  const animalId = Number(animal_id);
  const shareNumber = Number(share_number);

  if (!animalId || !shareNumber) {
    return fail(res, "animal_id and share_number are required", 400);
  }

  try {
    const shareholder = await fetchShareholderForAdmin(shareholderId, adminId, "*");
    if (!shareholder) {
      return fail(res, "Shareholder not found", 404);
    }

    if (Number(shareholder.payment_status) !== 0) {
      return fail(res, "Payment must be completed before assigning animal", 400);
    }

    const { data: animal, error: animalError } = await supabase
      .from("animals")
      .select("*")
      .eq("id", animalId)
      .eq("admin_id", adminId)
      .maybeSingle();
    throwDb(animalError, "Failed to fetch animal");

    if (!animal) {
      return fail(res, "Animal not found", 404);
    }

    const totalShares = Number(animal.shares || 0);
    const requestedAnimalType = (shareholder.animal_type || "").toString().trim();
    const selectedAnimalType = (animal.animal_type || "").toString().trim();

    if (
      requestedAnimalType &&
      selectedAnimalType.toLowerCase() !== requestedAnimalType.toLowerCase()
    ) {
      return fail(res, `Please select a ${requestedAnimalType} animal for this shareholder`, 400);
    }

    const { count: assignedCount, error: countError } = await supabase
      .from("shareholder_details")
      .select("id", { count: "exact", head: true })
      .eq("animal_id", animalId);
    throwDb(countError, "Failed to count assigned shares");

    if (totalShares - Number(assignedCount || 0) <= 0) {
      return fail(res, "No shares available", 400);
    }

    if (shareNumber < 1 || shareNumber > totalShares) {
      return fail(res, `Share number must be between 1 and ${totalShares}`, 400);
    }

    const { data: existingShare, error: existingError } = await supabase
      .from("shareholder_details")
      .select("id")
      .eq("animal_id", animalId)
      .eq("share_number", shareNumber)
      .neq("id", shareholderId)
      .limit(1)
      .maybeSingle();
    throwDb(existingError, "Failed to check share number");

    if (existingShare) {
      return fail(res, "This share number is already assigned", 400);
    }

    const { error: updateError } = await supabase
      .from("shareholder_details")
      .update({ animal_id: animalId, share_number: shareNumber })
      .eq("id", shareholderId);
    throwDb(updateError, "Failed to assign animal");

    await pushToUser({
      userId: shareholder.order.user_id,
      title: "Animal Assigned",
      message: "Your Qurbani animal has been successfully assigned.",
      payload: {
        type: "SHAREHOLDER_ANIMAL_ASSIGNED",
        orderId: shareholder.order_id,
        shareholderId,
        animal_id: animalId,
        share_number: shareNumber,
      },
      logContext: "Assign animal push failed",
    });

    logger.info("Shareholder animal assigned", {
      adminId,
      shareholderId,
      animalId,
      shareNumber,
    });

    return ok(res, "Animal assigned successfully", {
      shareholder_id: shareholderId,
      animal_id: animalId,
      share_number: shareNumber,
    });
  } catch (err) {
    logger.error("Assign animal route error", {
      message: err.message,
      stack: err.stack,
      adminId,
      shareholderId,
      animalId,
    });
    return fail(res, "Something went wrong");
  }
});

router.post("/:id/schedule", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { qurbani_datetime } = req.body;

  try {
    const { data: shareholder, error: shareholderError } = await supabase
      .from("shareholder_details")
      .select("animal_id,order_id")
      .eq("id", id)
      .maybeSingle();
    throwDb(shareholderError, "Failed to fetch shareholder");

    if (!shareholder) {
      return fail(res, "Shareholder not found", 404);
    }

    if (!shareholder.animal_id) {
      return fail(res, "Assign animal first before scheduling", 400);
    }

    const { error: updateError } = await supabase
      .from("shareholder_details")
      .update({ qurbani_datetime, processing_status: "completed" })
      .eq("id", id);
    throwDb(updateError, "Failed to schedule qurbani");

    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("user_id")
      .eq("id", shareholder.order_id)
      .maybeSingle();
    throwDb(orderError, "Failed to fetch order");

    if (order?.user_id) {
      await pushToUser({
        userId: order.user_id,
        title: "Qurbani Scheduled",
        message: "Your Qurbani has been successfully completed.",
        payload: {
          type: "SHAREHOLDER_QURBANI_COMPLETED",
          orderId: shareholder.order_id,
          shareholderId: id,
          qurbani_datetime,
        },
        logContext: "Schedule push failed",
      });
    }

    logger.info("Shareholder qurbani scheduled", {
      shareholderId: id,
      orderId: shareholder.order_id,
      qurbani_datetime,
    });

    return ok(res, "Qurbani scheduled successfully", {
      shareholder_id: id,
      qurbani_datetime,
    });
  } catch (err) {
    logger.error("Schedule route error", {
      message: err.message,
      stack: err.stack,
      shareholderId: id,
    });
    return fail(res, "Something went wrong");
  }
});

router.post("/:shareholderId/delivery-status", authMiddleware, async (req, res) => {
  const { shareholderId } = req.params;
  const { delivery_status } = req.body;
  const allowedStatuses = ["pending", "sent", "delivered"];

  if (!allowedStatuses.includes(delivery_status)) {
    return fail(res, "Invalid delivery status", 400);
  }

  try {
    const { data: shareholder, error: shareholderError } = await supabase
      .from("shareholder_details")
      .select("id,order_id")
      .eq("id", shareholderId)
      .maybeSingle();
    throwDb(shareholderError, "Failed to fetch shareholder");

    if (!shareholder) {
      return fail(res, "Shareholder not found", 404);
    }

    const { error: updateError } = await supabase
      .from("shareholder_details")
      .update({ delivery_status, processing_status: "completed" })
      .eq("id", shareholderId);
    throwDb(updateError, "Failed to update delivery status");

    const [{ data: allShareholders, error: allError }, { data: order, error: orderError }] =
      await Promise.all([
        supabase
          .from("shareholder_details")
          .select("delivery_status")
          .eq("order_id", shareholder.order_id),
        supabase
          .from("orders")
          .select("payment_status,user_id")
          .eq("id", shareholder.order_id)
          .maybeSingle(),
      ]);
    throwDb(allError, "Failed to fetch order shareholders");
    throwDb(orderError, "Failed to fetch order");

    const allDelivered = (allShareholders || []).every((s) => s.delivery_status === "delivered");
    const isPaid = Number(order?.payment_status) === 0 || order?.payment_status === "paid";
    let orderCompleted = false;

    if (allDelivered && isPaid) {
      const { error: orderUpdateError } = await supabase
        .from("orders")
        .update({ status: 1 })
        .eq("id", shareholder.order_id);
      throwDb(orderUpdateError, "Failed to mark order completed");
      orderCompleted = true;
      logger.info("Order auto-completed", { orderId: shareholder.order_id });
    }

    if (order?.user_id) {
      if (delivery_status === "sent") {
        await pushToUser({
          userId: order.user_id,
          title: "On The Way",
          message: "Your Qurbani meat has been sent for delivery.",
          payload: { type: "DELIVERY_SENT", orderId: shareholder.order_id, shareholderId },
          logContext: "Delivery notification failed",
        });
      }

      if (delivery_status === "delivered") {
        await pushToUser({
          userId: order.user_id,
          title: "Delivered Successfully",
          message: "Your Qurbani meat has been delivered.",
          payload: { type: "DELIVERY_COMPLETED", orderId: shareholder.order_id, shareholderId },
          logContext: "Delivery notification failed",
        });
      }

      if (orderCompleted) {
        await pushToUser({
          userId: order.user_id,
          title: "Order Completed",
          message: "Your entire Qurbani order has been completed successfully.",
          payload: { type: "ORDER_COMPLETED", orderId: shareholder.order_id },
          logContext: "Delivery notification failed",
        });
      }
    }

    logger.info("Shareholder delivery status updated", {
      shareholderId,
      orderId: shareholder.order_id,
      delivery_status,
      orderCompleted,
    });

    return ok(res, "Delivery status updated successfully", {
      shareholder_id: shareholderId,
      delivery_status,
      order_completed: orderCompleted,
    });
  } catch (err) {
    logger.error("Delivery status update failed", {
      message: err.message,
      stack: err.stack,
      shareholderId,
    });
    return fail(res, "Something went wrong");
  }
});

module.exports = router;

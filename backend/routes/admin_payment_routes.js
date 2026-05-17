const express = require("express");
const QRCode = require("qrcode");

const router = express.Router();

const auth = require("../middleware/authmiddleware");

const controller = require(
  "../controllers/admin_payment_settings"
);

const supabase = require(
  "../config/db"
);

// ==============================
// Admin Payment Settings
// ==============================

router.get(
  "/payment-settings",
  auth,
  controller.getMyPaymentSettings
);

router.put(
  "/payment-settings",
  auth,
  controller.updateMyPaymentSettings
);

// ==============================
// Generate QR Code for Animal
// ==============================

router.post(
  "/animals/:id/qrcode",
  auth,
  async (req, res) => {

    try {

      const { id } = req.params;

      const qrData = `animal:${id}`;

      const qrCode =
        await QRCode.toDataURL(qrData);

      const { error } = await supabase
        .from("animals")
        .update({
          qr_code: qrCode,
        })
        .eq("id", id);

      if (error) {
        throw new Error(error.message);
      }

      return res.json({
        qr_code: qrCode,
      });

    } catch (err) {

      console.error(
        "QR code generation failed:",
        err.message
      );

      return res.status(500).json({
        message:
          "Failed to generate QR code",
      });
    }
  }
);

// ==============================
// Get Animal Shareholders/Orders
// ==============================

router.get(
  "/animals/:animalId/orders",
  auth,
  async (req, res) => {

    try {

      const { animalId } = req.params;

      // Fetch shareholder details
      const {
        data: shareholders,
        error: shareholderError,
      } = await supabase
        .from("shareholder_details")
        .select(`
          id,
          order_id,
          shareholder_name,
          guardian_name,
          qurbani_day,
          processing_status,
          delivery_status,
          payment_status,
          created_at
        `)
        .eq("animal_id", animalId)
        .order("created_at", {
          ascending: false,
        });

      if (shareholderError) {
        throw new Error(
          shareholderError.message
        );
      }

      if (!shareholders?.length) {
        return res.json([]);
      }

      // Get order ids
      const orderIds = shareholders.map(
        (s) => s.order_id
      );

      // Fetch related orders
      const {
        data: orders,
        error: ordersError,
      } = await supabase
        .from("orders")
        .select(`
          id,
          payment_method,
          created_at,
          user_id
        `)
        .in("id", orderIds);

      if (ordersError) {
        throw new Error(
          ordersError.message
        );
      }

      // Get user ids
      const userIds = orders.map(
        (o) => o.user_id
      );

      // Fetch users
      const {
        data: users,
        error: usersError,
      } = await supabase
        .from("users")
        .select(`
          id,
          name
        `)
        .in("id", userIds);

      if (usersError) {
        throw new Error(
          usersError.message
        );
      }

      // Create lookup maps
      const ordersMap = {};
      const usersMap = {};

      orders.forEach((order) => {
        ordersMap[order.id] = order;
      });

      users.forEach((user) => {
        usersMap[user.id] = user;
      });

      // Combine all data
      const rows = shareholders.map(
        (s) => {

          const order =
            ordersMap[s.order_id] || {};

          const user =
            usersMap[order.user_id] || {};

          return {
            shareholder_id: s.id,
            order_id: s.order_id,
            shareholder_name:
              s.shareholder_name,
            guardian_name:
              s.guardian_name,
            qurbani_day:
              s.qurbani_day,
            processing_status:
              s.processing_status,
            delivery_status:
              s.delivery_status,
            payment_status:
              s.payment_status,
            created_at:
              s.created_at,

            payment_method:
              order.payment_method || null,

            order_created_at:
              order.created_at || null,

            user_name:
              user.name || null,
          };
        }
      );

      console.log(
        "Fetched orders for animal",
        {
          animalId,
          count: rows.length,
        }
      );

      return res.json(rows);

    } catch (err) {

      console.error(err);

      return res.status(500).json({
        message:
          "Failed to fetch animal shareholders",
      });
    }
  }
);

module.exports = router;
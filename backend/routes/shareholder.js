const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");

router.post("/:id/payment", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { payment_status } = req.body;

  if (!["pending", "paid", "unpaid"].includes(payment_status)) {
    return res.status(400).json({ message: "Invalid payment status" });
  }

  try {
    const [rows] = await pool.execute(
      "SELECT * FROM shareholder_details WHERE id = ?",
      [id],
    );

    if (!rows.length) {
      return res.status(404).json({ message: "Shareholder not found" });
    }

    await pool.execute(
      `UPDATE shareholder_details
         SET payment_status = ?
         WHERE id = ?`,
      [payment_status, id],
    );

    res.json({ message: "Payment updated successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Something went wrong" });
  }
});

router.post("/:id/assign-animal", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { animal_id } = req.body;

  try {
    // 1️⃣ Check shareholder
    const [shareholders] = await pool.execute(
      "SELECT * FROM shareholder_details WHERE id = ?",
      [id],
    );

    if (shareholders[0].payment_status !== "paid") {
      return res
        .status(400)
        .json({ message: "Payment must be completed before assigning animal" });
    }

    if (!shareholders.length) {
      return res.status(404).json({ message: "Shareholder not found" });
    }

    // 2️⃣ Check animal
    const [animals] = await pool.execute("SELECT * FROM animals WHERE id = ?", [
      animal_id,
    ]);

    if (!animals.length) {
      return res.status(404).json({ message: "Animal not found" });
    }

    const animal = animals[0];

    if (animal.remaining_shares <= 0) {
      return res.status(400).json({ message: "No shares available" });
    }

    // Count already assigned shares for this animal
    const [countResult] = await pool.execute(
      `SELECT COUNT(*) as count 
   FROM shareholder_details 
   WHERE animal_id = ?`,
      [animal_id],
    );

    const shareNumber = countResult[0].count + 1;

    // 4️⃣ Update shareholder
    await pool.execute(
      `UPDATE shareholder_details
         SET animal_id = ?, share_number = ?, processing_status = 'confirmed'
         WHERE id = ?`,
      [animal_id, shareNumber, id],
    );

    // 5️⃣ Decrease animal remaining shares
    // await pool.execute(
    //   `UPDATE animals
    //      SET remaining_shares = remaining_shares - 1
    //      WHERE id = ?`,
    //   [animal_id],
    // );

    res.json({ message: "Animal assigned successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Something went wrong" });
  }
});

router.post("/:id/schedule", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { qurbani_datetime } = req.body;

  try {
    const [rows] = await pool.execute(
      "SELECT animal_id FROM shareholder_details WHERE id = ?",
      [id],
    );

    if (!rows.length) {
      return res.status(404).json({ message: "Shareholder not found" });
    }

    if (!rows[0].animal_id) {
      return res
        .status(400)
        .json({ message: "Assign animal first before scheduling" });
    }

    await pool.execute(
      `UPDATE shareholder_details
         SET qurbani_datetime = ?, processing_status = 'completed'
         WHERE id = ?`,
      [qurbani_datetime, id],
    );

    res.json({ message: "Qurbani scheduled successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Something went wrong" });
  }
});


router.post("/:shareholderId/delivery-status", authMiddleware, async (req, res) => {
  const { shareholderId } = req.params;
  const { delivery_status } = req.body;

  const allowedStatuses = ["pending", "sent", "delivered"];

  if (!allowedStatuses.includes(delivery_status)) {
    return res.status(400).json({ message: "Invalid delivery status" });
  }

  try {
    await pool.execute(
      `
      UPDATE shareholder_details
      SET delivery_status = ?,
      processing_status = 'completed'
      WHERE id = ?
      `,
      [delivery_status, shareholderId]
    );

    res.json({ message: "Delivery status updated successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Something went wrong" });
  }
});


router.post("/:id/assign-delivery", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { delivery_person_id } = req.body;

  try {
    const [shareholders] = await pool.execute(
      "SELECT * FROM shareholder_details WHERE id = ?",
      [id],
    );

    if (!shareholders.length) {
      return res.status(404).json({ message: "Shareholder not found" });
    }

    // Optional: validate delivery person
    const [deliveryUser] = await pool.execute(
      "SELECT id FROM users WHERE id = ? AND role = 'delivery'",
      [delivery_person_id],
    );

    if (!deliveryUser.length) {
      return res.status(400).json({ message: "Invalid delivery person" });
    }

    await pool.execute(
      `UPDATE shareholder_details
         SET delivery_person_id = ?, delivery_status = 'assigned'
         WHERE id = ?`,
      [delivery_person_id, id],
    );

    res.json({ message: "Delivery assigned successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Something went wrong" });
  }
});

router.patch("/:id/status", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { delivery_status } = req.body;

  try {
    await pool.execute(
      `UPDATE shareholder_details
         SET delivery_status = ?
         WHERE id = ?`,
      [delivery_status, id],
    );

    res.json({ message: "Status updated successfully" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Something went wrong" });
  }
});

module.exports = router;

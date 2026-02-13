const express = require("express");
const router = express.Router();
const pool = require("../config/db");
const authMiddleware = require("../middleware/authmiddleware");
const logger = require("../middleware/logger");

/**
 * @swagger
 * /api/shareholders/{id}/payment:
 *   post:
 *     summary: Update shareholder payment status
 *     description: Admin updates the payment status of a shareholder.
 *     tags: [Shareholders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Shareholder ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - payment_status
 *             properties:
 *               payment_status:
 *                 type: string
 *                 enum: [pending, paid, unpaid]
 *                 example: paid
 *     responses:
 *       200:
 *         description: Payment updated successfully
 *       400:
 *         description: Invalid payment status
 *       404:
 *         description: Shareholder not found
 *       500:
 *         description: Something went wrong
 */

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
    logger.error("Route error", {
      message: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Something went wrong" });
  }
});

/**
 * @swagger
 * /api/shareholders/{id}/assign-animal:
 *   post:
 *     summary: Assign animal to shareholder
 *     description: Assigns an animal to a paid shareholder and generates share number.
 *     tags: [Shareholders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - animal_id
 *             properties:
 *               animal_id:
 *                 type: integer
 *                 example: 5
 *     responses:
 *       200:
 *         description: Animal assigned successfully
 *       400:
 *         description: Payment incomplete or no shares available
 *       404:
 *         description: Shareholder or Animal not found
 *       500:
 *         description: Something went wrong
 */

router.post("/:id/assign-animal", authMiddleware, async (req, res) => {
  const { id } = req.params;
  const { animal_id } = req.body;

  try {
    // Check shareholder
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

    // Check animal
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

    // Update shareholder
    await pool.execute(
      `UPDATE shareholder_details
         SET animal_id = ?, share_number = ?, processing_status = 'confirmed'
         WHERE id = ?`,
      [animal_id, shareNumber, id],
    );

    // Decrease animal remaining shares
    // await pool.execute(
    //   `UPDATE animals
    //      SET remaining_shares = remaining_shares - 1
    //      WHERE id = ?`,
    //   [animal_id],
    // );

    res.json({ message: "Animal assigned successfully" });
  } catch (err) {
    logger.error("Route error", {
      message: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Something went wrong" });
  }
});

/**
 * @swagger
 * /api/shareholders/{id}/schedule:
 *   post:
 *     summary: Schedule Qurbani date and time
 *     description: Sets the Qurbani date/time for a shareholder after animal assignment.
 *     tags: [Shareholders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - qurbani_datetime
 *             properties:
 *               qurbani_datetime:
 *                 type: string
 *                 format: date-time
 *                 example: 2026-06-17T10:30:00Z
 *     responses:
 *       200:
 *         description: Qurbani scheduled successfully
 *       400:
 *         description: Animal not assigned
 *       404:
 *         description: Shareholder not found
 *       500:
 *         description: Something went wrong
 */

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
    logger.error("Route error", {
      message: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Something went wrong" });
  }
});

/**
 * @swagger
 * /api/shareholders/{shareholderId}/delivery-status:
 *   post:
 *     summary: Update delivery status
 *     description: Updates delivery status for a shareholder.
 *     tags: [Shareholders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: shareholderId
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - delivery_status
 *             properties:
 *               delivery_status:
 *                 type: string
 *                 enum: [pending, sent, delivered]
 *                 example: delivered
 *     responses:
 *       200:
 *         description: Delivery status updated successfully
 *       400:
 *         description: Invalid delivery status
 *       500:
 *         description: Something went wrong
 */

router.post(
  "/:shareholderId/delivery-status",
  authMiddleware,
  async (req, res) => {
    const { shareholderId } = req.params;
    const { delivery_status } = req.body;

    const allowedStatuses = ["pending", "sent", "delivered"];

    if (!allowedStatuses.includes(delivery_status)) {
      return res.status(400).json({ message: "Invalid delivery status" });
    }

    const connection = await pool.getConnection();

    try {
      await connection.beginTransaction();

      // Update shareholder delivery + processing
      await connection.execute(
        `
        UPDATE shareholder_details
        SET delivery_status = ?,
            processing_status = 'completed'
        WHERE id = ?
        `,
        [delivery_status, shareholderId]
      );

      // Get order_id of this shareholder
      const [shareholderRows] = await connection.execute(
        `SELECT order_id FROM shareholder_details WHERE id = ?`,
        [shareholderId]
      );

      if (!shareholderRows.length) {
        throw new Error("Shareholder not found");
      }

      const orderId = shareholderRows[0].order_id;

      // Check if ALL shareholders delivered
      const [allShareholders] = await connection.execute(
        `
        SELECT delivery_status
        FROM shareholder_details
        WHERE order_id = ?
        `,
        [orderId]
      );

      const allDelivered = allShareholders.every(
        (s) => s.delivery_status === "delivered"
      );

      // Check order payment status
      const [orderRows] = await connection.execute(
        `SELECT payment_status FROM orders WHERE id = ?`,
        [orderId]
      );

      const isPaid =
        orderRows.length &&
        orderRows[0].payment_status === "paid";

      // If fully delivered + paid → mark order completed
      if (allDelivered && isPaid) {
        await connection.execute(
          `
          UPDATE orders
          SET status = 'completed'
          WHERE id = ?
          `,
          [orderId]
        );

        logger.info("Order auto-completed", { orderId });
      }

      await connection.commit();

      res.json({
        message: "Delivery status updated successfully",
      });

    } catch (err) {
      await connection.rollback();

      logger.error("Delivery status update failed", {
        message: err.message,
        stack: err.stack,
      });

      res.status(500).json({ message: "Something went wrong" });
    } finally {
      connection.release();
    }
  }
);


/**
 * @swagger
 * /api/shareholders/{id}/status:
 *   patch:
 *     summary: Update delivery status (quick update)
 *     description: Updates only the delivery status field.
 *     tags: [Shareholders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - delivery_status
 *             properties:
 *               delivery_status:
 *                 type: string
 *                 example: sent
 *     responses:
 *       200:
 *         description: Status updated successfully
 *       500:
 *         description: Something went wrong
 */

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
    logger.error("Route error", {
      message: err.message,
      stack: err.stack,
    });

    res.status(500).json({ message: "Something went wrong" });
  }
});

module.exports = router;

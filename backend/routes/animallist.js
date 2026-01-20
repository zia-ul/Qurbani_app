
const express = require("express");
const router = express.Router();
const isAdmin = require("../middleware/isAdmin");
const authMiddleware = require("../middleware/authmiddleware");

const {
  getAnimals,
  deleteAnimal,
  updateAnimal,
  getAnimalById,
} = require("../controllers/animal_list");

const pool = require("../config/db");

/**
 * @swagger
 * /api/animals:
 *   get:
 *     summary: Get animals for logged-in admin
 *     tags: [Animals]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of animals fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin access required
 *       500:
 *         description: Server error
 */

// Get animals for logged-in admin
router.get("/", authMiddleware, isAdmin, getAnimals);

/**
 * @swagger
 * /api/animals/{id}:
 *   delete:
 *     summary: Delete an animal (admin only)
 *     tags: [Animals]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Animal ID
 *     responses:
 *       200:
 *         description: Animal deleted successfully
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin access required
 *       404:
 *         description: Animal not found
 *       500:
 *         description: Server error
 */


// Delete animal by ID (admin only)
router.delete("/:id", authMiddleware, isAdmin, deleteAnimal);

/**
 * @swagger
 * /api/animals/{id}:
 *   put:
 *     summary: Update animal details (admin only)
 *     tags: [Animals]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Animal ID
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               animalType:
 *                 type: string
 *               breed:
 *                 type: string
 *               price:
 *                 type: number
 *               description:
 *                 type: string
 *               age:
 *                 type: string
 *               weight:
 *                 type: string
 *     responses:
 *       200:
 *         description: Animal updated successfully
 *       400:
 *         description: Invalid request data
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin access required
 *       404:
 *         description: Animal not found
 *       500:
 *         description: Server error
 */


//update animal - update data after edit
router.put("/:id", authMiddleware, isAdmin, updateAnimal);

/**
 * @swagger
 * /api/animals/{id}:
 *   get:
 *     summary: Get animal details by ID (admin only)
 *     tags: [Animals]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: Animal ID
 *     responses:
 *       200:
 *         description: Animal details fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin access required
 *       404:
 *         description: Animal not found
 *       500:
 *         description: Server error
 */


//fetch animal details - animal edit
router.get("/:id", authMiddleware, isAdmin, getAnimalById);

/**
 * @swagger
 * /api/animals/{animalId}/orders:
 *   get:
 *     summary: Get orders for a specific animal (admin only)
 *     tags: [Animals, Orders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: animalId
 *         required: true
 *         schema:
 *           type: integer
 *         description: Animal ID
 *     responses:
 *       200:
 *         description: Orders fetched successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 orders:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       order_id:
 *                         type: integer
 *                       user_id:
 *                         type: integer
 *                       user_name:
 *                         type: string
 *                       processing_status:
 *                         type: string
 *                       delivery_status:
 *                         type: string
 *                       qurbani_day:
 *                         type: string
 *                       price:
 *                         type: number
 *                       created_at:
 *                         type: string
 *                         format: date-time
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin access required
 *       500:
 *         description: Server error
 */


// GET /api/animals/:animalId/orders - Fetch orders for an animal (admin only)
router.get("/:animalId/orders", authMiddleware, async (req, res) => {
  const { animalId } = req.params;
  const adminId = req.user.id; 

  try {
    const [orders] = await pool.execute(
      `SELECT 
      o.id AS order_id,
      o.user_id,
      o.processing_status,
      o.delivery_status,
      o.created_at,
      u.name AS user_name,
      s.shareholder_name,
      s.guardian_name,
      s.qurbani_day,
      s.price
   FROM orders o
   JOIN users u ON o.user_id = u.id
   JOIN order_shareholders s ON s.order_id = o.id
   WHERE s.animal_id = ? AND o.admin_id = ?
   ORDER BY o.created_at DESC`,
      [animalId, adminId]
    );

    res.json({ orders });
  } catch (err) {
    console.error("Error fetching animal orders:", err);
    res.status(500).json({ message: "Internal server error" });
  }
});

module.exports = router;

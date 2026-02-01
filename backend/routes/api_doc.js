// AUTH

/**
 * @swagger
 * /api/auth/register:
 *   post:
 *     summary: Register a new user
 *     description: >
 *       Registers a new user account. Validates input, hashes the password,
 *       stores the user in the database, and sends a verification email.
 *       Admin registrations require approval by a super admin.
 *     tags:
 *       - Auth
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *               - email
 *               - password
 *               - phone
 *               - country_code
 *               - country_iso
 *               - role
 *             properties:
 *               name:
 *                 type: string
 *                 example: John Doe
 *               email:
 *                 type: string
 *                 format: email
 *                 example: john@example.com
 *               password:
 *                 type: string
 *                 format: password
 *                 example: password123
 *               phone:
 *                 type: string
 *                 example: "3001234567"
 *               country_code:
 *                 type: string
 *                 example: "+92"
 *               country_iso:
 *                 type: string
 *                 example: PK
 *               role:
 *                 type: string
 *                 enum: [user, admin, delivery]
 *               address:
 *                 type: string
 *                 example: Main Street
 *               gender:
 *                 type: string
 *                 example: male
 *               currency:
 *                 type: string
 *                 example: USD
 *               city:
 *                 type: string
 *                 example: Lahore
 *     responses:
 *       201:
 *         description: Registration successful
 *       400:
 *         description: Invalid input
 *       409:
 *         description: Email already registered
 *       500:
 *         description: Server error
 */

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Login user
 *     description: >
 *       Authenticates a user using email and password.
 *       Returns a JWT token upon successful authentication.
 *     tags:
 *       - Auth
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *                 example: john@example.com
 *               password:
 *                 type: string
 *                 format: password
 *                 example: password123
 *     responses:
 *       200:
 *         description: Login successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 token:
 *                   type: string
 *                 user:
 *                   type: object
 *                   properties:
 *                     id:
 *                       type: string
 *                       format: uuid
 *                     name:
 *                       type: string
 *                     email:
 *                       type: string
 *                     role:
 *                       type: string
 *                     city:
 *                       type: string
 *                     currency:
 *                       type: string
 *                     admin_verification_status:
 *                       type: string
 *       401:
 *         description: Incorrect password
 *       403:
 *         description: Email not verified or account inactive
 *       404:
 *         description: Unregistered email
 *       500:
 *         description: Server error
 */



// Admin Slot Schedule + Delivery Boy assignment

/**
 * @swagger
 * /orders/{orderId}/delivery:
 *   put:
 *     summary: Assign delivery person to order
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: orderId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - delivery_person_id
 *             properties:
 *               delivery_person_id:
 *                 type: string
 *     responses:
 *       200:
 *         description: Delivery assigned
 */

/**
 * @swagger
 * /orders/{orderId}/delivery-boy/{deliveryBoyId}:
 *   get:
 *     summary: Get assigned delivery boy details
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: orderId
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: deliveryBoyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Delivery boy details
 *       404:
 *         description: Not found
 */

/**
 * @swagger
 * /orders/{orderId}/mark-paid:
 *   put:
 *     summary: Mark COD order as paid
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: orderId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Order marked as paid
 */


/**
 * @swagger
 * /orders/{orderId}/schedule:
 *   put:
 *     summary: Schedule qurbani time
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - qurbani_time
 *             properties:
 *               qurbani_time:
 *                 type: string
 *                 example: 2026-06-17 10:00:00
 *     responses:
 *       200:
 *         description: Scheduled successfully
 */

/**
 * @swagger
 * /orders/{orderId}/cancel:
 *   put:
 *     summary: Cancel order (within 24 hours)
 *     tags: [Orders]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: orderId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Order cancelled
 *       400:
 *         description: Cannot cancel order
 */

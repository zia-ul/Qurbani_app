const express = require('express');
const router = express.Router();

const {
  getDeliveryOrders,
} = require('../controllers/animal_list');


const jwt = require('jsonwebtoken');

const verifyToken = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    return res.status(401).json({ message: 'No token provided' });
  }

  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    return res.status(401).json({ message: 'Invalid token' });
  }
};

const isSuperAdmin = (req, res, next) => {
  if (req.user.role !== 'super_admin') {
    return res.status(403).json({ message: 'Access denied' });
  }
  next();
};


router.get(
  '/delivery/:deliveryPersonId/orders',
  verifyToken,
  isSuperAdmin,
  getDeliveryOrders
);

module.exports = router;

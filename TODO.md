# TODO - Status Change Push Notifications Implementation

## Task: Implement push notifications when admin changes order status

### Plan:
- [x] **backend/routes/orders.js**
  - [x] Add notification triggers when admin updates order statuses (processing_status, delivery_status, payment_status)
  - [x] Include payment deadline/date notifications
- [x] **backend/controllers/admin_order.js**
  - [x] Add notification triggers for all status changes
  - [x] Include COD deadline notifications
  - [x] Notify delivery person when assigned

### Status Changes to Notify Users:
1. **processing_status**: pending → confirmed → processing → completed → cancelled
2. **delivery_status**: pending → sent → delivered → cancelled
3. **payment_status**: unpaid/pending → paid → failed → refunded
4. **payment deadline**: When admin sets/updates COD deadline
5. **delivery assignment**: When delivery person is assigned

### Implementation Completed:
1. ✅ Imported createNotification in orders.js and admin_order.js
2. ✅ Fetch user_id with the order details
3. ✅ Added notification logic after status updates
4. ✅ Handled different status change scenarios with appropriate messages
5. ✅ Added notification types: processing_status, delivery_status, payment_status, payment_deadline, delivery_assigned

### Notification Types Implemented:
| Type | Title Examples | Body Content |
|------|---------------|--------------|
| processing_status | ✅ Order Confirmed, 🔨 Order Processing, 🎉 Order Completed | Order status updates |
| delivery_status | 📦 Delivery Pending, 🚚 Order Out for Delivery, ✅ Order Delivered | Delivery tracking |
| payment_status | 💰 Payment Received, ⏳ Payment Pending, ❌ Payment Failed | Payment updates |
| payment_deadline | 📅 Payment Deadline Updated | COD deadline reminders |
| delivery_assigned | 📦 New Delivery Assigned | Delivery person notifications |

### Progress:
- [x] Created TODO.md
- [x] Implementing status change notifications in orders.js
- [x] Implementing status change notifications in admin_order.js
- [ ] Testing the implementation

### Files Modified:
- `backend/routes/orders.js` - Added comprehensive notification triggers in PUT /:orderId endpoint
- `backend/controllers/admin_order.js` - Added notification logic for all status changes

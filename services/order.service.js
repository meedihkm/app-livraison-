const pool = require("../config/database");

// Helper pour parsing sÃ©curisÃ©
const safeParseFloat = (value) => {
  if (value === null || value === undefined) return 0;
  const parsed = parseFloat(value);
  return isNaN(parsed) ? 0 : parsed;
};

/**
 * RÃ©cupÃ¨re les items d'une commande
 */
async function getOrderItems(orderId) {
  const result = await pool.query(
    `SELECT oi.*, p.name as product_name 
     FROM order_items oi 
     JOIN products p ON oi.product_id = p.id 
     WHERE oi.order_id = $1`,
    [orderId],
  );
  return result.rows.map((item) => ({
    id: item.id,
    orderId: item.order_id,
    productId: item.product_id,
    productName: item.product_name || "",
    unitPrice: safeParseFloat(item.price),
    quantity: item.quantity || 0,
  }));
}

/**
 * RÃ©cupÃ¨re une commande avec ses items
 */
async function getOrderWithItems(orderId) {
  const orderResult = await pool.query(
    `SELECT o.*, u.name as customer_name, u.phone as customer_phone, u.address as customer_address, u.address_lat as customer_lat, u.address_lng as customer_lng
     FROM orders o 
     JOIN users u ON o.customer_id = u.id 
     WHERE o.id = $1`,
    [orderId],
  );

  if (orderResult.rows.length === 0) return null;

  const order = orderResult.rows[0];
  const items = await getOrderItems(orderId);

  return {
    id: order.id,
    orderNumber: order.order_number || null,
    organizationId: order.organization_id,
    customerId: order.customer_id,
    date: order.date || "",
    total: safeParseFloat(order.total),
    status: order.status || "pending",
    paymentStatus: order.payment_status || "unpaid",
    amountPaid: safeParseFloat(order.amount_paid),
    createdAt: order.created_at,
    items,
    customer: {
      id: order.customer_id,
      name: order.customer_name || "",
      phone: order.customer_phone || null,
      address: order.customer_address || null,
      latitude: order.customer_lat ? parseFloat(order.customer_lat) : null,
      longitude: order.customer_lng ? parseFloat(order.customer_lng) : null,
    },
  };
}

/**
 * Formate une commande pour la rÃ©ponse API
 */
function formatOrder(order, items, customer = null) {
  return {
    id: order.id,
    orderNumber: order.order_number || null,
    organizationId: order.organization_id,
    customerId: order.customer_id,
    date: order.date || "",
    total: safeParseFloat(order.total),
    status: order.status || "pending",
    paymentStatus: order.payment_status || "unpaid",
    amountPaid: safeParseFloat(order.amount_paid),
    createdAt: order.created_at,
    items,
    customer: customer || {
      id: order.customer_id,
      name: order.customer_name || "",
    },
  };
}

module.exports = {
  getOrderItems,
  getOrderWithItems,
  formatOrder,
};

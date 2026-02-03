// =====================================================
// ROUTES: Financial API v2 - Routes refactorisÃ©es
// Utilise FinancialService pour toute la logique mÃ©tier
// Ces routes peuvent coexister avec l'ancienne version
// =====================================================

const express = require("express");
const router = express.Router();
const { authenticate, authorize } = require("../middleware/auth");
const financialService = require("../services/financial.service");

// Note: Ces routes sont montÃ©es sur /api/financial/v2/* pour tests
// Une fois validÃ©es, elles remplaceront les routes v1

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/financial/v2/overview
// Vue d'ensemble financiÃ¨re (Admin)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get(
  "/overview",
  authenticate,
  authorize(["admin"]),
  async (req, res) => {
    try {
      const { dateFrom, dateTo } = req.query;
      const data = await financialService.getOverview(req.user.organization_id, {
        dateFrom,
        dateTo,
      });

      res.json({
        success: true,
        data,
        meta: { version: "2.0", cached: false },
      });
    } catch (error) {
      console.error("[Financial v2] Overview error:", error);
      res.status(500).json({ 
        success: false,
        error: error.message || "Erreur serveur" 
      });
    }
  }
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/financial/v2/debts
// Liste des clients avec dette
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get(
  "/debts",
  authenticate,
  authorize(["admin", "deliverer"]),
  async (req, res) => {
    try {
      const page = parseInt(req.query.page) || 1;
      const limit = Math.min(parseInt(req.query.limit) || 50, 100);
      const minDebt = parseFloat(req.query.minDebt) || 0;
      const customerId = req.query.customerId || null;
      const delivererId =
        req.user.role === "deliverer"
          ? req.user.id
          : req.query.delivererId || null;

      const result = await financialService.getDebts(req.user.organization_id, {
        page,
        limit,
        minDebt,
        customerId,
        delivererId,
      });

      res.json({
        success: true,
        ...result,
        meta: { version: "2.0" },
      });
    } catch (error) {
      console.error("[Financial v2] Debts error:", error);
      res.status(500).json({ 
        success: false,
        error: error.message || "Erreur serveur" 
      });
    }
  }
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/financial/v2/debts/:customerId
// DÃ©tail de la dette d'un client
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get(
  "/debts/:customerId",
  authenticate,
  authorize(["admin", "deliverer"]),
  async (req, res) => {
    try {
      const { customerId } = req.params;
      
      const data = await financialService.getCustomerDebt(
        customerId,
        req.user.organization_id
      );

      res.json({
        success: true,
        data,
        meta: { version: "2.0" },
      });
    } catch (error) {
      console.error("[Financial v2] Customer debt error:", error);
      
      if (error.message === "Client non trouvÃ©") {
        return res.status(404).json({
          success: false,
          error: error.message,
        });
      }
      
      res.status(500).json({ 
        success: false,
        error: error.message || "Erreur serveur" 
      });
    }
  }
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// POST /api/financial/v2/payments
// Enregistrer un paiement
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.post(
  "/payments",
  authenticate,
  authorize(["admin", "deliverer"]),
  async (req, res) => {
    try {
      const { customerId, amount, mode = "cash", notes, targetOrders } = req.body;

      // Validation
      if (!customerId || !amount || amount <= 0) {
        return res.status(400).json({
          success: false,
          error: "DonnÃ©es invalides: customerId et amount (positif) requis",
        });
      }

      const result = await financialService.recordPayment(
        { customerId, amount, mode, notes, targetOrders },
        req.user.id,
        req.user.organization_id
      );

      res.status(201).json({
        success: true,
        data: result,
        meta: { version: "2.0" },
      });
    } catch (error) {
      console.error("[Financial v2] Record payment error:", error);
      
      // Erreurs mÃ©tier = 400, Erreurs serveur = 500
      const statusCode = 
        error.message.includes("pas de dette") ||
        error.message.includes("supÃ©rieur Ã  la dette") ||
        error.message.includes("Client non trouvÃ©")
          ? 400
          : 500;
      
      res.status(statusCode).json({
        success: false,
        error: error.message,
      });
    }
  }
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/financial/v2/credit/alerts
// Liste des clients en alerte crÃ©dit
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get(
  "/credit/alerts",
  authenticate,
  authorize(["admin"]),
  async (req, res) => {
    try {
      const alerts = await financialService.getCreditAlerts(req.user.organization_id);

      res.json({
        success: true,
        data: alerts,
        meta: { version: "2.0", count: alerts.length },
      });
    } catch (error) {
      console.error("[Financial v2] Credit alerts error:", error);
      res.status(500).json({ 
        success: false,
        error: error.message || "Erreur serveur" 
      });
    }
  }
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// PUT /api/financial/v2/credit/:customerId/limit
// Modifier la limite de crÃ©dit
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.put(
  "/credit/:customerId/limit",
  authenticate,
  authorize(["admin"]),
  async (req, res) => {
    try {
      const { customerId } = req.params;
      const { limit } = req.body;

      if (limit === undefined || limit < 0) {
        return res.status(400).json({
          success: false,
          error: "Limite invalide (doit Ãªtre >= 0)",
        });
      }

      const result = await financialService.updateCreditLimit(
        customerId,
        limit,
        req.user.id,
        req.user.organization_id
      );

      res.json({
        success: true,
        data: result,
        meta: { version: "2.0" },
      });
    } catch (error) {
      console.error("[Financial v2] Update credit limit error:", error);
      
      if (error.message === "Client non trouvÃ©") {
        return res.status(404).json({
          success: false,
          error: error.message,
        });
      }
      
      res.status(500).json({ 
        success: false,
        error: error.message || "Erreur serveur" 
      });
    }
  }
);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// GET /api/financial/v2/payments/my-collections
// Collections du livreur connectÃ©
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
router.get(
  "/payments/my-collections",
  authenticate,
  authorize(["deliverer"]),
  async (req, res) => {
    try {
      const collections = await financialService.getDelivererCollections(
        req.user.id,
        req.user.organization_id,
        { date: new Date() }
      );

      res.json({
        success: true,
        data: collections,
        meta: { version: "2.0", count: collections.length },
      });
    } catch (error) {
      console.error("[Financial v2] My collections error:", error);
      res.status(500).json({ 
        success: false,
        error: error.message || "Erreur serveur" 
      });
    }
  }
);

module.exports = router;

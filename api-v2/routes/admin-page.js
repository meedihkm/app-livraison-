const express = require("express");
const path = require("path");
const router = express.Router();

// Servir la page HTML super admin
router.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "../public/super-admin.html"));
});

module.exports = router;

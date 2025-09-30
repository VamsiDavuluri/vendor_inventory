const express = require('express');
const qrController = require('../controllers/qr.controller');

// This line creates the router. It must be present.
const router = express.Router();

// This line defines a route on the router.
router.get('/vendor/:vendorId/qrcode', qrController.generateQrCode);

// This line exports the router so index.js can use it.
module.exports = router;
const express = require('express');
const productController = require('../controllers/product.controller');
const router = express.Router();

router.get('/vendor/:vendorId/products-with-status', productController.getProductsWithStatus);
router.get('/products/:vendorId/:productId', productController.getProductImages);

module.exports = router;
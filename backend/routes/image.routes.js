const express = require('express');
const multer = require('multer');
const imageController = require('../controllers/image.controller');

const router = express.Router();
const storage = multer.memoryStorage();
const upload = multer({ storage });

router.post(
  '/products/:vendorId/:productId/manage-images',
  upload.array('files'), // Multer middleware for file handling
  imageController.manageImages
);

module.exports = router;
// index.js

require('dotenv').config();
const express = require('express');
const multer = require('multer');
const AWS = require('aws-sdk');
const sharp = require('sharp');
const db = require('./database');
const cors = require('cors');
const qrcode = require('qrcode');

const app = express();
const port = 3000;
app.use(cors());

// --- AWS and Multer setup ---
const s3 = new AWS.S3({ /* ... your config ... */ });
const bucketName = process.env.AWS_BUCKET_NAME;
const storage = multer.memoryStorage();
const upload = multer({ storage });

// --- Mock Vendor Product Database ---
const VENDOR_PRODUCTS = {
  'vendor_123': [
    { id: 'prod_1', name: 'White & Black Stroke Art Abstract Pattern Shirt' }, { id: 'prod_2', name: 'Black Liquid Art Aloha Shirt' }, { id: 'prod_3', name: 'Neon Tropical Pattern Aloha Shirt' }, { id: 'prod_4', name: 'Modern Abstract Art Aloha Shirt' }, { id: 'prod_5', name: 'Bright Tropical Print Aloha Shirt' }, { id: 'prod_6', name: 'Multicoloured Geometric Pattern Aloha Shirt' }, { id: 'prod_7', name: 'Blue & Black Abstract Art Pattern Aloha Shirt' }, { id: 'prod_8', name: 'Abstract Pattern Aloha Shirt' }, { id: 'prod_9', name: 'Green Abstract Pattern Aloha Shirt' }, { id: 'prod_10', name: 'White & Sky Blue Tie Dye Pattern Aloha Shirt' }, { id: 'prod_11', name: 'Plain Red & Black Tie Dye Pattern Aloha Shirt' }, { id: 'prod_12', name: 'Black & White Tie Dye Pattern Aloha Shirt' }, { id: 'prod_13', name: 'Grey & White Tie Dye Pattern Aloha Shirt' },
  ],
  'vendor_456': [
    { id: 'prod_14', name: 'Classic Leather Wallet' }, { id: 'prod_15', name: 'Stainless Steel Watch' }, { id: 'prod_16', name: 'Canvas Backpack' }, { id: 'prod_17', name: 'Sunglasses' },
  ],
};

// ================================================================= //
//                           API ENDPOINTS                           //
// ================================================================= //

/**
 * ✅ Get the list of products for a specific vendor
 */
app.get('/products/:vendorId', (req, res) => {
  const { vendorId } = req.params;
  const products = VENDOR_PRODUCTS[vendorId];
  console.log(`🔎 Request for product list from vendor: ${vendorId}`);
  if (products) {
    console.log(`📤 Found ${products.length} products. Sending list.`);
    res.json(products);
  } else {
    console.log(`🤷 Vendor ${vendorId} not found or has no products.`);
    res.status(404).json([]);
  }
});

/**
 * ✅ Fetch a single product's images
 */
app.get('/products/:vendorId/:productId', async (req, res) => {
  const { vendorId, productId } = req.params;
  try {
    // THIS IS THE LOG YOU WERE MISSING
    console.log("🔎 Fetching images with:", { vendorId, productId });

    const result = await db.query('SELECT image_url FROM vendor_products WHERE vendor_id=$1 AND product_id=$2', [vendorId, productId]);
    
    // THIS IS THE LOG YOU WERE MISSING
    console.log("📤 DB rows on fetch:", result.rows);

    const freshUrls = result.rows.map(row => s3.getSignedUrl('getObject', { Bucket: bucketName, Key: row.image_url, Expires: 3600 }));
    res.json({ images: freshUrls });
  } catch (err) {
    console.error("❌ Fetch error:", err);
    res.status(500).json({ error: 'Failed to fetch images' });
  }
});

/**
 * ✅ Upload images
 */
app.post('/upload/:vendorId/:productId/:productName', upload.array('files'), async (req, res) => {
  const { vendorId, productId, productName } = req.params;
  if (!req.files || req.files.length === 0) return res.status(400).json({ error: 'No files uploaded' });

  console.log(`📥 Uploading ${req.files.length} files for product ${productId}...`);

  for (const file of req.files) {
    try {
      const webpBuffer = await sharp(file.buffer).webp({ quality: 80 }).toBuffer();
      const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1e9)}.webp`;
      const s3Key = `${vendorId}/${productId}/${uniqueName}`;
      await s3.upload({ Bucket: bucketName, Key: s3Key, Body: webpBuffer, ContentType: 'image/webp' }).promise();
      await db.query('INSERT INTO vendor_products(vendor_id, product_id, product_name, image_url) VALUES($1,$2,$3,$4)', [vendorId, productId, productName, s3Key]);
      console.log(`   ✅ Uploaded ${file.originalname} → ${uniqueName}`);
    } catch (err) {
      console.error("   ❌ Upload error:", err);
      return res.status(500).json({ error: 'Upload failed' });
    }
  }

  console.log(`   🔄 Fetching updated image list after upload...`);
  const result = await db.query('SELECT image_url FROM vendor_products WHERE vendor_id=$1 AND product_id=$2', [vendorId, productId]);
  const freshUrls = result.rows.map(row => s3.getSignedUrl('getObject', { Bucket: bucketName, Key: row.image_url, Expires: 3600 }));
  res.json({ images: freshUrls });
});

/**
 * ✅ Delete an image
 */
app.delete('/products/:vendorId/:productId/:imageKey', async (req, res) => {
  const { vendorId, productId, imageKey } = req.params;
  const fullKey = `${vendorId}/${productId}/${imageKey}`;
  console.log(`🗑️ Deleting key: ${fullKey}`);
  try {
    await s3.deleteObject({ Bucket: bucketName, Key: fullKey }).promise();
    await db.query('DELETE FROM vendor_products WHERE vendor_id=$1 AND product_id=$2 AND image_url=$3', [vendorId, productId, fullKey]);
    
    console.log(`   🔄 Fetching updated image list after delete...`);
    const result = await db.query('SELECT image_url FROM vendor_products WHERE vendor_id=$1 AND product_id=$2', [vendorId, productId]);
    const freshUrls = result.rows.map(row => s3.getSignedUrl('getObject', { Bucket: bucketName, Key: row.image_url, Expires: 3600 }));
    res.json({ images: freshUrls });
  } catch (err) {
    console.error("   ❌ Delete error:", err);
    res.status(500).json({ error: "Failed to delete image" });
  }
});

/**
 * ✅ Generate QR Code
 */
app.get('/vendor/:vendorId/qrcode', async (req, res) => {
  const { vendorId } = req.params;
  if (!vendorId) return res.status(400).send('Vendor ID is required');
  try {
    const qrCodeDataURL = await qrcode.toDataURL(vendorId);
    res.json({ qrCodeUrl: qrCodeDataURL });
    console.log(`✅ Generated QR Code for: ${vendorId}`);
  } catch (err) {
    console.error('❌ QR Code generation error:', err);
    res.status(500).send('Failed to generate QR Code');
  }
});


// Start server
app.listen(port, '0.0.0.0', () => {
  console.log(`🚀 Backend running on http://localhost:${port}`);
});
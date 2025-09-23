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
app.use(express.json());

// --- AWS S3 and Multer Setup ---
const s3 = new AWS.S3({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION,
});
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
 * ✅ EFFICIENT ENDPOINT
 * Fetches the product list for a vendor AND enriches it with image status and count.
 */
app.get('/vendor/:vendorId/products-with-status', async (req, res) => {
  const { vendorId } = req.params;
  const products = VENDOR_PRODUCTS[vendorId];
  if (!products) return res.status(404).json([]);
  try {
    const enrichedProducts = await Promise.all(
      products.map(async (product) => {
        const result = await db.query('SELECT image_url FROM vendor_products WHERE vendor_id=$1 AND product_id=$2 ORDER BY created_at DESC', [vendorId, product.id]);
        const hasImages = result.rows.length > 0;
        const coverImageUrl = hasImages ? s3.getSignedUrl('getObject', { Bucket: bucketName, Key: result.rows[0].image_url, Expires: 3600 }) : null;
        return {
          id: product.id, name: product.name, hasImages: hasImages, coverImageUrl: coverImageUrl, imageCount: result.rows.length,
        };
      })
    );
    res.json(enrichedProducts);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch product statuses' });
  }
});

/**
 * ✅ Fetch a single product's images (Thumbnail First)
 */
app.get('/products/:vendorId/:productId', async (req, res) => {
  const { vendorId, productId } = req.params;
  try {
    console.log("🔎 Fetching images with:", { vendorId, productId });
    const result = await db.query('SELECT image_url, created_at FROM vendor_products WHERE vendor_id=$1 AND product_id=$2 ORDER BY created_at DESC', [vendorId, productId]);
    console.log("📤 DB rows on fetch:", result.rows);
    const freshUrls = result.rows.map(row => s3.getSignedUrl('getObject', { Bucket: bucketName, Key: row.image_url, Expires: 3600 }));
    res.json({ images: freshUrls });
  } catch (err) {
    console.error("❌ Fetch error:", err);
    res.status(500).json({ error: 'Failed to fetch images' });
  }
});

/**
 * ✅ Set a product's thumbnail image by updating its timestamp
 */
app.post('/products/:vendorId/:productId/thumbnail', async (req, res) => {
  const { vendorId, productId } = req.params;
  const { imageKey } = req.body;
  const fullS3Key = `${vendorId}/${productId}/${imageKey}`;
  try {
    const result = await db.query("UPDATE vendor_products SET created_at = NOW() WHERE image_url = $1 RETURNING *", [fullS3Key]);
    if (result.rowCount === 0) return res.status(404).json({ error: 'Image key not found' });
    res.status(200).json({ message: 'Thumbnail updated successfully' });
  } catch (err) { res.status(500).json({ error: 'Failed to set thumbnail' }); }
});

/**
 * ✅ SMART UPLOAD ENDPOINT (Corrected)
 * Now correctly sets timestamps to guarantee thumbnail order.
 */
app.post('/products/:vendorId/:productId/add-images', upload.array('files'), async (req, res) => {
  const { vendorId, productId } = req.params;
  const { thumbnail_index } = req.body; // Index of the thumbnail in the files array

  if (!req.files || req.files.length === 0) return res.status(400).json({ error: 'No files uploaded' });

  const allVendorProducts = VENDOR_PRODUCTS[vendorId] || [];
  const productInfo = allVendorProducts.find(p => p.id === productId);
  const productName = productInfo ? productInfo.name : 'Unknown Product';

  try {
    const uploadPromises = req.files.map(async (file, index) => {
      console.log(`   🔄 Converting ${file.originalname} to WebP for product ${productId}...`);
      const webpBuffer = await sharp(file.buffer).rotate().webp({ quality: 80 }).toBuffer();
      const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1e9)}.webp`;
      const s3Key = `${vendorId}/${productId}/${uniqueName}`;
      
      await s3.upload({ Bucket: bucketName, Key: s3Key, Body: webpBuffer, ContentType: 'image/webp' }).promise();

      const timestamp = (index.toString() === thumbnail_index) 
        ? 'NOW()' 
        : `NOW() - interval '${index + 1} seconds'`;

      await db.query(
        `INSERT INTO vendor_products(vendor_id, product_id, product_name, image_url, created_at) VALUES($1, $2, $3, $4, ${timestamp})`,
        [vendorId, productId, productName, s3Key]
      );
    });

    await Promise.all(uploadPromises);

    const result = await db.query('SELECT image_url FROM vendor_products WHERE vendor_id=$1 AND product_id=$2 ORDER BY created_at DESC', [vendorId, productId]);
    const freshUrls = result.rows.map(row => s3.getSignedUrl('getObject', { Bucket: bucketName, Key: row.image_url, Expires: 3600 }));
    res.json({ images: freshUrls });

  } catch (err) {
    console.error("❌ Upload error:", err);
    return res.status(500).json({ error: 'Upload failed' });
  }
});

/**
 * ✅ Delete an image
 */
app.delete('/products/:vendorId/:productId/:imageKey', async (req, res) => {
  const { vendorId, productId, imageKey } = req.params;
  const fullKey = `${vendorId}/${productId}/${imageKey}`;
  try {
    await s3.deleteObject({ Bucket: bucketName, Key: fullKey }).promise();
    await db.query('DELETE FROM vendor_products WHERE image_url=$1', [fullKey]);
    const result = await db.query('SELECT image_url FROM vendor_products WHERE vendor_id=$1 AND product_id=$2 ORDER BY created_at DESC', [vendorId, productId]);
    const freshUrls = result.rows.map(row => s3.getSignedUrl('getObject', { Bucket: bucketName, Key: row.image_url, Expires: 3600 }));
    res.json({ images: freshUrls });
  } catch (err) { res.status(500).json({ error: "Failed to delete image" }); }
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
  } catch (err) { res.status(500).send('Failed to generate QR Code'); }
});

// Start server
app.listen(port, '0.0.0.0', () => {
  console.log(`🚀 Backend running on http://localhost:${port}`);
});
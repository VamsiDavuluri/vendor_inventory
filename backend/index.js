require('dotenv').config();
const express = require('express');
const multer = require('multer');
const AWS = require('aws-sdk');
const sharp = require('sharp');
const db = require('./database'); // <-- db.js connection
const cors = require('cors');

const app = express();
const port = 3000;
app.use(cors());

// AWS S3 Setup
const s3 = new AWS.S3({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION,
});
const bucketName = process.env.AWS_BUCKET_NAME;

// Multer memory storage
const storage = multer.memoryStorage();
const upload = multer({ storage });

/**
 * ✅ Upload images (WebP, quality 80)
 */
app.post('/upload/:vendorId/:productId/:productName', upload.array('files'), async (req, res) => {
  const { vendorId, productId, productName } = req.params;

  if (!req.files || req.files.length === 0) {
    return res.status(400).json({ error: 'No files uploaded' });
  }

  for (const file of req.files) {
    try {
      // Convert to WebP
      const webpBuffer = await sharp(file.buffer)
        .webp({ quality: 80 })
        .toBuffer();

      const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1e9)}.webp`;
      const s3Key = `${vendorId}/${productId}/${uniqueName}`;

      // Upload to S3
      await s3.upload({
        Bucket: bucketName,
        Key: s3Key,
        Body: webpBuffer,
        ContentType: 'image/webp',
      }).promise();

      // Save in DB
      console.log("📥 Inserting into DB:", { vendorId, productId, productName, s3Key });

      await db.query(
        'INSERT INTO vendor_products(vendor_id, product_id, product_name, image_url) VALUES($1,$2,$3,$4)',
        [vendorId, productId, productName, s3Key]
      );

      console.log(`✅ Uploaded ${file.originalname} → ${uniqueName}`);
    } catch (err) {
      console.error("❌ Upload error:", err);
      return res.status(500).json({ error: 'Upload failed' });
    }
  }

  // Return fresh signed URLs
  console.log("🔎 Fetching after upload:", { vendorId, productId });

  const result = await db.query(
    'SELECT image_url FROM vendor_products WHERE vendor_id=$1 AND product_id=$2',
    [vendorId, productId]
  );

  console.log("📤 DB rows after upload:", result.rows);

  const freshUrls = result.rows.map(row =>
    s3.getSignedUrl('getObject', {
      Bucket: bucketName,
      Key: row.image_url,
      Expires: 3600,
    })
  );

  res.json({ images: freshUrls });
});

/**
 * ✅ Fetch product images
 */
app.get('/products/:vendorId/:productId', async (req, res) => {
  const { vendorId, productId } = req.params;

  try {
    console.log("🔎 Fetching with:", { vendorId, productId });

    const result = await db.query(
      'SELECT image_url FROM vendor_products WHERE vendor_id=$1 AND product_id=$2',
      [vendorId, productId]
    );

    console.log("📤 DB rows on fetch:", result.rows);

    const freshUrls = result.rows.map(row =>
      s3.getSignedUrl('getObject', {
        Bucket: bucketName,
        Key: row.image_url,
        Expires: 3600,
      })
    );

    res.json({ images: freshUrls });
  } catch (err) {
    console.error("❌ Fetch error:", err);
    res.status(500).json({ error: 'Failed to fetch images' });
  }
});

/**
 * ✅ Delete an image
 */
app.delete('/products/:vendorId/:productId/:imageKey', async (req, res) => {
  const { vendorId, productId, imageKey } = req.params;
  const fullKey = `${vendorId}/${productId}/${imageKey}`;

  try {
    console.log("🗑️ Deleting:", { vendorId, productId, imageKey });

    // Delete from S3
    await s3.deleteObject({
      Bucket: bucketName,
      Key: fullKey,
    }).promise();

    // Delete from DB
    await db.query(
      'DELETE FROM vendor_products WHERE vendor_id=$1 AND product_id=$2 AND image_url=$3',
      [vendorId, productId, fullKey]
    );

    // Return updated list
    const result = await db.query(
      'SELECT image_url FROM vendor_products WHERE vendor_id=$1 AND product_id=$2',
      [vendorId, productId]
    );

    console.log("📤 DB rows after delete:", result.rows);

    const freshUrls = result.rows.map(row =>
      s3.getSignedUrl('getObject', {
        Bucket: bucketName,
        Key: row.image_url,
        Expires: 3600,
      })
    );

    res.json({ images: freshUrls });
  } catch (err) {
    console.error("❌ Delete error:", err);
    res.status(500).json({ error: "Failed to delete image" });
  }
});

// Start server
app.listen(port, '0.0.0.0', () => {
  console.log(`🚀 Backend running on http://localhost:${port}`);
});

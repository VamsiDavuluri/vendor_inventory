const sharp = require('sharp');
const db = require('../database');
const { s3, bucketName, VENDOR_PRODUCTS } = require('../config'); // We'll create a config file

const extractS3Key = (signedUrl) => {
  try {
    const url = new URL(signedUrl);
    return decodeURIComponent(url.pathname.substring(1));
  } catch (error) {
    console.error(`Invalid URL for S3 key extraction: ${signedUrl}`);
    return null;
  }
};

// The main logic for managing images
exports.manageImages = async (req, res) => {
  const { vendorId, productId } = req.params;
  const { action, thumbnail_index, urls_to_delete, existing_thumbnail_url } = req.body;

  console.log(`⚡ Action: ${action} | product: ${productId}`);

  const productInfo = (VENDOR_PRODUCTS[vendorId] || []).find((p) => p.id === productId);
  if (!productInfo) return res.status(404).json({ error: 'Product not found' });
  const { name: productName, brand } = productInfo;

  try {
    if (action === 'batchUpdate') {
      // 1. Handle Deletions
      if (urls_to_delete) {
        const signedUrls = JSON.parse(urls_to_delete);
        console.log(`🗑️ Deleting ${signedUrls.length} images...`);
        const deletePromises = signedUrls.map((url) => {
          const key = extractS3Key(url);
          if (!key) return Promise.resolve();
          return Promise.all([
            s3.deleteObject({ Bucket: bucketName, Key: key }).promise(),
            db.query('DELETE FROM vendor_products WHERE vendor_id=$1 AND product_id=$2 AND image_url=$3', [vendorId, productId, key]),
          ]);
        });
        await Promise.all(deletePromises);
      }

      // 2. Handle Uploads
      if (req.files && req.files.length > 0) {
        console.log(`📤 Uploading ${req.files.length} images...`);
        const uploadPromises = req.files.map(async (file, index) => {
          const webpBuffer = await sharp(file.buffer).rotate().webp({ quality: 80 }).toBuffer();
          const uniqueName = `${Date.now()}-${Math.round(Math.random() * 1e9)}.webp`;
          const s3Key = `getto/pre-inventory/${vendorId}/${productId}/${uniqueName}`;
          await s3.upload({ Bucket: bucketName, Key: s3Key, Body: webpBuffer, ContentType: 'image/webp' }).promise();
          const timestamp = index.toString() === thumbnail_index ? 'NOW()' : `NOW() - interval '${index + 1} seconds'`;
          await db.query(
            `INSERT INTO vendor_products(vendor_id, product_id, product_name, brand_name, image_url, created_at) VALUES($1, $2, $3, $4, $5, ${timestamp})`,
            [vendorId, productId, productName, brand, s3Key]
          );
        });
        await Promise.all(uploadPromises);
      }

      // 3. Handle Thumbnail Update
      if (existing_thumbnail_url) {
        const key = extractS3Key(existing_thumbnail_url);
        if (key) {
          console.log(`⭐ Setting existing thumbnail: ${key}`);
          await db.query("UPDATE vendor_products SET created_at = NOW() WHERE vendor_id=$1 AND product_id=$2 AND image_url=$3", [vendorId, productId, key]);
        }
      }
    } else {
      return res.status(400).json({ error: `Unsupported action: ${action}` });
    }

    // Always respond with the final state
    const result = await db.query('SELECT image_url FROM vendor_products WHERE vendor_id=$1 AND product_id=$2 ORDER BY created_at DESC', [vendorId, productId]);
    const freshUrls = result.rows.map((row) => s3.getSignedUrl('getObject', { Bucket: bucketName, Key: row.image_url, Expires: 3600 }));

    res.json({
      images: freshUrls,
      coverImageUrl: freshUrls.length > 0 ? freshUrls[0] : null,
      imageCount: freshUrls.length,
    });
  } catch (err) {
    console.error("❌ Manage images error:", err);
    res.status(500).json({ error: 'Operation failed' });
  }
};
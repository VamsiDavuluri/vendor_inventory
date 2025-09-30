const db = require('../database');
const { s3, bucketName, VENDOR_PRODUCTS } = require('../config');

exports.getProductsWithStatus = async (req, res) => {
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
          id: product.id,
          name: product.name,
          brand: product.brand,
          hasImages,
          coverImageUrl,
          imageCount: result.rows.length,
        };
      })
    );
    res.json(enrichedProducts);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch product statuses' });
  }
};

exports.getProductImages = async (req, res) => {
  const { vendorId, productId } = req.params;
  try {
    const result = await db.query('SELECT image_url FROM vendor_products WHERE vendor_id=$1 AND product_id=$2 ORDER BY created_at DESC', [vendorId, productId]);
    const freshUrls = result.rows.map((row) => s3.getSignedUrl('getObject', { Bucket: bucketName, Key: row.image_url, Expires: 3600 }));
    res.json({ images: freshUrls });
  } catch (err) {
    console.error("❌ Fetch error:", err);
    res.status(500).json({ error: 'Failed to fetch images' });
  }
};
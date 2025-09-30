require('dotenv').config();
const AWS = require('aws-sdk');

// S3 Configuration
const s3 = new AWS.S3({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION,
});
const bucketName = process.env.AWS_BUCKET_NAME;

// Mock Data (can be moved to a database later)
const VENDOR_PRODUCTS = {
    'vendor_123': [
        { id: 'prod_1', name: 'White & Black Stroke Art Abstract Pattern Shirt', brand: "nike" },
        { id: 'prod_2', name: 'Black Liquid Art Aloha Shirt', brand: "nike" },
        { id: 'prod_3', name: 'Neon Tropical Pattern Aloha Shirt', brand: "adidas" },
        { id: 'prod_4', name: 'Modern Abstract Art Aloha Shirt', brand: "adidas" },
        { id: 'prod_5', name: 'Bright Tropical Print Aloha Shirt', brand: "nike" },
        { id: 'prod_6', name: 'Multicoloured Geometric Pattern Aloha Shirt', brand: "puma" },
        { id: 'prod_7', name: 'Blue & Black Abstract Art Pattern Aloha Shirt', brand: "puma" },
        { id: 'prod_8', name: 'Abstract Pattern Aloha Shirt', brand: "puma" },
        { id: 'prod_9', name: 'Green Abstract Pattern Aloha Shirt', brand: "puma" },
        { id: 'prod_10', name: 'White & Sky Blue Tie Dye Pattern Aloha Shirt', brand: "puma" },
        { id: 'prod_11', name: 'Plain Red & Black Tie Dye Pattern Aloha Shirt', brand: "puma" },
        { id: 'prod_12', name: 'Black & White Tie Dye Pattern Aloha Shirt', brand: "puma" },
        { id: 'prod_13', name: 'Grey & White Tie Dye Pattern Aloha Shirt', brand: "puma" },
    ],
    'vendor_456': [
        { id: 'prod_14', name: 'Classic Leather Wallet', brand: "gucci" },
        { id: 'prod_15', name: 'Stainless Steel Watch', brand: "gucci" },
        { id: 'prod_16', name: 'Canvas Backpack', brand: "gucci" },
        { id: 'prod_17', name: 'Sunglasses', brand: "gucci" },
    ],
};

module.exports = {
    s3,
    bucketName,
    VENDOR_PRODUCTS
};
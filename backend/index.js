require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path'); // Import the path module

// Import routes
const imageRoutes = require('./routes/image.routes.js');
const productRoutes = require('./routes/product.routes.js');
const qrRoutes = require('./routes/qr.routes.js');

const app = express();
const port = 3000;

// Middleware
app.use(cors());
app.use(express.json());

// --- NEW: Serve static files from the 'public' directory ---
// This makes your admin.html available in the browser
app.use(express.static(path.join(__dirname, 'public')));

// Use the API routes, prefixed with /api
app.use('/api', imageRoutes);
app.use('/api', productRoutes);
app.use('/api', qrRoutes);

// Server entrypoint
app.listen(port, '0.0.0.0', () => {
  console.log(`🚀 Backend running on http://localhost:${port}`);
  console.log(`👑 Admin QR Generator available at http://localhost:${port}/admin.html`);
});
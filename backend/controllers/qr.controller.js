const qrcode = require('qrcode');

exports.generateQrCode = async (req, res) => {
  const { vendorId } = req.params;
  if (!vendorId) {
    return res.status(400).send('Vendor ID is required');
  }

  try {
    // Generate QR code as a Data URL
    const qrCodeDataURL = await qrcode.toDataURL(vendorId);
    res.json({ qrCodeUrl: qrCodeDataURL });
  } catch (err) {
    console.error('Failed to generate QR Code:', err);
    res.status(500).send('Failed to generate QR Code');
  }
};
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_screen.dart';
import '../api_service.dart';

const Color brandTealDark = Color(0xFF009EAE);
const Color brandTealLight = Color(0xFF02D7C0);

class QRScannerScreen extends StatelessWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  Future<void> _handleScanButton(BuildContext context) async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      final String? scannedValue = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => _ScannerPage()),
      );
      if (scannedValue != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _LoadingScreen(vendorId: scannedValue),
          ),
        );
      }
    } else if (context.mounted) {
      _showPermissionDeniedDialog(context);
    }
  }

  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text("Permission Denied"),
        content: Text("Camera access is required."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: TextStyle(
                color: brandTealDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... UI code is the same, no changes needed here ...
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: brandTealDark.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 80,
                    color: brandTealDark,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              Text(
                "Welcome to Inventory",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Please scan your vendor QR code to access your product folders.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const Spacer(),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _handleScanButton(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: brandTealDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  "Let's Get Started",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage({Key? key}) : super(key: key);
  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final MobileScannerController cameraController = MobileScannerController();
  bool _isPopping = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    if (_isPopping) return; // Prevent multiple pops from a single scan

    final String? scannedValue = capture.barcodes.first.rawValue;
    if (scannedValue != null && scannedValue.isNotEmpty) {
      _isPopping = true;
      // --- NEW: Log to confirm the scan was successful ---
      print('✅ QR Code Detected: $scannedValue');
      if (mounted) {
        Navigator.pop(context, scannedValue);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... UI code is the same, no changes needed here ...
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onQRCodeDetected,
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: brandTealLight, width: 4),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingScreen extends StatefulWidget {
  final String vendorId;
  const _LoadingScreen({Key? key, required this.vendorId}) : super(key: key);
  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _fetchDataAndNavigate();
  }

  Future<void> _fetchDataAndNavigate() async {
    try {
      final List<Product> loadedProducts =
          await ApiService.fetchProductsWithStatus(widget.vendorId);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              vendorId: widget.vendorId,
              initialProducts: loadedProducts,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      // --- NEW: Print the specific error to the terminal ---
      print("❌ Fetch failed with error: $e");
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Scan Error"),
            content: Text(
              "Could not load data for this vendor. Please check your network connection and try again.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("OK", style: TextStyle(color: brandTealDark)),
              ),
            ],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... UI code is the same, no changes needed here ...
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: brandTealDark),
            SizedBox(height: 20),
            Text(
              "Fetching Vendor Data...",
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}

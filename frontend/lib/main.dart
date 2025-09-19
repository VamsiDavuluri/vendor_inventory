import 'package:flutter/material.dart';
import 'screens/qr_scanner_screen.dart'; // This import is now correct

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vendor Inventory',
      theme: ThemeData(
        primaryColor: Color(0xFF009EAE),
        scaffoldBackgroundColor: Colors.white,
      ),
      debugShowCheckedModeBanner: false,
      // This home property is now correct
      home: QRScannerScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const WhatsAppSenderApp());
}

class WhatsAppSenderApp extends StatelessWidget {
  const WhatsAppSenderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp Bulk Sender',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

import 'package:flutter/material.dart';

/// Root widget AGAM.
///
/// Masih berupa kerangka. Layar UI01–UI09 dibangun oleh track FE
/// berdasarkan kontrak di `lib/contracts/`.
class AgamApp extends StatelessWidget {
  const AgamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGAM',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const Scaffold(body: Center(child: Text('AGAM'))),
    );
  }
}

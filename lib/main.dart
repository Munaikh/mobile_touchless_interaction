import 'package:flutter/material.dart';

import 'widgets/touchless_ring.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Avenir',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF256B6A),
          brightness: Brightness.light,
        ),
      ),
      home: const TouchlessHome(),
    );
  }
}

class TouchlessHome extends StatelessWidget {
  const TouchlessHome({super.key});

  static const List<String> _labels = [
    'Call',
    'Music',
    'Map',
    'Camera',
    'Message',
    'Torch',
  ];

  @override
  Widget build(BuildContext context) {
    final items = _labels.map((label) => Text(label)).toList(growable: false);

    return Scaffold(
      backgroundColor: Color(0xFFE5ECEB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Touchless Hover',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Tilt the device to move the cursor. Hold over a button\nfor a moment to activate it with haptics.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TouchlessRing(
                  fastDwellDuration: Duration(seconds: 2),
                  items: items,
                  onActivate: (index) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Activated ${_labels[index]}'),
                        duration: const Duration(milliseconds: 900),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

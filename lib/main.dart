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
    final items = _labels
        .map((label) => Text(label))
        .toList(growable: false);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F1E9), Color(0xFFE5ECEB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 48,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Touchless Hover',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tilt the device to move the cursor. Hold over a button\nfor a moment to activate it with haptics.',
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: TouchlessRing(
                items: items,
                itemBuilder: (context, index, isHovered, size, child) {
                  return AnimatedScale(
                    duration: const Duration(milliseconds: 150),
                    scale: isHovered ? 1.08 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: size,
                      height: size,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            isHovered ? const Color(0xFF256B6A) : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: isHovered ? 18 : 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(
                          color: isHovered
                              ? const Color(0xFF1F5957)
                              : const Color(0xFFE0E6E6),
                          width: isHovered ? 2 : 1,
                        ),
                      ),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              isHovered ? Colors.white : Colors.black87,
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
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
    );
  }
}

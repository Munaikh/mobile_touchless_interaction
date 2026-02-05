import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

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

class TouchlessHome extends StatefulWidget {
  const TouchlessHome({super.key});

  @override
  State<TouchlessHome> createState() => _TouchlessHomeState();
}

class _TouchlessHomeState extends State<TouchlessHome>
    with SingleTickerProviderStateMixin {
  static const Duration _dwellDuration = Duration(milliseconds: 800);
  static const Duration _activationCooldown = Duration(milliseconds: 1200);

  final List<String> _labels = const [
    'Call',
    'Music',
    'Map',
    'Camera',
    'Message',
    'Torch',
  ];

  StreamSubscription<AccelerometerEvent>? _accelSub;
  late final Ticker _ticker;
  Duration? _lastTick;
  Timer? _dwellTimer;
  DateTime? _lastActivationTime;

  Offset _cursorOffset = Offset.zero;
  Offset _desiredOffset = Offset.zero;
  Offset _targetOffset = Offset.zero;
  List<Offset> _buttonOffsets = const [];
  int? _hoveredIndex;

  double _circleRadius = 140.0;
  double _buttonRadius = 48.0;
  double _maxCursorRadius = 190.0;

  double _gravityX = 0.0;
  double _gravityY = 0.0;
  double _gravityZ = 0.0;
  double? _neutralX;
  double? _neutralY;

  void _recenter() {
    final gravityMag = sqrt(
      _gravityX * _gravityX +
          _gravityY * _gravityY +
          _gravityZ * _gravityZ,
    );

    if (gravityMag >= 0.1) {
      _neutralX = _gravityX / gravityMag;
      _neutralY = _gravityY / gravityMag;
    }

    _desiredOffset = Offset.zero;
    _targetOffset = Offset.zero;
    _cursorOffset = Offset.zero;
    _updateHover(null);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _accelSub = accelerometerEventStream().listen(_handleAccelEvent);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    _ticker.dispose();
    _dwellTimer?.cancel();
    super.dispose();
  }

  void _handleAccelEvent(AccelerometerEvent event) {
    if (_buttonOffsets.isEmpty) {
      return;
    }

    // Low-pass filter to approximate gravity for tilt direction.
    const double gravityAlpha = 0.94;
    _gravityX = gravityAlpha * _gravityX + (1 - gravityAlpha) * event.x;
    _gravityY = gravityAlpha * _gravityY + (1 - gravityAlpha) * event.y;
    _gravityZ = gravityAlpha * _gravityZ + (1 - gravityAlpha) * event.z;

    final gravityMag = sqrt(
      _gravityX * _gravityX +
          _gravityY * _gravityY +
          _gravityZ * _gravityZ,
    );
    if (gravityMag < 0.1) {
      return;
    }

    final normX = _gravityX / gravityMag;
    final normY = _gravityY / gravityMag;

    _neutralX ??= normX;
    _neutralY ??= normY;

    var deltaX = normX - (_neutralX ?? 0.0);
    var deltaY = normY - (_neutralY ?? 0.0);

    const double deadZone = 0.015;
    if (deltaX.abs() < deadZone) {
      deltaX = 0.0;
    }
    if (deltaY.abs() < deadZone) {
      deltaY = 0.0;
    }

    const double tiltSensitivity = 980.0;
    _desiredOffset = _clampToRadius(
      Offset(-deltaX, deltaY) * tiltSensitivity,
      _maxCursorRadius,
    );
  }

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;

    if (last == null || _buttonOffsets.isEmpty) {
      return;
    }

    final dt =
        ((elapsed - last).inMicroseconds / 1000000.0).clamp(0.005, 0.05);

    const double targetResponse = 6.0;
    final targetSmoothing = (dt * targetResponse).clamp(0.0, 1.0);
    _targetOffset += (_desiredOffset - _targetOffset) * targetSmoothing;

    const double cursorResponse = 9.0;
    final cursorSmoothing = (dt * cursorResponse).clamp(0.0, 1.0);
    var nextCursor =
        _cursorOffset + (_targetOffset - _cursorOffset) * cursorSmoothing;

    const double maxCursorSpeed = 1350.0;
    final delta = nextCursor - _cursorOffset;
    final maxStep = maxCursorSpeed * dt;
    if (delta.distance > maxStep) {
      nextCursor = _cursorOffset + delta / delta.distance * maxStep;
    }

    nextCursor = _clampToRadius(nextCursor, _maxCursorRadius);

    final hovered = _findHoveredIndex(nextCursor);
    if (hovered != null) {
      nextCursor = _applyMagnet(nextCursor, _buttonOffsets[hovered]);
    }

    _cursorOffset = nextCursor;
    _updateHover(hovered);

    if (mounted) {
      setState(() {});
    }
  }

  Offset _clampToRadius(Offset offset, double radius) {
    final dist = offset.distance;
    if (dist <= radius) {
      return offset;
    }
    return offset / dist * radius;
  }

  int? _findHoveredIndex(Offset cursorOffset) {
    if (_buttonOffsets.isEmpty) {
      return null;
    }

    final hoverRadius = _buttonRadius * 0.75;
    int? hovered;
    double best = hoverRadius;

    for (var i = 0; i < _buttonOffsets.length; i++) {
      final dist = (cursorOffset - _buttonOffsets[i]).distance;
      if (dist < best) {
        best = dist;
        hovered = i;
      }
    }

    return hovered;
  }

  Offset _applyMagnet(Offset cursorOffset, Offset target) {
    final magnetRadius = _buttonRadius * 1.6;
    final dist = (target - cursorOffset).distance;

    if (dist >= magnetRadius) {
      return cursorOffset;
    }

    final pull = (1 - (dist / magnetRadius)).clamp(0.0, 1.0);
    final strength = 0.05;

    return cursorOffset + (target - cursorOffset) * (strength * pull);
  }

  void _updateHover(int? index) {
    if (index == _hoveredIndex) {
      return;
    }

    _hoveredIndex = index;
    _dwellTimer?.cancel();

    if (index != null) {
      HapticFeedback.selectionClick();
      _dwellTimer = Timer(_dwellDuration, () => _activate(index));
    }
  }

  void _activate(int index) {
    final now = DateTime.now();
    final lastActivation = _lastActivationTime;

    if (lastActivation != null &&
        now.difference(lastActivation) < _activationCooldown) {
      return;
    }

    _lastActivationTime = now;
    HapticFeedback.mediumImpact();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Activated ${_labels[index]}'),
        duration: const Duration(milliseconds: 900),
      ),
    );

    setState(() {});
  }

  void _recalculateLayout(Size size) {
    final minSide = min(size.width, size.height);
    _circleRadius = minSide * 0.28;
    _buttonRadius = minSide * 0.085;
    _maxCursorRadius = _circleRadius + _buttonRadius * 0.8;

    final step = (2 * pi) / _labels.length;
    _buttonOffsets = List.generate(_labels.length, (index) {
      final angle = -pi / 2 + step * index;
      return Offset(cos(angle), sin(angle)) * _circleRadius;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          _recalculateLayout(constraints.biggest);
          final center = Offset(
            constraints.biggest.width / 2,
            constraints.biggest.height / 2,
          );

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF6F1E9), Color(0xFFE5ECEB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // Title and Instructions
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
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                // Recenter Button
                Positioned(
                  bottom: 52,
                  right: 24,
                  child: ElevatedButton.icon(
                    onPressed: _recenter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF256B6A),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.center_focus_strong, size: 16),
                    label: const Text('Recenter'),
                  ),
                ),
                // Circle
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        width: _circleRadius * 2.2,
                        height: _circleRadius * 2.2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFCAD5D4),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Buttons
                ..._labels.asMap().entries.map((entry) {
                  final index = entry.key;
                  final label = entry.value;
                  final offset = _buttonOffsets[index];
                  final isHovered = _hoveredIndex == index;

                  return Positioned(
                    left: center.dx + offset.dx - _buttonRadius,
                    top: center.dy + offset.dy - _buttonRadius,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 150),
                      scale: isHovered ? 1.08 : 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _buttonRadius * 2,
                        height: _buttonRadius * 2,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isHovered
                              ? const Color(0xFF256B6A)
                              : Colors.white,
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
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isHovered ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                
                // Cursor
                Positioned(
                  left: center.dx + _cursorOffset.dx - 10,
                  top: center.dy + _cursorOffset.dy - 10,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF256B6A).withOpacity(0.2),
                      border: Border.all(
                        color: const Color(0xFF256B6A),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
